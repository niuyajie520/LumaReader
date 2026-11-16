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

## Android：已按这份合同实现

`android/` 是一个独立 Gradle 工程（Kotlin 2.0.21 / AGP 8.7.3 / JDK 17 / minSdk 26）：

| 模块 | 内容 |
| --- | --- |
| `android/core` | 纯 Kotlin JVM，逐行对应 `Packages/LumaCore`：`DictationRules.kt`（判题 / 长措辞 / 纯英文输入）、`WordReview.kt`（艾宾浩斯 + 同日不推进 + FSRS 字段）、`DictationSession.kt`（四档阶梯、错词插回、错满 3 次挪队尾、退一档）、`VocabularyWord.kt`、`SyncMerge.kt` |
| `android/core/src/test` | `SpecFixtureTest.kt` 自带极简 JSON 解析器，**直接读 `spec/behaviour.json`** 逐条断言（10 个用例），不另写期望值 |
| `android/app` | Compose 界面：听写 / 阅读 / 词库 / 设置 四个 Tab，`StudyStore.kt` 读写同一份 `luma_study_store.json`，`SyncManager.kt` 用 SAF 目录做与 iOS 相同的 `device-*.json` 合并，`BookLibrary.kt` 自写 EPUB 解析（无第三方依赖） |

本地跑：

```bash
export JAVA_HOME=/path/to/jdk17
export ANDROID_HOME=/path/to/android-sdk
cd android
./gradlew :core:test :app:assembleDebug   # 或者用自己装的 gradle 8.10.2
```

一条命令出包：`bash Scripts/release.sh --target android`（跑内核测试 + 编 APK + 打源码包）。

## 仍与 iOS/macOS 不同的地方（都是 UI 层，不涉及规则）

- 阅读器：Android 是**滚动阅读 + 点击查词**（WebView + 注入取词脚本），没有照搬 iOS 那张「快照式分页」；
  分页是表现层，不影响学习数据。
- 朗读：三端都用系统 TTS，没有内置神经语音（macOS 那份 Kitten ONNX 依赖上位机进程，手机端跑不动）。
- 云同步：iPhone 用 iCloud Drive 目录，Android 用系统文件选择器授权的云盘目录，**文件格式与合并规则相同**，
  所以两个手机端可以互相同步；桌面端的数据靠 `导入/导出` 走同一个 JSON。
