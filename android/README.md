# Luma Reader · Android

听写 / 阅读 / 词库 / 设置 四块，与 macOS、iPhone 共用同一套判题与复习规则。

## 工程结构

```
android/
├── settings.gradle.kts         # :core :app
├── build.gradle.kts            # AGP 8.7.3 / Kotlin 2.0.21 / Compose plugin
├── core/                       # 纯 Kotlin JVM（无 Android 依赖，可在 JVM 上直接测）
│   └── src/main/kotlin/app/luma/core/
│       ├── DictationRules.kt   # 判题、长措辞虚词小错、纯英文输入校验
│       ├── WordReview.kt       # 艾宾浩斯 + 同日不推进 + FSRS 字段
│       ├── DictationSession.kt # 状态机：四档阶梯、错词插回、退一档、挪队尾
│       ├── VocabularyWord.kt
│       └── SyncMerge.kt        # 多设备合并（并集 / 取较晚进度 / 日志按 id 去重）
├── app/                        # Compose 界面
│   └── src/main/kotlin/app/luma/android/
│       ├── MainActivity.kt     # 四个 Tab
│       ├── StudyStore.kt       # 读写 luma_study_store.json（与 macOS 同格式）
│       ├── DictationSession.kt # 状态机 + 取词范围
│       ├── BookLibrary.kt      # 自写 EPUB 解析（zip + container.xml + OPF）
│       ├── Speaker.kt          # 系统 TTS（en-US / en-GB）
│       ├── SyncManager.kt      # SAF 目录 + device-*.json
│       └── ui/                 # DictationTab / ReaderTab / VocabularyTab / SettingsTab / Theme
└── README.md
```

## 编译

需要 JDK 17 与 Android SDK（platform 35、build-tools 35）。

```bash
export JAVA_HOME=/path/to/jdk-17
export ANDROID_HOME=/path/to/android-sdk
cd android
gradle :core:test :app:assembleDebug        # 或 ./gradlew
```

`local.properties` 里写 `sdk.dir=...` 也可以（该文件不进仓库）。

产物：`android/app/build/outputs/apk/debug/app-debug.apk`。

## 跑内核测试

```bash
cd android && gradle :core:test
```

`core/src/test/.../SpecFixtureTest.kt` 直接读仓库根的 `spec/behaviour.json`，
和 Swift 侧的 `RuleFixtureTests` 断言同一批用例——改规则时两端会一起红。

## 装到设备

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

debug 包是本地签名，可以直接装；上架 Google Play 需要另配 release 签名。

## 数据

- 学习数据：`/data/data/app.luma.reader.android/files/StudyCenter/luma_study_store.json`
  （字段与 macOS 版一致，Mac 导出的 JSON 可以直接导入）
- 书籍：`files/Books/`，EPUB 会解压到 `Books/<书名>.extract/` 供 WebView 引用图片
- 云同步：设置里选一个系统文件选择器授权的目录，每台设备写一份 `device-*.json`

## 与另外两端的差异

- 阅读器是滚动阅读 + 点击查词（没有 iOS 那张快照式分页）。
- 朗读用系统 TTS；macOS 的 Kitten 神经语音依赖上位机进程，手机端没有移植。
- 写作 / AI 对话 / 主题皮肤这些只有 macOS 有，Android 版按需求只做三块学习功能。
