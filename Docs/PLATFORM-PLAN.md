# 全平台更新计划（macOS / iPhone，为 Android 留口）

目标：**改一次规则，两端同时正确；加 Android 时不用重新猜一遍行为。**

## 现状（2026-11-16 晚）

- `Packages/LumaCore`：纯 Foundation 的规则层——判题、条目分类、长措辞门槛、复习调度、到期排序、
  **听写会话状态机**、**云同步合并**、词条模型、英文输入策略。
  不 import SwiftUI / AppKit / UIKit，不碰文件与网络。
- macOS（`Deferred/StudyCenter`）与 iPhone（`iOS/LumaReaderIOS`）都通过
  `XCLocalSwiftPackageReference` / `@_exported import LumaCore` 用同一个内核，
  两端的 `*Bridge.swift` 只有一行 import。
- `spec/behaviour.json`（`specification = 2`）+ `spec/constants.json`：可执行的跨平台合同，
  LumaCore 的测试直接读这份 JSON。
- 版本只有一个来源：`version.json`；`Scripts/release.sh --target macos|ios|both` 一条命令出两个平台的包。

## 三步走

1. **内核统一**（已完成）：iOS 工程通过 `XCLocalSwiftPackageReference` 引用 `Packages/LumaCore`，
   iOS 侧复制的判题/调度代码已删除；`generate_project.py` 负责生成这段引用。
2. **状态机内核化**（已完成）：`DictationSessionStateMachine` 在 `LumaCore`，两端各剩一层
   `@Observable` 薄封装（只管播报、滚屏、动效）。
3. **一条命令出包**（已完成）：`version.json` 是唯一版本源，`Scripts/sync-version.py` 把它写进
   `release.json` 与 iOS 工程；`Scripts/release.sh --target macos|ios|both [--test] [--install]`
   负责同步版本 → 构建 → 校验 → 打源码包。
4. **下一步（可选）**：数据层（`luma_study_store.json` 的读写与迁移）也抽到内核，
   让 Android 只写 UI 与文件授权。

## Android 怎么接

- **不要**尝试让 Swift 代码直接跑在 Android（没有官方 Swift-on-Android 生产路径；
  Kotlin/Native 也只能调 C，不是调 Swift）。
- 正确做法是**同一份规范、两套实现**：Kotlin 重写 `LumaCore` 里那几百行纯逻辑，
  用 `spec/behaviour.json` 做参数化测试（JUnit `@ParameterizedTest`），跑绿即等价。
  规则改动这天，两边都必须改 JSON 里的用例，否则测试挂。
- 数据层直接读写同一个 `luma_study_store.json`（`schemaVersion` + 前向迁移），
  Android 只管 UI（Compose）与文件授权（SAF），不做第二套字段。
- 设计 token（圆角 4/10/18、44pt 热区、按下 0.97、动效 ≤0.15 回弹）放在 `spec/constants.json`，
  Compose 的 Theme 从它生成——macOS 改一次，Android 下次构建自动跟上。

## 为什么不用别的方案

| 备选 | 为什么不选 |
| --- | --- |
| 一套 SwiftUI 两端跑 | macOS 要窗口/多栏/菜单栏，iPhone 要 Tab/手势；硬合并两边都别扭，还会被 DESIGN 规范反复打回 |
| 用 Kotlin Multiplatform 重写全部 | 现有 1.2 万行 StudyHome 是 AppKit 深度耦合，重写成本远高于收益 |
| 把逻辑编成 C/Rust 静态库两端调用 | 改动链路长（FFI 调试、符号表、交叉编译），收益只有「一份实现」，而规范+测试已经拿到同样保证 |
