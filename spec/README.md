# LumaCore 行为规范（跨平台契约）

这里的文件不是给人读的文档，是**给移植用的合同**：macOS 版（Swift）与 iPhone 版（Swift）
共用 `Packages/LumaCore` 里的实现，将来 Android（Kotlin）必须逐条通过同一组用例，
才能声称「规则一致」。

## 为什么要有这一层

听写判题、复习间隔、错词调度这些规则一旦在两端各写一遍，就会像 2026-11 那次一样漂移：
iOS 的 `isFirstAttemptInSession` 恒为 true，macOS 没有这个 bug；同一个调度改动要在两个仓库改两遍。
把规则抽到 `LumaCore` + 一份可执行的行为清单，漂移会立刻被测试抓住。

## 目录

| 文件 | 内容 |
| --- | --- |
| `behaviour.json` | 全部行为用例（输入 → 期望输出），机器可读，供 Kotlin 移植逐条对照 |
| `constants.json` | 可调参数：四档阶梯、错词偏移、艾宾浩斯间隔、长措辞阈值、虚词表 |

`Packages/LumaCore/Tests/LumaCoreTests/RuleFixtureTests.swift` 断言的正是这两个文件里的条目。
改规则 = 改 `behaviour.json` + 改实现 + 把 `LumaCoreVersion.specification` 加一。

## 移植时要遵守的边界

`LumaCore` 里**不允许**出现：SwiftUI / AppKit / UIKit、文件读写、网络、`UserDefaults`、当前时间以外的环境依赖
（`Date` 与 `Calendar` 都从参数传入，方便测试与移植）。

时间相关函数一律接受 `now` 与 `calendar`，不用隐式当前时间——Android 侧只要传同样的
`ZonedDateTime` 与 `Calendar`（或 `java.time`）就能得到同样的结果。

## Android 的路线

1. 用 Kotlin 实现 `DictationAnswerPolicy`、`DictationPhraseDiff`、`DictationEntryKind`、
   `WordReviewProgress.record(...)`、`WordReviewOrdering.dueFirst(...)`。
2. 把 `behaviour.json` 读进 JUnit 参数化测试，逐条断言。
3. 数据层直接复用同一份 `luma_study_store.json`（`schemaVersion` 相同），
   Compose 只做 UI；不要另起一套字段。
4. UI 规范（颜色、字号、圆角、动效时长）放在 `constants.json` 的 `design` 段，
   Compose 的 Theme 从这里生成，避免「iOS 改完 Android 还是旧尺寸」。

## 谁在用 LumaCore

- macOS（`Deferred/StudyCenter`）：`LumaCoreBridge.swift` 里 `@_exported import LumaCore`，
  判题、复习日程、词条模型全部走内核。
- iPhone（`iOS/LumaReaderIOS`）：`generate_project.py` 用 `XCLocalSwiftPackageReference`
  指向 `../Packages/LumaCore`，app target 链接 `LumaCore` 产品；`Core/LumaCoreBridge.swift`
  同样 `@_exported import LumaCore`，iOS 侧的判题 / 长措辞小错 / 词条分类代码已删除。
- Android：还没开始，先把 `behaviour.json` 当验收清单。

## 内核里已经有什么（specification = 2）

| 模块 | 文件 | 覆盖内容 |
| --- | --- | --- |
| 判题 | `DictationRules.swift` | 规范化、连字符/空格互换、长措辞虚词小错 |
| 复习日程 | `WordReview.swift` | 艾宾浩斯 1/3/5/7/10/14、同日不推进、隔天到期优先 |
| 听写会话 | `DictationSession.swift` | 四档词距、快速过词跳题、错词插回、三档退档、顽固词 |
| 云同步 | `SyncMerge.swift` | 词条/进度/日志/顽固词/慢反应/每日阅读的合并规则 |

macOS 与 iPhone 都链接 `LumaCore`，两边的 `*Bridge.swift` 只做 `@_exported import`，
所以判定逻辑改一次两端同时生效。

## 现在还没抽出来的部分

- **数据落盘**：`luma_study_store.json` 的字段读写、schemaVersion 迁移、备份策略仍在各平台的持久层里
  （`StudyPersistence` / `Core/StudyStore.swift`）。字段名以 `docs/PLATFORM-PLAN.md` 的表格为准。
- **界面**：没有也不应该进内核——macOS 用 AppKit + SwiftUI，iPhone 用 SwiftUI，Android 用 Compose。
- **合成语音**：macOS 走本地 ONNX（Kitten 15M/41M + Python 守护进程），iPhone 目前用系统语音，
  Android 建议先用系统 TTS，再接同一个 ONNX 模型。
