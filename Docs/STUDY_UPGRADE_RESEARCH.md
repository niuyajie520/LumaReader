# Study centre: research, selection and acceptance scope

Reviewed 2026-11-07. Upstream facts are from the primary links below. Repository metadata is a review-time snapshot, not a claim about future maintenance or quality. Benchmarks are measured on GitHub macOS ARM64 runners, not the user's Mac.

## Native interface and exam architecture

| Concern | Compared approaches | Selection and reason |
|---|---|---|
| Overall layout | Apple HIG/Books, Bear's theme-wide editor treatment, web exam shells | Adaptive book-like study shelves, semantic paper/ink/accent/surface roles inherited from the reader/Monet palette, focused practice; preserve native window management |
| Dividers | Custom local-coordinate DragGesture, HSplitView, manual NSSplitViewDelegate | HSplitView owns the native divider and constraints; native tests manipulate the resulting NSSplitView and ensure the essay remains intact |
| Countdown | Recreated Combine publisher counting ticks, wall-clock deadline, monotonic elapsed time | Stable task plus ContinuousClock elapsed accounting. One draft owns both task answers and the shared timer. New 20/40/60-minute sessions have unique IDs; explicit draft reopening preserves old content |
| Text input | SwiftUI TextEditor, WKWebView editor, NSTextView | Native exam-only NSTextView policy preserves English verbatim, suppresses correction/completion, rejects CJK committed/marked input; other app editors are unchanged |
| Highlight | Transient attributed text, persisted character ranges | Read-only native prompt with validated UTF-16 ranges, merge/remove operations and persistence in each draft/part |
| Figures | Data-only lists, native Swift Charts, unavailable original images | Swift Charts for numeric data, expandable figures, source-labelled schematic maps and process steps. Map diagrams are explicitly not to scale; raw source data remains available. No copyrighted test images are invented |
| Motion/material | Custom web animation stack, blanket glass, native controls | Native sheets/context menus/controls; restrained mode transition respecting Reduce Motion. Paper and writing content remain opaque/readable. Existing reader/AI transitions remain intact |

Primary references:
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/swiftui/hsplitview
- https://developer.apple.com/documentation/appkit/nssplitview
- https://developer.apple.com/documentation/appkit/nstextview
- https://developer.apple.com/documentation/avfaudio/avaudioplayer/preparetoplay()
- https://bear.app/faq/about-free-and-pro-themes-in-bear/
- https://ielts.idp.com/about/ielts-familiarisation-tests
- https://ielts.org/take-a-test/test-types/ielts-on-computer-writing-on-paper

IELTS web candidates inspected: `ujjawalpoudel/ielts-write` (root README/HTML/JS/CSS, no test directory or declared licence in the reviewed metadata, 0 stars) and `Arittra95/computer-based-ielts-writing-test-interface` (Apache-2.0, root README/HTML, 3 stars). They demonstrate exam interaction, but neither establishes native macOS/Swift regression coverage. They are references, not adopted runtime dependencies. IDP/British Council/Bear are product references, not reusable source or a claim that this application is an official IELTS product.

## Speech candidates

| Project | Licence/integration evidence | Performance and selection |
|---|---|---|
| k2-fsa/sherpa-onnx | Apache-2.0 runtime, Swift/C++/Python APIs, macOS support, active repository | Selected local worker: separately installed VITS model loaded once, two CPU threads, serial generation; actual US/GB model inference and production audio playback are tested |
| Neywa-Labs/mlx-audio-swift (formerly Blaizzy) | MIT, Swift/MLX SDK, Tests directory, active at review | Strong native Apple Silicon candidate, but not linked into this build. Full model-specific Swift quality/memory coverage was not independently established |
| Neywa-Labs/mlx-audio (formerly Blaizzy) | MIT, Python/MLX server with OpenAI-compatible speech route, tests directory | Existing compatible local services can be selected through the verified service adapter; the app does not install Python or weights automatically |
| QwenLM/Qwen3-TTS | Apache-2.0 reference project; expressive and streaming architecture | Larger deployment burden than a small VITS word model. No Qwen weight/runtime benchmark performed here; no latency or memory number is claimed |
| hexgrad/Kokoro-82M | Apache-2.0 weights; inference/phonemizer dependencies have separate licences | Small-model candidate. No Kokoro inference implementation or weights are bundled or claimed to be installed; compatible externally installed services must pass audio verification |
| OHF-Voice/piper1-gpl | Current runtime GPL-3.0; individual voices/licences separate | No Piper runtime is bundled. CI uses separately downloaded VITS model packs through sherpa for evaluation only; model archives are not redistributed |
| Apple AVSpeechSynthesizer | OS-provided runtime, actual installed voices | Default engine. Exact selected installed voice; automatic female preference never silently switches requested accent. Standard mechanical voices lock normal speed; enhanced voice requests support up to 1.8x |

Sources:
- https://github.com/k2-fsa/sherpa-onnx
- https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/offline-tts.py
- https://github.com/Neywa-Labs/mlx-audio-swift
- https://github.com/Neywa-Labs/mlx-audio
- https://github.com/Neywa-Labs/mlx-audio/blob/main/docs/guides/web-ui-api-server.md
- https://github.com/QwenLM/Qwen3-TTS
- https://huggingface.co/hexgrad/Kokoro-82M
- https://github.com/OHF-Voice/piper1-gpl

The service adapter accepts HTTPS remote endpoints or loopback HTTP only. The service's live model list is not treated as proof of TTS support: generated audio must decode successfully before enabling. API credentials live in macOS Keychain. Validation/playback of a configured paid service occurs only through explicit user actions; no paid keys are used in CI. Cloud-service unit/protocol tests are not a paid-provider end-to-end benchmark.

## Residency, prefetch and resource policy

- The supplied loopback sherpa worker loads one licensed, separately installed model once and never logs words or headers. For example: `python Scripts/StudySpeech/sherpa_service.py --model-dir /path/to/model --model-id my-voice --port 8765`. Its optional Python environment requires `sherpa-onnx==1.12.34` and `numpy==2.2.6`.
- Production Swift uses exact-input memory-only LRU keys (endpoint, model, voice, word, rate, credential), shared in-flight requests and at most two active fetches.
- Low power/balanced/high-quality profiles allow 16/48/96 MiB raw audio cache and zero/two/four-word look-ahead. Quality stays with the explicitly selected model; profiles do not pretend to change arbitrary remote GPU settings.
- A separate audio actor owns at most five prepared AVAudioPlayer instances. Decode/preparation does not block SwiftUI. Cancellation IDs prevent stale playback after rapid navigation or engine changes.
- Service verification plays a real hello audition before enabling the engine; first-audition submission is reported separately from subsequent cached playback. Players pause on navigation to retain prepared resources and are bounded/evicted normally. Prepared audio is prewarmed along with upcoming generated words. An observed 331 ms preparation in an earlier benchmark was not waived; player prewarming was added while retaining the 300 ms test.

## Reproducible acceptance

`.github/workflows/study-speech-benchmark.yml` installs a pinned runtime and benchmarks real `vits-piper-en_US-lessac-medium` and `vits-piper-en_GB-cori-medium` packs in isolated runner storage. It records model/archive provenance, load/first/warm inference, audio duration, peak RSS and production Swift warm-cache player submission. Installed UK/US Apple speech voices are measured using actual didStart callbacks. Generated WAV samples must be nonempty/non-silent. Model files and raw speech are not included in the uploaded numeric report.

The 300 ms measure is the cached audio's native player preparation/submission, not microphone-measured speaker latency. Perceptual naturalness, speaker audibility, physical trackpad/keyboard behaviour and user-device GPU/thermal performance cannot be inferred from CI. Qwen/Kokoro/other uninstalled models have no fabricated measurements.

Swift tests cover cache coalescing/isolation/eviction/failure, actual native player playback, continuous native editor insertion while the countdown progresses, CJK commit/marked-text rejection, NSSplitView position changes without text loss, persistent highlighting, vocabulary import/deduplication, original-essay score validation, separate drafts/review queues and damaged-store recovery. Full app CI retains the reader regressions, Debug/Release ARM64, signing, launch, privacy gates and source/package checks. App screenshots use synthetic content; a best-effort native-window capture is clearly distinguished from cached control snapshots. No physical input acceptance is claimed.

## Data and review behaviour

TSV/JSON imports merge stable word IDs without deleting existing decks or records. Normal/wrong/stubborn review queues have separate persisted keys. New writing sessions do not overwrite another draft for the same question. Original submitted essays are saved before optional assessment. Real AI assessment uses the existing configured client only after the user explicitly sends that essay; invalid band values or corrections quoting nonexistent sentences are rejected. Unconfigured/failed grading remains pending and never substitutes fixed example scores. The app is ad-hoc signed and not Apple notarized; no formal Release or PR merge is performed automatically.


## Correction, review and import update (2026-11-07)

Compared the maintained MIT-licensed `open-spaced-repetition/swift-fsrs` package (tests and CI present) and Anki's documented relearning/Again behaviour. FSRS models long-term retention; it does not implement this user's required spelling gate. This update therefore keeps the explicit correction state machine and transparent 1/3/7/14/30-day intervals, without claiming an FSRS memory model. References: https://github.com/open-spaced-repetition/swift-fsrs and https://docs.ankiweb.net/studying.html . Native SwiftUI List/TextField and the existing NSTextView editor avoid a web editor dependency for review/import.

Wrong input never advances the current word. After a failed attempt, optional spelling help is available; successful correction schedules one randomized retrieval after 2–5 other tasks where enough tasks remain. Only clean retrieval completes that cycle. The sixth daily error promotes a stubborn word; it must still be corrected before advancing, and no further automatic retry is queued. Raw attempts stay unchanged; matching ignores case, punctuation, symbols, spacing and control characters, while wrong letters/digits and CJK still matter. This intentionally treats apostrophes and hyphens as non-scoring separators, not spelling errors. Existing older stubborn records are retained.

Completed-session reports sort actual session errors descending and export UTF-8 BOM CSV through a native save panel. Corrected quarantined words are labelled stubborn, not mastered. Import previews edit/deselect invalid rows, deduplicate confirmed content and preserve existing definitions/IDs. No records change before confirmation. Writing comparisons show the immutable original and classified AI suggestions when available; independent English rewrite versions autosave and reopen without replacing the original or inventing feedback. AI feedback's optional kind field distinguishes actual errors from optional upgrades; legacy unclassified suggestions remain labelled unclassified.

Writing revision snapshots also preserve a read-only suggested draft, formed only from uniquely located, non-overlapping AI quotations. Ambiguous quotations remain in sentence feedback for manual review. Original, suggested and rewritten versions remain separate; no synthetic feedback is produced when grading is absent.


## Independent reading/listening/writing workspaces

A window-owned opaque LumaStudySession retains the study model while reader/library views replace study views. Listening and writing remember separate destinations; queued retries, correction gates, raw unsubmitted input, active draft ID and remaining time are checkpointed in optional backward-compatible workspace state. Restoring input requires the same word ID, and restoring an exam requires a known saved draft/question. Switching away suspends pronunciation and writing countdown; returning resumes at the same input/question without starting a new attempt. Explicit start/new-exam actions remain available. The existing reader store retains EPUB/PDF positions, with a separate last-book continuation entry and menu shortcuts. Study and reader engines are not forced to stay mounted invisibly. Native tests remove/recreate study hosts and verify essay/input/clock continuity, and the app probe exercises a real reader/study/reader round trip with synthetic content.
