# Swift 6 编译错误修正

用户的 Mac 构建记录确认原版在 DictationPracticeLayout.swift:51 的 Animatable 协议实现处编译失败。本版将第 52 行 size 与第 53 行 animatableData 显式标为 nonisolated，保留字体插值实现与主线程 body；没有使用 unsafe、@preconcurrency 或关闭并发检查。此状态只有值类型 CGFloat，不涉及 VM、AppKit 对象或共享引用。

同时为所有 .command 和 Scripts 下 .sh 文件补充执行位，并在 ZIP 中保留。

已静态检查修改差异；当前环境没有 macOS/SwiftUI 编译器，尚未在用户工具链重跑。不能宣称已通过编译。此前完整审查说明仍适用，新版以本修正说明为补充。

依据：https://github.com/swiftlang/swift-evolution/blob/main/proposals/0434-global-actor-isolated-types-usability.md
