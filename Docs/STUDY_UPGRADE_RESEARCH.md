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

## Follow-up implementation and review

The earlier "incomplete" paragraph is a historical checkpoint. Subsequent implementation uses a verified OpenAI-compatible speech-service adapter for resident local MLX/sherpa services and optional configured HTTPS services. Credentials use macOS Keychain. Models come from the service's live list and require a decodable audio validation request before enabling. No end-user weight downloads occur automatically. A loopback-only sherpa worker loads one separately installed VITS model exactly once, serialises generation and never logs exercise text.

The production Swift audio cache is memory-only, exact-input keyed, request-coalescing, bounded (16/48/96 MiB), with no more than two active fetches. Profiles choose zero/two/four-word look-ahead; model quality stays with the explicitly selected model. Prefetch runs at utility priority. Stop/cancel tokens prevent stale audio from starting. These are resource policies, not claims that an arbitrary remote model can be made high quality or use less GPU memory.

Actual macOS benchmark workflow uses pinned sherpa-onnx 1.12.34, two CPU threads and separate US lessac/GB cori medium model packs. It reports archive provenance/digest, load/first/warm inference, PCM duration, peak RSS and production Swift warm-cache AVAudioPlayer submission. An early runtime pin was unavailable on macOS; a subsequent failed playback test was retained and diagnosed. Both actual VITS model/playback jobs passed on commit e2aef6552e7b778e0e1575e6bbf5e9867eb8bb91. Newer commits must rerun these gates. None of these measurements establishes physical speaker latency or perceptual naturalness.

Additional primary references:
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/avfaudio/avaudioplayer/preparetoplay()
- https://bear.app/faq/about-free-and-pro-themes-in-bear/
- https://github.com/Blaizzy/mlx-audio/blob/main/docs/guides/web-ui-api-server.md
- https://github.com/ujjawalpoudel/ielts-write
- https://github.com/Arittra95/computer-based-ielts-writing-test-interface

Repository metadata review: sherpa-onnx is active and Apache-2.0; Qwen3-TTS declares Apache-2.0; current OHF Piper declares GPL-3.0. Runtime, phonemizer and individual voice licences are separate. The IELTS web candidates are small projects (0 and 3 stars at review), one lacking a declared repository licence in API metadata. Neither establishes production macOS/Swift coverage. They are interaction references, not adopted dependencies. Bear is a commercial visual reference, not reusable source. Native SwiftUI/AppKit controls avoid adding those web runtimes and preserve native input handling.

UI changes now include adaptive listening/writing shelves, safe TSV/JSON vocabulary import, focused practice with restored sidebar/AI state on exit, semantic reader/Monet roles throughout native views, native resizable exam panes, persistent selection ranges, native Swift Charts and zoom, actual date filters, per-session drafts and explicit optional AI grading through the existing configured client. New native tests type repeatedly in the actual exam editor, reject CJK insertions, drag NSSplitView without altering essay text and verify countdown/persisted content. These are automated native controls tests, not physical Mac hardware acceptance.
