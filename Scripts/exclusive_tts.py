"""One loaded neural backend. Supports switching models, persisting per-model voice slots, and deleting unwanted model files on request."""
import gc
import json
from pathlib import Path
import shutil
import threading

MODEL_IDS = {
    'kitten-nano': 'KittenML/kitten-tts-nano-0.8-int8',
    'kitten-micro': 'KittenML/kitten-tts-micro-0.8',
}
KITTEN_VOICES = ['Bella', 'Jasper', 'Luna', 'Bruno', 'Rosie', 'Hugo', 'Kiki', 'Leo']
KITTEN_DEFAULT_SLOTS = {
    'US_Female': 'Bella',
    'US_Male': 'Jasper',
    'UK_Female': 'Luna',
    'UK_Male': 'Bruno',
}


class KittenAdapter:
    def __init__(self, name, cache):
        from kittenml import KittenTTS
        try:
            local = json.loads((Path(cache).parent / 'models-installed.json').read_text()).get(name)
        except (OSError, ValueError):
            local = None
        source = local if local and Path(local).is_dir() else MODEL_IDS[name]
        from bounded_onnx import bounded_sessions
        with bounded_sessions():
            self.model = KittenTTS(source, cache_dir=str(cache), backend='cpu')

    def get_voices(self):
        return list(self.model.available_voices)

    def create(self, text, voice, speed=1.0, lang=None):
        return self.model.generate(text, voice=voice, speed=1.0), 24000


class ExclusiveModels:
    def __init__(self, engine, base, loader=None):
        self.engine = engine
        self.base = Path(base)
        self.file = self.base / 'config' / 'exclusive-engine.json'
        self.lock = threading.RLock()
        self.switch_lock = threading.Lock()
        self.old_render = engine.synthesize_with_wsola_and_padding
        self.old_voices = engine.get_categorized_voices
        self.old_save_slots = engine.save_slots
        self.loader = loader
        self.ready = False
        self.switching = False
        self.voice_sets = {}
        try:
            saved = json.loads(self.file.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            saved = {}
        self.selected = saved.get('model', 'kitten-micro')
        if self.selected not in MODEL_IDS:
            self.selected = 'kitten-micro'
        raw_voice_sets = saved.get('voices', {})
        if isinstance(raw_voice_sets, dict):
            self.voice_sets = raw_voice_sets
        self.voice_sets.pop('kokoro', None)
        for k_model in ('kitten-micro', 'kitten-nano'):
            existing = self.voice_sets.get(k_model)
            if not isinstance(existing, dict) or len(set(existing.values())) <= 1:
                self.voice_sets[k_model] = KITTEN_DEFAULT_SLOTS.copy()
        engine.selected_model = self.selected
        engine.active_slots = self._defaults_for(self.selected)
        engine.model_epoch = 0
        engine._init_model = self.ensure_loaded
        engine.is_ready = lambda: self.ready and not self.switching
        engine.get_categorized_voices = self.voices
        engine.synthesize_checked = self.render_checked
        engine.save_slots = self.save_slots

    def _defaults_for(self, model_name):
        base_defaults = KITTEN_DEFAULT_SLOTS.copy()
        saved_slots = self.voice_sets.get(model_name)
        if isinstance(saved_slots, dict):
            if len(set(saved_slots.values())) <= 1:
                return base_defaults
            merged = base_defaults.copy()
            for k in base_defaults:
                if saved_slots.get(k):
                    merged[k] = saved_slots[k]
            return merged
        return base_defaults

    def _load_locked(self):
        e = self.engine
        if self.ready:
            return
        e.active_slots = self._defaults_for(self.selected)
        if self.loader is not None:
            e.kokoro = self.loader(self.selected)
        else:
            try:
                e.kokoro = KittenAdapter(self.selected, self.base / 'kitten-cache')
            except Exception as exc:
                e.kokoro = None
                e.fallback_ready = True
                raise RuntimeError(f'{self.selected} 模型未安装或加载失败: {exc}') from exc
        e.model_error = None
        e.fallback_ready = True
        e._init_event.set()
        self.ready = True

    def ensure_loaded(self):
        with self.lock:
            try:
                self._load_locked()
            except Exception as exc:
                self.engine.kokoro = None
                self.ready = False
                self.engine.fallback_ready = True
                self.engine.model_error = str(exc)
                self.engine._init_event.set()

    def _persist(self):
        self.voice_sets[self.selected] = self.engine.active_slots.copy()
        self.file.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.file.with_suffix('.tmp')
        tmp.write_text(json.dumps({'model': self.selected, 'voices': self.voice_sets}, ensure_ascii=False, indent=2), encoding='utf-8')
        tmp.replace(self.file)

    def switch(self, name):
        if name not in MODEL_IDS:
            raise ValueError('未知语音模型')
        with self.switch_lock:
            self.switching = True
            # Invalidate all old queued results before waiting for a running inference.
            self.engine.model_epoch += 1
            self.engine.audio_jobs.preload([])
            try:
                with self.lock:
                    self.voice_sets[self.selected] = self.engine.active_slots.copy()
                    self.ready = False
                    self.engine.kokoro = None
                    gc.collect()
                    self.selected = name
                    self.engine.selected_model = name
                    self.engine.active_slots = self._defaults_for(name)
                    self.engine._init_event.clear()
                    try:
                        self._load_locked()
                    except Exception as exc:
                        self.engine.kokoro = None
                        self.engine.model_error = str(exc)
                        self.engine.fallback_ready = True
                        self.engine._init_event.set()
                        self._persist()
                        raise
                    else:
                        self._persist()
            finally:
                self.switching = False

    def delete_model(self, name):
        if name not in MODEL_IDS:
            raise ValueError('未知语音模型')
        removed_paths = []
        with self.switch_lock:
            with self.lock:
                if self.selected == name:
                    self.ready = False
                    self.engine.kokoro = None
                    gc.collect()
                alt_dir = self.base.parent / 'KokoroTTS'
                slug = 'models--KittenML--kitten-tts-micro-0.8' if name == 'kitten-micro' else 'models--KittenML--kitten-tts-nano-0.8-int8'
                for cache_root in (self.base / 'kitten-cache', alt_dir / 'kitten-cache'):
                    target_dir = cache_root / slug
                    if target_dir.exists():
                        shutil.rmtree(target_dir)
                        removed_paths.append(str(target_dir))
                for inst_file in (self.base / 'models-installed.json', alt_dir / 'models-installed.json'):
                    if inst_file.is_file():
                        try:
                            data = json.loads(inst_file.read_text(encoding='utf-8'))
                            if isinstance(data, dict) and name in data:
                                custom_path = data.pop(name, None)
                                allowed = [(self.base / 'kitten-cache').resolve(), (alt_dir / 'kitten-cache').resolve()]
                                safe = custom_path and any(Path(custom_path).resolve().is_relative_to(folder / slug) for folder in allowed)
                                if safe and Path(custom_path).exists():
                                    if Path(custom_path).is_dir():
                                        shutil.rmtree(custom_path, ignore_errors=True)
                                    else:
                                        Path(custom_path).unlink(missing_ok=True)
                                    removed_paths.append(str(custom_path))
                                inst_file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
                        except Exception:
                            pass
        return removed_paths

    def render_checked(self, text, voice, speed, epoch):
        with self.lock:
            if self.switching or epoch != self.engine.model_epoch:
                raise RuntimeError('语音模型已切换，旧任务已取消')
            if not self.ready and self.loader is not None:
                self._load_locked()
            elif not self.ready and not self.engine._init_event.is_set():
                self.ensure_loaded()
            if not self.ready:
                raise RuntimeError(self.engine.model_error or '本地神经模型尚未就绪')
            result = self.old_render(text, voice, 1.0)
            if self.switching or epoch != self.engine.model_epoch:
                raise RuntimeError('旧模型结果已丢弃')
            return result

    def voices(self):
        return {slot: KITTEN_VOICES.copy() for slot in self.engine.DEFAULT_SLOTS}

    def validate(self, name):
        if name is not None and name != self.selected:
            raise RuntimeError('请求已过期：语音模型不匹配')
        if self.switching:
            raise RuntimeError('语音模型正在切换')

    def save_slots(self, slots):
        with self.lock:
            self.old_save_slots(slots)
            self._persist()

    def status(self):
        return {
            'model_id': self.selected,
            'switching': self.switching,
            'ready': self.ready and not self.switching,
            'neural_loaded': self.ready and not self.switching,
            'error': self.engine.model_error,
        }
