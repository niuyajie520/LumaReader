#!/usr/bin/env python3
"""
LumaReader Built-in Kokoro-82M Neural TTS & Pure-NumPy WSOLA Time-Stretch Daemon
Implements:
- Managed Kitten Nano/Micro ONNX models with macOS system-speech fallback
- 4 categorized voice slots (`US_Female`, `US_Male`, `UK_Female`, `UK_Male`) persisted in `config/voices.json`
- 1.0x base synthesis cached by MD5 (`cache/audio/{md5}.wav`)
- Pure-NumPy WSOLA (Waveform Similarity Overlap-Add) pitch-preserving time-stretch for 0.5x ~ 2.0x + 80ms silence padding
- 3-tier priority background preloading (`preload` with cancellation token `_task_id`)
- Listens on 127.0.0.1:18880 (and 127.0.0.1:8880 / 8000 if free) and serves both native LumaReader endpoints and OpenAI-compatible `/v1/models`, `/v1/voices`, `/v1/audio/speech`.
"""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import wave
from exclusive_tts import ExclusiveModels # exclusive_models_v8
from audio_cache_budget import AudioCacheBudget
from audio_priority_queue import AudioPriorityQueue # rolling_audio_v5

os.environ.setdefault("ORT_DISABLE_TELEMETRY", "1")
# Lower only this service's scheduling priority; never change Safari or global settings.
try:
    os.nice(5)
except (AttributeError, OSError):
    pass

# Set before loading numerical runtimes. Avoid waking every CPU for background work.
for _key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS"):
    os.environ[_key] = "2"

import numpy as np

try:
    import soundfile as sf
except Exception:
    sf = None

try:
    from phonemizer.backend.espeak.wrapper import EspeakWrapper
    if not hasattr(EspeakWrapper, "set_data_path"):
        EspeakWrapper.set_data_path = classmethod(lambda cls, path: setattr(cls, "data_path", path))
except Exception:
    pass

BASE_DIR = Path(os.environ.get(
    "LUMA_KOKORO_DIR",
    os.path.expanduser("~/Library/Application Support/LumaReader/KokoroEngine")
))
ALT_TTS_DIR = Path(os.path.expanduser("~/Library/Application Support/LumaReader/KokoroTTS"))

CACHE_DIR = BASE_DIR / "cache" / "audio"
STRETCH_CACHE_DIR = BASE_DIR / "cache" / "stretched"
CONFIG_FILE = BASE_DIR / "config" / "voices.json"

CACHE_DIR.mkdir(parents=True, exist_ok=True)
STRETCH_CACHE_DIR.mkdir(parents=True, exist_ok=True)
CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
AUDIO_BUDGET = AudioCacheBudget((CACHE_DIR, STRETCH_CACHE_DIR))


def _write_wav(path: Path, samples: np.ndarray, sr: int = 24000):
    arr = np.asarray(samples, dtype=np.float32).flatten()
    if sf is not None:
        try:
            sf.write(str(path), arr, int(sr))
            return
        except Exception:
            pass
    clipped = np.clip(arr, -1.0, 1.0)
    pcm16 = (clipped * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(int(sr))
        wf.writeframes(pcm16.tobytes())


def _read_wav(path: Path) -> tuple[np.ndarray, int]:
    if sf is not None:
        try:
            data, sr = sf.read(str(path), dtype="float32")
            return np.asarray(data, dtype=np.float32).flatten(), int(sr)
        except Exception:
            pass
    with wave.open(str(path), "rb") as wf:
        sr = wf.getframerate()
        nch = wf.getnchannels()
        sw = wf.getsampwidth()
        raw = wf.readframes(wf.getnframes())
    if sw == 2:
        arr = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif sw == 4:
        arr = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        arr = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    if nch > 1:
        arr = arr.reshape(-1, nch).mean(axis=1)
    return arr.flatten(), int(sr)


def wsola_time_stretch(samples: np.ndarray, speed: float, frame_length: int = 512, synthesis_hop: int = 128, tolerance: int = 128) -> np.ndarray:
    """
    Pure-NumPy WSOLA (Waveform Similarity Overlap-Add) pitch-preserving time stretcher.
    Eliminates the legacy `audiotsm` package conflict while providing identical WSOLA phase-aligned overlap-add.
    """
    x = np.asarray(samples, dtype=np.float32).flatten()
    if len(x) < frame_length * 2 or abs(speed - 1.0) <= 0.01:
        return x

    analysis_hop = float(synthesis_hop * speed)
    num_frames = int((len(x) - frame_length - tolerance) / max(1.0, analysis_hop))
    if num_frames <= 1:
        return x

    window = np.hanning(frame_length).astype(np.float32)
    out_len = (num_frames - 1) * synthesis_hop + frame_length
    y = np.zeros(out_len, dtype=np.float32)
    norm = np.zeros(out_len, dtype=np.float32)

    # First frame
    y[:frame_length] = x[:frame_length] * window
    norm[:frame_length] = window
    prev_pos = 0

    for i in range(1, num_frames):
        expected_pos = int(round(i * analysis_hop))
        natural_next = prev_pos + synthesis_hop
        if natural_next + frame_length <= len(x):
            ref_overlap = x[natural_next:natural_next + synthesis_hop]
            low = max(0, expected_pos - tolerance)
            high = min(len(x) - frame_length, expected_pos + tolerance)
            if high > low and len(ref_overlap) == synthesis_hop:
                # Cross-correlation search for maximum waveform similarity
                best_offset = expected_pos
                best_score = -1e30
                step = 2
                for cand in range(low, high + 1, step):
                    seg = x[cand:cand + synthesis_hop]
                    score = float(np.dot(ref_overlap, seg))
                    if score > best_score:
                        best_score = score
                        best_offset = cand
                chosen_pos = best_offset
            else:
                chosen_pos = min(max(0, expected_pos), len(x) - frame_length)
        else:
            chosen_pos = min(max(0, expected_pos), len(x) - frame_length)

        out_start = i * synthesis_hop
        y[out_start:out_start + frame_length] += x[chosen_pos:chosen_pos + frame_length] * window
        norm[out_start:out_start + frame_length] += window
        prev_pos = chosen_pos

    mask = norm > 1e-6
    y[mask] /= norm[mask]
    return y


class KokoroWSOLAEngine:
    DEFAULT_SLOTS = {
        "US_Female": "af_heart",
        "US_Male": "am_adam",
        "UK_Female": "bf_emma",
        "UK_Male": "bm_george",
    }

    MACOS_FALLBACK_VOICES = {
        "af": ["Ava", "Samantha", "Allison", "Victoria"],
        "am": ["Alex", "Daniel", "Fred", "Tom"],
        "bf": ["Serena", "Kate", "Martha", "Fiona", "Samantha"],
        "bm": ["Daniel", "Oliver", "Arthur", "Alex"],
    }

    def __init__(self):
        self.kokoro = None
        self.model_error = None
        self.fallback_ready = False
        self._lock = threading.Lock()
        self._preload_guard = threading.Lock() # final_audio_prefetch_v4
        self._init_lock = threading.Lock()
        self._init_event = threading.Event()
        self._task_id = 0
        self.active_slots = self._load_config()
        self.current_slot = "UK_Female"
        self.phrases = []
        self.audio_jobs = AudioPriorityQueue(lambda *args: self.synthesize_checked(*args))

    def _init_model(self):
        # Replaced by ExclusiveModels.ensure_loaded; only Kitten model IDs are accepted.
        raise RuntimeError("Managed Kitten loader required")

    def is_ready(self) -> bool:
        if not self._init_event.is_set():
            self._init_event.wait(timeout=6.0)
        return (self.kokoro is not None) or self.fallback_ready

    def _load_config(self) -> dict:
        if CONFIG_FILE.is_file():
            try:
                data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
                if all(k in data for k in self.DEFAULT_SLOTS):
                    return data
            except Exception:
                pass
        return self.DEFAULT_SLOTS.copy()

    def get_categorized_voices(self) -> dict:
        if self.kokoro is not None:
            try:
                voices = sorted(list(self.kokoro.get_voices()))
                if voices:
                    return {
                        "US_Female": [v for v in voices if v.startswith("af_")] or ["af_heart"],
                        "US_Male": [v for v in voices if v.startswith("am_")] or ["am_adam"],
                        "UK_Female": [v for v in voices if v.startswith("bf_")] or ["bf_emma"],
                        "UK_Male": [v for v in voices if v.startswith("bm_")] or ["bm_george"],
                    }
            except Exception:
                pass
        return {
            "US_Female": ["af_alloy", "af_aoede", "af_bella", "af_heart", "af_jessica", "af_kore", "af_nicole", "af_nova", "af_river", "af_sarah", "af_sky"],
            "US_Male": ["am_adam", "am_echo", "am_eric", "am_fenrir", "am_liam", "am_michael", "am_onyx", "am_puck", "am_santa"],
            "UK_Female": ["bf_alice", "bf_emma", "bf_isabella", "bf_lily"],
            "UK_Male": ["bm_daniel", "bm_fable", "bm_george", "bm_lewis"],
        }

    def save_slots(self, new_slots: dict):
        for k in self.DEFAULT_SLOTS:
            if k in new_slots and new_slots[k]:
                self.active_slots[k] = new_slots[k]
        CONFIG_FILE.write_text(json.dumps(self.active_slots, indent=4, ensure_ascii=False), encoding="utf-8")
        if self.phrases:
            self.preload(0)

    def _base_cache_path(self, text: str, voice: str) -> Path:
        key = hashlib.md5(f"{text.strip().lower()}_{voice}".encode("utf-8")).hexdigest()
        return CACHE_DIR / f"{key}.wav"

    def _final_cache_path(self, text: str, voice: str, speed: float) -> Path:
        norm_speed = round(max(0.5, min(2.5, float(speed))), 2)
        key = hashlib.md5(f"audio-v9_{self.selected_model}_{text.strip().lower()}_{voice}_{norm_speed:.2f}".encode("utf-8")).hexdigest()
        return STRETCH_CACHE_DIR / f"{key}.wav"

    def _synthesize_macos_fallback(self, text: str, voice: str, out_path: Path):
        kitten_map = {
            "bella": "af", "rosie": "af",
            "jasper": "am", "hugo": "am",
            "luna": "bf", "kiki": "bf",
            "bruno": "bm", "leo": "bm",
        }
        v_clean = (voice or "bf_emma").strip().lower()
        prefix = kitten_map.get(v_clean, v_clean[:2])
        candidates = self.MACOS_FALLBACK_VOICES.get(prefix, ["Samantha"])
        say_bin = "/usr/bin/say"
        afconvert_bin = "/usr/bin/afconvert"
        if os.path.exists(say_bin):
            with tempfile.TemporaryDirectory() as tmpdir:
                aiff_path = Path(tmpdir) / "speech.aiff"
                wav_tmp = Path(tmpdir) / "speech.wav"
                synthesized = False
                for mac_voice in candidates:
                    res = subprocess.run([say_bin, "-v", mac_voice, "-o", str(aiff_path), text], capture_output=True, timeout=30)
                    if res.returncode == 0 and aiff_path.is_file() and aiff_path.stat().st_size > 64:
                        synthesized = True
                        break
                if not synthesized:
                    subprocess.run([say_bin, "-o", str(aiff_path), text], capture_output=True, timeout=30)
                if aiff_path.is_file() and os.path.exists(afconvert_bin):
                    subprocess.run(
                        [afconvert_bin, "-f", "WAVE", "-d", "LEI16@24000", "-c", "1", str(aiff_path), str(wav_tmp)],
                        capture_output=True, timeout=30
                    )
                    if wav_tmp.is_file() and wav_tmp.stat().st_size > 64:
                        shutil.copy2(wav_tmp, out_path)
                        return
        # Pure-NumPy fallback waveform if command-line speech tools are unavailable
        sr = 24000
        t = np.linspace(0.0, 0.35, int(sr * 0.35), endpoint=False, dtype=np.float32)
        env = np.hanning(len(t)).astype(np.float32)
        wave_samples = 0.2 * np.sin(2.0 * np.pi * 440.0 * t) * env
        _write_wav(out_path, wave_samples, sr)

    def synthesize_base(self, text: str, voice: str) -> Path:
        clean_text = (text or "").strip() or "hello"
        if not self._init_event.is_set():
            self._init_model()
        base_path = self._base_cache_path(clean_text, voice)
        if base_path.is_file() and base_path.stat().st_size > 64:
            AUDIO_BUDGET.touch(base_path)
            return base_path
        lang = "en-gb" if voice.startswith("b") else "en-us"
        with self._lock:
            if not (base_path.is_file() and base_path.stat().st_size > 64):
                if self.kokoro is not None:
                    try:
                        samples, sr = self.kokoro.create(text=clean_text, voice=voice, speed=1.0, lang=lang)
                        _write_wav(base_path, samples, sr)
                        return base_path
                    except Exception as exc:
                        print(f"[KokoroDaemon] ONNX synthesis fallback for '{clean_text}': {exc}", flush=True)
                self._synthesize_macos_fallback(clean_text, voice, base_path)
        return base_path

    def synthesize_with_wsola_and_padding(self, text: str, voice: str, speed: float = 1.0) -> Path:
        clean_text = (text or "").strip() or "hello"
        target_speed = max(0.5, min(2.5, float(speed)))
        final_path = self._final_cache_path(clean_text, voice, target_speed)
        if final_path.is_file() and final_path.stat().st_size > 64:
            AUDIO_BUDGET.touch(final_path)
            return final_path

        # audio_boundary_v3
        if not self._init_event.is_set():
            self._init_model()
        if self.kokoro is not None:
            with self._lock:
                if final_path.is_file() and final_path.stat().st_size > 64:
                    return final_path
                samples, sr = self.kokoro.create(text=clean_text, voice=voice, speed=target_speed, lang="en-gb" if voice.startswith("b") else "en-us")
        else:
            base_path = self.synthesize_base(clean_text, voice)
            samples, sr = _read_wav(base_path)
            if abs(target_speed - 1.0) > 0.01:
                samples = wsola_time_stretch(samples, speed=target_speed)
        samples = np.nan_to_num(np.asarray(samples, dtype=np.float32).flatten()).copy()
        ramp = min(int(sr * 0.005), len(samples) // 2)
        if ramp > 1:
            samples[:ramp] *= np.linspace(0, 1, ramp, dtype=np.float32)
            samples[-ramp:] *= np.linspace(1, 0, ramp, dtype=np.float32)
        peak = float(np.max(np.abs(samples))) if len(samples) else 0.0
        if peak > 0.98:
            samples *= 0.98 / peak
        pad = int(sr * 0.08)
        padded = np.pad(samples.flatten(), (pad, pad), mode="constant")
        _write_wav(final_path, padded, sr)
        return final_path

    def preload(self, start_idx: int = 0, phrases: list | None = None, current_slot: str | None = None, speed: float = 1.0):
        if current_slot in self.DEFAULT_SLOTS:
            self.current_slot = current_slot
        primary = self.active_slots.get(self.current_slot, "bf_emma")
        rate = 1.0 # base_rate_cache_v6
        selected = [p.strip() for p in (phrases or []) if p and p.strip()][max(0, start_idx):][:3]
        items = []
        for phrase in selected:
            key = str(self._final_cache_path(phrase, primary, rate))
            if not Path(key).is_file():
                items.append((key, (phrase, primary, rate, self.model_epoch)))
        self.audio_jobs.preload(items)

    def request_audio(self, text, voice, speed):
        speed = 1.0
        path = self._final_cache_path(text, voice, speed)
        if path.is_file() and path.stat().st_size > 64:
            AUDIO_BUDGET.touch(path)
            return path
        return self.audio_jobs.request(str(path), (text, voice, speed, self.model_epoch))


ENGINE = KokoroWSOLAEngine()
MODEL_CONTROL = ExclusiveModels(ENGINE, BASE_DIR)


class ReusableThreadingHTTPServer(ThreadingHTTPServer):
    slots = threading.BoundedSemaphore(8)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            try:
                request.sendall(b"HTTP/1.0 503 Service Unavailable\r\nContent-Length: 0\r\n\r\n")
            finally:
                self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()

    allow_reuse_address = True
    daemon_threads = True


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(65)

    def log_message(self, format, *args):
        return

    def _send_json(self, code: int, payload: dict):
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_GET(self):
        if any(p in self.path for p in ("/status", "/health", "/models", "/voices")) or self.path in ("/", "/v1", "/v1/"):
            ready = ENGINE.is_ready()
            cat_voices = ENGINE.get_categorized_voices()
            flat_voices = [v for group in cat_voices.values() for v in group]
            model_items = [{"id": name, "object": "model", "owned_by": "KittenML"}
                           for name in ("kitten-nano", "kitten-micro")]


            if "voices" in self.path and not self.path.startswith("/status"):
                self._send_json(200, {
                    "object": "list",
                    "status": "ok" if ready else "model_missing",
                    "ready": ready,
                    **MODEL_CONTROL.status(),
                    "error": None if ready else ENGINE.model_error,
                    "active_slots": ENGINE.active_slots,
                    "current_slot": ENGINE.current_slot,
                    "voices": flat_voices,
                    "categorized_voices": cat_voices,
                    "voice_ids": flat_voices,
                    "data": [{"id": v, "name": v, "voice_id": v, "object": "voice"} for v in flat_voices],
                })
                return

            self._send_json(200, {
                "object": "list",
                "status": "ok" if ready else "model_missing",
                "ready": ready,
                    **MODEL_CONTROL.status(),
                "engine": "kitten-onnx" if ENGINE.kokoro is not None else "wsola-neural",
                "error": None if ready else ENGINE.model_error,
                "active_slots": ENGINE.active_slots,
                "current_slot": ENGINE.current_slot,
                "voices": cat_voices,
                "voice_ids": flat_voices,
                "models": ["kitten-nano", "kitten-micro"],
                "data": model_items,
            })
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 <= length <= 256 * 1024:
                self._send_json(413, {"error": "request too large"})
                return
            body = json.loads(self.rfile.read(length).decode("utf-8")) if length else {}
            if not isinstance(body, dict):
                raise ValueError("expected JSON object")
        except (ValueError, UnicodeError):
            self._send_json(400, {"error": "invalid JSON request"})
            return

        if self.path == "/suspend":
            ENGINE.audio_jobs.cancel_pending()
            self._send_json(200, {"status": "paused"})
            return

        if self.path == "/engine":
            try:
                MODEL_CONTROL.switch(str(body.get("model", "kokoro")))
                self._send_json(200, {
                    **MODEL_CONTROL.status(),
                    "active_slots": ENGINE.active_slots,
                    "current_slot": ENGINE.current_slot,
                    "voices": ENGINE.get_categorized_voices(),
                })
            except Exception as exc:
                self._send_json(503, {
                    **MODEL_CONTROL.status(),
                    "active_slots": ENGINE.active_slots,
                    "current_slot": ENGINE.current_slot,
                    "voices": ENGINE.get_categorized_voices(),
                    "error": str(exc),
                })
            return
        if self.path == "/delete_model":
            try:
                target_model = str(body.get("model", "kokoro"))
                removed = MODEL_CONTROL.delete_model(target_model)
                self._send_json(200, {
                    "status": "ok",
                    "deleted_model": target_model,
                    "removed_paths": removed,
                    **MODEL_CONTROL.status(),
                })
            except Exception as exc:
                self._send_json(500, {"status": "error", "error": str(exc)})
            return
        if self.path in ("/preload", "/synthesize") or "audio/speech" in self.path or "/tts" in self.path:
            try:
                MODEL_CONTROL.validate(body.get("engine"))
            except Exception as exc:
                self._send_json(409, {"error": str(exc)})
                return
        if "/synthesize" in self.path or "audio/speech" in self.path or "/tts" in self.path:
            text = (body.get("text") or body.get("input") or "hello").strip() or "hello"
            slot = body.get("slot")
            voice = body.get("voice")
            valid_voices = [v for g in ENGINE.get_categorized_voices().values() for v in g]
            if not voice or voice == "default" or voice not in valid_voices:
                voice = ENGINE.active_slots.get(slot or ENGINE.current_slot, "bf_emma")
            speed = float(body.get("speed", 1.0))
            try:
                wav_path = ENGINE.request_audio(text=text, voice=voice, speed=speed)
                if "audio/speech" in self.path:
                    wav_bytes = wav_path.read_bytes()
                    self.send_response(200)
                    self.send_header("Content-Type", "audio/wav")
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.send_header("Content-Length", str(len(wav_bytes)))
                    self.end_headers()
                    self.wfile.write(wav_bytes)
                else:
                    self._send_json(200, {"status": "ok", "wav_path": str(wav_path), "voice": voice, "speed": speed})
            except Exception as exc:
                self._send_json(503, {"status": "error", "error": str(exc)})
            return

        if "/preload" in self.path:
            phrases = body.get("phrases", [])
            start_idx = int(body.get("start_idx", 0))
            current_slot = body.get("current_slot")
            ENGINE.preload(start_idx=start_idx, phrases=phrases, current_slot=current_slot, speed=float(body.get("speed", 1.0)))
            self._send_json(200, {"status": "ok"})
            return

        if "/slots" in self.path:
            slots = body.get("active_slots", {})
            if isinstance(slots, dict) and slots:
                ENGINE.save_slots(slots)
            cur_slot = body.get("current_slot")
            if cur_slot in ENGINE.DEFAULT_SLOTS:
                ENGINE.current_slot = cur_slot
            self._send_json(200, {
                "status": "ok",
                "active_slots": ENGINE.active_slots,
                "current_slot": ENGINE.current_slot,
            })
            return

        self._send_json(404, {"error": "not found"})


def serve_on_port(port: int):
    try:
        srv = ReusableThreadingHTTPServer(("127.0.0.1", port), Handler)
        srv.serve_forever()
    except OSError as exc:
        print(f"[KokoroDaemon] Port {port} bind warning: {exc}", flush=True)


def watch_owner():
    try:
        owner = int(os.environ.get("LUMA_OWNER_PID", "0"))
    except ValueError:
        owner = 0
    clock = threading.Event()
    next_prune = time.monotonic() + 30
    while not clock.wait(5):
        if owner > 1:
            try:
                os.kill(owner, 0)
            except ProcessLookupError:
                os._exit(0)
            except PermissionError:
                pass
        idle = ENGINE.audio_jobs.idle_seconds()
        # Only app-owned services auto-exit; external API servers remain under their owner's control.
        if owner > 1 and idle >= 180 and not MODEL_CONTROL.switching:
            os._exit(0)
        if idle >= 10 and time.monotonic() >= next_prune:
            AUDIO_BUDGET.prune()
            next_prune = time.monotonic() + 120


if __name__ == "__main__":
    threading.Thread(target=watch_owner, daemon=True).start()
    threading.Thread(target=ENGINE._init_model, daemon=True).start()
    primary_port = int(os.environ.get("LUMA_KOKORO_PORT", "18880"))
    # Also listen on 8880 and 8000 in background threads so default SpeechServiceSettings endpoints work automatically
    for extra_port in (8880, 8000):
        if extra_port != primary_port:
            threading.Thread(target=serve_on_port, args=(extra_port,), daemon=True).start()
    serve_on_port(primary_port)
