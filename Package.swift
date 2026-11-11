// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumaReader",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "LumaReader", targets: ["LumaReader"])],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20"),
                   .package(path: "Vendor/MaterialColorUtilities"),
                   .package(path: "Deferred/StudyCenter"),
                   .package(url:"https://github.com/kean/Pulse.git",exact:"5.2.3"),
                   .package(url:"https://github.com/kstenerud/KSCrash.git",exact:"2.6.1")],
    targets: [
        .target(name:"DiagnosticsC",linkerSettings:[.linkedLibrary("proc")]),
        .executableTarget(name: "LumaReader", dependencies: ["ZIPFoundation", "MaterialColorUtilities", "DiagnosticsC", .product(name:"LumaReaderStudyKit",package:"StudyCenter"), .product(name:"Pulse",package:"Pulse"), .product(name:"Recording",package:"KSCrash"), .product(name:"Monitors",package:"KSCrash")], resources: [.process("Resources")]),
        .testTarget(name: "LumaReaderTests", dependencies: ["LumaReader", "ZIPFoundation"], path: "Tests/LumaReaderTests", resources: [.copy("Fixtures")])
    ]
)
