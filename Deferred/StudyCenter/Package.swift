// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaReaderStudyKit",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v15) // Forward-compatible with macOS 15+ through macOS 27 SDK
    ],
    products: [
        .library(
            name: "LumaReaderStudyKit",
            targets: ["LumaReaderStudyKit"]
        )
    ],
    targets: [
        .target(
            name: "LumaReaderStudyKit",
            path: ".",
            exclude: ["README.md", "Tests"],
            sources: ["LumaStudyCenterAllInOne.swift", "StudyHome.swift", "StudyPersistence.swift", "DictationEngine.swift", "StudyPromptView.swift", "StudyAppearance.swift", "SpeechAudioPipeline.swift", "SpeechSettingsPanel.swift", "VocabularyImport.swift", "StudyMapDiagram.swift", "StudyReview.swift", "WritingReviewPanel.swift", "VocabularyImportReview.swift", "DictationReportView.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "LumaReaderStudyKitTests",
            dependencies: ["LumaReaderStudyKit"],
            path: "Tests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
