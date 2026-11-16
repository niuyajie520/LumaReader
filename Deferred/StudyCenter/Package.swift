// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyCenter",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaReaderStudyKit", targets: ["LumaReaderStudyKit"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumaCore"),
    ],
    targets: [
        .target(
            name: "LumaReaderStudyKit",
            dependencies: ["LumaCore"],
            path: ".",
            exclude: ["Tests"],
            sources: [
                "BuiltInIELTSDictionary.swift",
                "DictationEngine.swift",
                "DictationUnitWrongWindow.swift",
                "RecentDictationDecksWindow.swift",
                "DictationThemeErrorAccent.swift",
                "DictationPracticeLayout.swift",
                "DictationShortcutPolicy.swift",
                "EmbeddedNeuralSpeechEngine.swift",
                "IELTSOfficialRubricEngine.swift",
                "LumaDesignTokens.swift",
                "LumaStudyCenterAllInOne.swift",
                "SpeechAudioPipeline.swift",
                "StudyAppearance.swift",
                "LumaTextScale.swift",
                "VisualThemeBackdrop.swift",
                "HeroScenes.swift", "HeroImageOverride.swift",
                "StudyHome.swift",
                "StudyPersistence.swift",
                "StudyPromptView.swift",
                "StudyReview.swift",
                "ReadingVocabularyView.swift",
                "IELTSReadingPractice.swift",
                "ReadingChoiceQuiz.swift",
                "WrongWordsCenter.swift",
                "StudyWorkspace.swift",
                "VocabularyImport.swift",
                "VocabularyLibraryCleanup.swift",
                "VocabularyImportReview.swift",
                "ConfusablePractice.swift",
                "ConfusableViews.swift",
                "MiniPracticeWindow.swift",
                "StarMangaScenes.swift",
                "LumaButtonSystem.swift",
                "LumaCoreBridge.swift",
            ],
            resources: [.copy("Resources/CoraVocabulary"), .copy("Resources/ReadingVocabulary.json"), .copy("Resources/IELTSReadingSamples.json"),
                        .copy("Resources/IELTSReadingLayoutSample.json"),
                        .copy("Resources/IELTSReadingRainwaterDiagram.png")]
        ),
        .testTarget(
            name: "LumaReaderStudyKitTests",
            dependencies: ["LumaReaderStudyKit"],
            path: "Tests"
        ),
    ]
)
