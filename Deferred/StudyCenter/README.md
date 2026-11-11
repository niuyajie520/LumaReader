# LumaReaderStudyKit

Independent Swift 6/macOS study module, linked into the main LumaReader package through a local SwiftPM dependency. `StudyCenterScreen` bridges reader themes and explicitly requested AI assessment into the module. Source location is retained for compatibility; this module is no longer deferred or excluded from the app.

- `StudyHome.swift`: shelves, import, dictation sessions, drafts, statistics and persistence coordination.
- `DictationEngine.swift`: answer checking and retry queues.
- `StudyPersistence.swift`: versioned atomic snapshots, backup recovery and preserved damaged data.
- `SpeechAudioPipeline.swift` / `SpeechSettingsPanel.swift`: installed system speech, verified local/cloud audio service, bounded cache/prefetch and native prepared players.
- `StudyPromptView.swift` / `StudyMapDiagram.swift`: persistent prompt highlights and source-labelled map schematics.
- `StudyAppearance.swift`: shared reader palette.
- `LumaStudyCenterAllInOne.swift`: existing public models, exam input controls and writing/chart views retained while extracting responsibilities incrementally.

Run `swift test --package-path Deferred/StudyCenter` on macOS with Swift 6. The main application and ARM64 packaging are verified separately by the native workflow. See `Docs/STUDY_UPGRADE_RESEARCH.md` for primary sources, selection decisions, speech service requirements and the distinction between programmatic macOS tests and physical-user acceptance.

No neural model weights or Python runtime are bundled. Apple installed speech works without a separate service; optional local neural speech requires an already installed compatible service or the separately run `Scripts/StudySpeech/sherpa_service.py`. A model is enabled only after actual audio validation. Cloud speech and AI grading use explicit user actions and preserve original study data on failure.
