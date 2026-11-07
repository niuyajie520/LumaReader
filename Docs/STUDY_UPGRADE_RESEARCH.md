# Study upgrade research and current limits

Reviewed 2026-11-07. These are source/documentation reviews, not completed hardware benchmarks.

| Candidate | Evidence / integration | Decision |
|---|---|---|
| Apple HSplitView / NSSplitView | Native macOS split-view layout and divider ownership; no external runtime | Replace custom local-coordinate DragGesture with HSplitView |
| Apple NSTextView | Native selection, attributed text and context menus | Read-only selectable prompt with highlight/remove; highlights currently session-only |
| IDP familiarisation | Official reference for two writing tasks, timer and exam interaction; not reusable application source | Reference interaction, retain original prompts |
| sherpa-onnx | Apache-2.0 runtime, Swift examples, macOS support and active changelog; model licences separate | Strong ONNX integration candidate; not installed or benchmarked here |
| mlx-audio-swift | MIT Swift SDK, Apple Silicon focus, releases and streaming implementations | Native MLX candidate; model weights, memory and exact toolchain need integration validation |
| mlx-audio | Python MLX implementation | Useful reference, adds Python runtime burden for a native application |
| Qwen3-TTS | Official expressive/streaming model implementation | Higher integration and weight cost; published latency is not a measurement of this application |
| Kokoro-82M | Apache-2.0 model weights; phonemizer dependencies require separate licence review | Small-model candidate, no verified inference engine currently installed |
| Piper | Current OHF runtime and individual voice licences need separate review | Not included in this build |
| Apple AVSpeechSynthesizer | Already integrated, installed voices only | Actual available engine for this build; premium/enhanced rate up to 1.8x, standard fallback remains 1.0x |

Sources:
- https://developer.apple.com/documentation/swiftui/hsplitview
- https://developer.apple.com/documentation/appkit/nssplitview
- https://developer.apple.com/documentation/appkit/nstextview
- https://ielts.idp.com/about/ielts-familiarisation-tests
- https://github.com/k2-fsa/sherpa-onnx
- https://github.com/Blaizzy/mlx-audio-swift
- https://github.com/Blaizzy/mlx-audio
- https://github.com/QwenLM/Qwen3-TTS
- https://huggingface.co/hexgrad/Kokoro-82M
- https://github.com/OHF-Voice/piper1-gpl

No local neural model or cloud TTS provider was integrated. Cold-start, memory, GPU and 300 ms cache playback targets have NOT been measured. No inference/cache performance claim is made. Full visual redesign, Monet propagation, cloud/model settings, repeat/interval settings and graph zoom remain incomplete.

Timer: use a stable SwiftUI task and ContinuousClock elapsed duration instead of counting delivery of a newly created Combine publisher. Remaining time catches up after delayed main-thread execution; pause suspends accounting. Native device tests for sustained typing are still required.
