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
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "LumaReaderStudyKitTests",
            dependencies: ["LumaReaderStudyKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
