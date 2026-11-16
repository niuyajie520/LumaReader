// swift-tools-version: 6.0
import PackageDescription

// LumaCore：两端（macOS / iPhone，将来 Android 走 Kotlin 移植）共用的纯逻辑。
// 这里的规则不能 import SwiftUI / AppKit / UIKit，也不能碰文件系统与用户界面，
// 这样它才能被单元测试、被 iOS 工程、以及将来的 Android 实现逐条对照。
let package = Package(
    name: "LumaCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "LumaCore", targets: ["LumaCore"]),
    ],
    targets: [
        .target(name: "LumaCore", path: "Sources/LumaCore"),
        .testTarget(name: "LumaCoreTests", dependencies: ["LumaCore"], path: "Tests/LumaCoreTests"),
    ]
)
