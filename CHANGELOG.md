# Changelog

## 2026-11-16 12:10:00 (UTC-07:00) · 发布到 GitHub（macOS 1.33.0 + iPhone 1.0.0）
由 DeepSeek 更改 在 12:10:00，本次把两个平台的版本推到公开仓库，内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 提交：`4590aad`，96 个文件改动（+81509 / −1628），推到 `niuyajie520/LumaReader` 的 `main`
- Release：
  - `v1.33.0` → `LumaReader-1.33.0-B145-20261116-Source.zip`（63.5 MB）、`LumaReader-1.33.0-B145-macOS.zip`（79.1 MB，可直接拖进「应用程序」）
  - `ios-1.0.0-b5` → `LumaReader-iPhone-1.0.0-B5-20261116-Source.zip`（448 KB）
- `README.md` 顶部加 iPhone 徽章与「两个平台」表格，说明共用 `LumaCore` 与 `version.json` 单一版本源。
- 注意：仓库历史原本停在 1.24.0(129)，这次一次性带上 1.25 → 1.33 的全部改动。

## 2026-11-16 09:45:00 (UTC-07:00) · 架构 · 听写会话与云同步也进内核，版本只留一份
由 DeepSeek 更改 在 09:45:00，本次把「剩下三件」做完，内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：architecture / cross-platform（macOS 1.33.0 · build 145，iPhone 1.0.0 · build 5）

**1. 听写会话状态机进内核**
- 新增 `Packages/LumaCore/Sources/LumaCore/DictationSession.swift`：`DictationSessionStateMachine`、
  `DictationSessionMode`、`DictationSubmitOutcome`、`DictationTuning`、`DictationAttemptLog`、
  `StubbornWordRecord`、`SlowReactionWordRecord`；`submitAnswer(...)` 与 `skipRemaining()` 为公开 API。
- macOS：`Deferred/StudyCenter/DictationEngine.swift` 只留报告视图，`LumaCoreBridge.swift` 用
  `typealias` 把八个类型名映射回内核，既有调用点一行没改。
- iPhone：`Core/DictationEngine.swift` 重建成薄封装（`DictationSession` 持一份状态机，只做
  `@Observable` 与 UI 派生量），判题、错词插回位置、三档退档全部改由内核决定。

**2. 云同步合并进内核**
- 新增 `Packages/LumaCore/Sources/LumaCore/SyncMerge.swift`：`mergeWords` / `mergeSchedule` /
  `mergeLogs` / `mergeStubborn` / `mergeSlowReaction` / `mergeDailyReading` / `mergeMarks`。
- macOS `StudyPersistence.merge(local:remote:)` 与 iPhone `StudyStore.mergeRemote(...)` 都改调这一份；
  比较「档位更高 / 到期更晚」的规则只写了一遍。

**3. 版本只留一份**
- 新增 `version.json`（macOS 与 iOS 各自的 version/build/source_id）作为唯一版本源。
- 新增 `Scripts/sync-version.py`：把 `version.json` 写进 `release.json` 与 iOS 工程生成脚本；
  `--check` 用于 CI 检查漂移。
- 新增 `Scripts/release.sh --target macos|ios|both [--test] [--install]`：同步版本 → 构建 →
  校验 → 打源码包（macOS 与 iPhone 各一个 ZIP），一条命令出两个平台的包。

**4. 规范漂移的自动检查**
- 新增 `Scripts/check-core-spec.py`：校对 `spec/constants.json` 的数字与 `LumaCore/` 源码、
  `behaviour.json` 的 `specification` 与 `LumaCoreVersion.specification` 是否同步；
  `release.sh` 每次出包先跑它。

**验证**
- `Packages/LumaCore`：`Executed 17 tests, with 0 failures`（新增 10 个会话状态机与 8 个合并规则用例）。
- `python3 Scripts/check-core-spec.py` → `spec 与内核一致：specification=2，8 组用例，13 个常量`。
- `Deferred/StudyCenter`：103 tests / 27 suites / 18 issues，与基线 `/tmp/base-fails.txt` 逐条一致。
- iPhone：`xcodebuild ... build` 通过；全量 6 个 UI 用例（听写、阅读翻页、点词、词库、设置、截图）全绿。
- macOS：`bash Scripts/build-macos.sh` 通过（202 秒），`check-app-bundle.py PASS`；
  已用 `rsync` 静默替换 `/Applications/Luma Reader.app`（1.33.0 / 145，未启动应用）。
- 出包：`bash Scripts/release.sh --target both`，产物
  `~/Desktop/LumaReader-macOS-1.33.0-B145-Source.zip` 与 `~/Desktop/LumaReader-iPhone-1.0.0-B5-Source.zip`
  （后者解压后单独编译通过）。

**未做**
- 真机验证（iOS 需用户自己的 Apple ID 签名；iCloud 文件夹同步需真机两个设备）。
- Android：`spec/README.md` 的路线图已列出 Kotlin 侧要实现的五个类型与验收方式。

## 2026-11-16 09:20:00 (UTC-07:00) · iPhone 版 1.0.0 (build 4) · 接上共享内核 LumaCore
由 DeepSeek 更改 在 09:20:00，本次让 iPhone 版真正用上同一份规则，内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：ios / architecture
- 改动：
  - `iOS/generate_project.py` 生成 `XCLocalSwiftPackageReference`（`../Packages/LumaCore`）与 `XCSwiftPackageProductDependency`，app target 通过 `packageProductDependencies` 链接 `LumaCore`。
  - 新增 `iOS/LumaReaderIOS/Core/LumaCoreBridge.swift`（`@_exported import LumaCore`），删掉 iOS 里复制的 `DictationAnswerPolicy` / `DictationEntryKind` / `DictationPhraseDiff`（-3484 字符）。判题与「长措辞只差虚词」从此只有一份实现。
  - `CURRENT_PROJECT_VERSION` 3 → 4。
- 验证：`xcodebuild -project LumaReaderIOS.xcodeproj -scheme LumaReader -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO build` 通过；全量 UI 用例 `Executed 6 tests, with 0 failures`（135.0 秒），说明换内核后听写判题行为未变。
- 未改动（下一步再搬）：iOS 的 `WordReviewProgress`、`DictationSession`、云同步合并仍留在 app 内；`spec/README.md` 已记下这三处待办。
- 打包布局：源码包根为 `LumaReader-iPhone/`，其中 `iOS/`（工程与源码）与 `Packages/LumaCore/` 平级，正好对应工程里的 `../Packages/LumaCore`。

## 2026-11-16 09:05:00 (UTC-07:00) · 架构 · 抽出共享内核 LumaCore
由 DeepSeek 更改 在 09:05:00，本次为「一套规则服务 macOS / iPhone，将来好接 Android」做地基，内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：architecture / refactor / cross-platform（**未发布新版本**，macOS 行为不变，`release.json` 未动）
- 新增 `Packages/LumaCore`（纯 Foundation，不 import SwiftUI/AppKit/UIKit，不碰文件与网络）：
  - `DictationAnswerPolicy`、`DictationEntryKind`、`DictationPhraseDiff`（判题、条目分类、长措辞虚词门槛）
  - `WordReviewProgress`、`WordReviewOrdering`（艾宾浩斯 + FSRS 混合调度、到期优先排序）
  - `VocabularyWord`、`ExamEnglishInputPolicy`（词条模型、雅思英文输入策略）
  - `LumaCoreVersion.specification`（规则版本号，改规则要 +1）
- `Deferred/StudyCenter/Package.swift` 增加对 `Packages/LumaCore` 的本地依赖，新增 `LumaCoreBridge.swift`
  里 `@_exported import LumaCore`，因此 StudyKit 内部既有代码一行 import 都不用改。
- 新增跨平台合同：`spec/behaviour.json`（判题/归一化/分类/虚词差异/复习间隔的输入→期望输出）、
  `spec/constants.json`（四档阶梯 5/55/155/255、错词偏移 10/20/35/50、间隔 1/3/5/7/10/14、长措辞阈值 5、
  虚词表、设计 token）、`spec/README.md`（移植边界与 Android 路线）、`docs/PLATFORM-PLAN.md`（三步走与备选方案取舍）。
  `Packages/LumaCore/Tests/LumaCoreTests/RuleFixtureTests.swift` **直接读这两个 JSON** 做断言，不是另写一份期望值。
- 顺手修掉一个真实的迁移缺陷：词库清理迁移原来「只要 importedWords 非空就改写文件并备份」，
  即使词库本来就干净也会重写一遍（`DictationResetMigrationTests` 的字节级校验因此失败）。
  现在只有「真的删了词或改了拼写」才写盘。
- 涉及文件：`Packages/LumaCore/**`（新增）、`spec/**`（新增）、`docs/PLATFORM-PLAN.md`（新增）、
  `Deferred/StudyCenter/{Package.swift,DictationEngine.swift,StudyReview.swift,LumaStudyCenterAllInOne.swift,StudyPersistence.swift}`、`Deferred/StudyCenter/LumaCoreBridge.swift`（新增）、`CHANGELOG.md`
- 原因：用户要求「为以后的 android 作准备」。听写引擎此前在 macOS 与 iOS 各有一份，同一个 bug 要改两遍，
  iOS 那份还多出一个 macOS 没有的缺陷（`isFirstAttemptInSession` 恒 true）——漂移必须用共享内核 + 可执行规范堵住。
- 验证：
  - `xcrun swift test`（`Packages/LumaCore`）→ 6 tests / 0 failures（全部用例来自 `spec/behaviour.json`）。
  - `xcrun swift test`（`Deferred/StudyCenter`）→ 103 tests / 27 suites，失败清单与拆分前逐条一致（11 个环境型用例，
    都是需要图形窗口的 AppKit 界面测试），没有新增失败。
  - `bash Scripts/build-macos.sh` → 构建完成，`check-app-bundle.py` 结果 `PASS`（169.7 秒）。
- 未验证：iPhone 工程还没切到 `LumaCore`（下一步：`generate_project.py` 生成 `XCLocalSwiftPackageReference`，
  删掉 iOS 侧复制的判题与调度代码）；`DictationSession` 状态机仍在两端各一份；云同步合并算法未抽。
## 2026-11-16 05:40:00 (UTC-07:00) · iPhone 版 1.0.0 (build 3)
由 DeepSeek 更改 在 05:40:00，本次把阅读从「连续滚动、一屏以外被截掉」改成真正的整页翻页，内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：ios / reader / layout
- 症状：长章节只显示到屏幕底部就断掉，翻页无效；底栏页码永远是 `1 / 1 页`。
- 根因（都是实测出来的，不是读代码猜的）：
  1. `Resources/Reader.js` 的分页靠 `document.getElementById('luma-viewport')` 是否存在决定，分页模式用 CSS 多栏（`column-count`）。手机上窄屏只算出一列，超出内容既不分栏也不产生横向 `scrollWidth`，所以永远算成 1 页、后面的正文被 `overflow:hidden` 静默裁掉。
  2. `Resources/Reader.css:19` 的 `body { padding: 48px 44px 100px !important; }` 是给 macOS 窗口写的，手机上把正文整体右移 44pt、右侧超出视口被裁（实测 `left=62px`，清掉后 `left=18px`）。
  3. `Reader.js` 末尾 `// === LumaReader v1.10.14 Instant Split-View Smooth Scale ===` 会在 resize 时给 `document.body` 加 `scaleX`（macOS 分屏特效用），在 iOS 上把正文横向拉扁。
  4. 正文与章节底栏都用 `.safeAreaInset` 时仍互相压，最后两行被底栏盖住。
- 改法：
  - 阅读页不再使用 Reader.js 的多栏分页（`ReaderHTML.compose` 不再输出 `#luma-viewport` 包装），改由 iOS 侧的 `Coordinator.iosPagerScript` 分页：按 `innerHeight` 与正文 `lineHeight` 算出每页整行数（`step = floor(available / lineHeight) * lineHeight`），`body` 高度设为正好 `step`，正文用 `translate3d(0, -pageIndex * step, 0)` 整页位移，`transition` 180ms；`window.Luma.turn(delta)` 被接管，翻到本章头尾返回 `false`，由 Swift 切章；页底加 6px 纸色遮罩盖住跨页处半个字的字头。
  - `body` 内边距归零、`#luma-content` 的宽度与左右留白由 JS 按 `window.innerWidth` 显式设定（`calc(100vw - 36px)`，两侧各 18pt），旋转/改字号时重新排版。
  - 删掉 `Reader.js` 里的 macOS 分屏 `scaleX` 动画段（iOS 这份 `Resources/Reader.js` 副本）。
  - 阅读页改成 `VStack(spacing: 0) { 正文区域; 章节底栏 }`，两者不再叠压；底栏页码加 `accessibilityIdentifier("reader.page")`，章节行加 `reader.chapter`。
  - 测试用书换成新的 3 章示例（`Resources/sample.epub`），`-seed-sample-book` 先删旧书再重新导入，避免测到上一次容器里的旧章节。
- 同一版里一并做的三件事：
  - **左右滑动翻页**：在页面内判定 `touchstart/touchend`（横向位移 ≥48pt、纵向不超过横向的 0.6 倍、700ms 内），比点边缘的 48pt 窄条自然；点词查词不受影响。
  - **接着上次那一页读**：进阅读页首帧向书库要磁盘上的最新 `progress`（不信任导航传进来的快照），算出章内页序后用 `window.__lumaPagerJump` 直接定位；切章、改字号都会重排后重新定位。
  - 修掉一个只在测试里暴露的真问题：`-seed-sample-book` 原来每次回到书架都「删书 → 重导」，把刚存的阅读进度清零（重开书永远回第 1 页）。改成每次启动只种一次。
  - 听写卡片遇到没有释义的词（比如从阅读里加进来的生词）原来什么都不显示，现在显示「暂无释义」，不会出现空卡片。
- 涉及文件：`iOS/LumaReaderIOS/Features/Reader/ReaderViews.swift`、`iOS/LumaReaderIOS/Resources/{Reader.js,Reader.css,sample.epub}`、`iOS/LumaReaderIOSUITests/LumaReaderSmokeTests.swift`、`iOS/generate_project.py`、`iOS/README.md`、`CHANGELOG.md`
- 原因：用户要求「把这个任务定到明天早上 5:30 开始」之前先自主推进；阅读不能翻页属于交付级缺陷。
- 不变：macOS 版源码、`release.json`、macOS 安装包；听写与词库逻辑未改。
- 验证：
  - `xcodebuild test -project LumaReaderIOS.xcodeproj -scheme LumaReader -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` → 6 tests / 0 failures（117.6 秒）；`testOpenSampleBook` 里真的点右侧翻页带，断言页码从 `1 / 5` 变 `2 / 5`，并截图核对两页的正文首尾不重不漏。
  - 截图核对：第 1 页止于「with hedges and the occasional white」，第 2 页从「with hedges and the occasional white / farmhouse.」接上，页底没有半行残字，底栏与正文不再重叠。
  - 同一次用例里还验证了：点右边缘翻到 `2 / 5`、左滑翻到 `3 / 5`、退到书架再点回来仍停在第 3 页、点词弹出查词面板并加入生词本（词库 6063 → 6064）。
- 未验证：真机上的滑动手感与阻尼（模拟器里只有点击/滑动手势，没有真实惯性）；超长章节（数十页）的翻页性能；带图片/表格的 EPUB 分页；真机字号切换后的重新分页。

## 2026-11-15 22:10:00 (UTC-07:00) · iPhone 版 1.0.0 (build 2)
由 DeepSeek 更改 在 22:10:00，本次是 iPhone 版第一个**在模拟器上真跑过**的构建，内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：new-product / ios / verification
- 更正上一条记录里的错误结论：「本机 `xcrun simctl` 缺 CoreSimulator、iOS 应用无法运行」是错的。`xcrun simctl list runtimes` 显示 iOS 27.2 运行时齐全，iPhone 17 模拟器 `CB391BF6-5029-447A-A441-B51CF4010E4E` 可以 boot / install / launch / 截图；本机只是没有 Simulator.app 图形界面（headless 足够）。
- 修掉的 7 个真问题（都是模拟器上点出来、看到像素才发现的，不是读代码猜的）：
  1. 软件键盘弹出后「提交」被键盘盖住（无障碍树里 `HITTABLE >>> false`，点击落到 `UIKeyboardLayoutStar` 上），真机上打完字根本提交不了 → 输入框与提交按钮改为 `.safeAreaInset(edge: .bottom)` 钉在键盘上方，正文进 `ScrollView` 并可拖动收键盘。
  2. 输入框本身也被键盘挤出屏幕：自动化「点输入框」实际点在提交按钮上，空答案被记成一次错误（幽灵提交）。与上一条同源，一并修好；另把提交按钮改成「输入为空时禁用」，空答案再也记不进错题。
  3. `Core/DictationEngine.swift` 的 `isFirstAttemptInSession` 恒为 `true`（`advance()` 里就写入了「已记录首次尝试」集合），与 macOS 版 `Deferred/StudyCenter/DictationEngine.swift:314` 的语义不一致 → 改成在 `submit()` 里先算 `let isFirstAttempt = !wordsWithInitialAttemptLogged.contains(word.id)` 再 insert。
  4. 章节底栏（上一章 / 第 1/3 章 / 下一章）压在正文上，最后两行被遮住 → 底栏改 `.safeAreaInset(edge: .bottom)`，正文可见区域随之缩短。
  5. 阅读时底部 TabBar 仍占 83pt → 进阅读页 `.toolbar(.hidden, for: .tabBar)`，竖屏多出两行正文。
  6. 手机上原本没有查词入口（只有长按拖选才会触发系统选区）→ 新增点词查词：注入脚本用 `caretRangeFromPoint` 取点到的词，经 `reader` 消息通道回 Swift，弹出 `WordLookupSheet`；左右 48pt 翻页带仍优先响应。
  7. 文档选择器允许把整个文件夹当作选中项，选中后只会报「导入失败」→ `handleImport` 增加 `expandForImport`：选中文件夹时把夹里 EPUB/ZIP/TXT/MD/HTML 批量导入。
- 新增回归测试 `iOS/LumaReaderIOSUITests/LumaReaderSmokeTests.swift` 与工程里的 UI 测试 target（`generate_project.py` 生成 `LumaReaderUITests`，scheme 带 TestAction）：6 个用例在模拟器上真的点击/打字/导入/翻页，全部通过（114.7 秒）。
- 仅供测试的钩子：`#if DEBUG` + 启动参数 `-seed-sample-book` 会把包内 `Resources/sample.epub` 直接种进书架，免得自动化去驱动系统「文件」选择器；Release 构建里这段代码不存在。
- 涉及文件：`iOS/LumaReaderIOS/Core/DictationEngine.swift`、`iOS/LumaReaderIOS/Core/StudyStore.swift`、`iOS/LumaReaderIOS/Core/SpeechService.swift`、`iOS/LumaReaderIOS/Features/Dictation/DictationHomeView.swift`、`iOS/LumaReaderIOS/Features/Reader/{ReaderViews,BookLibrary}.swift`、`iOS/LumaReaderIOS/Features/Settings/SettingsView.swift`、`iOS/LumaReaderIOS/Resources/sample.epub`（新增）、`iOS/LumaReaderIOSUITests/LumaReaderSmokeTests.swift`（新增）、`iOS/generate_project.py`、`iOS/README.md`、`CHANGELOG.md`
- 原因：用户提供 Xcode 模拟器并要求「我有 xcode 模拟器你可以」——不再以「编译通过但没跑过」交付。
- 不变：macOS 版源码、`release.json`、macOS 安装包。
- 验证：
  - `xcodebuild test -project LumaReaderIOS.xcodeproj -scheme LumaReader -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` → 6 tests / 0 failures（`testFourTabsRender`、`testVocabularyDeckListsWords`、`testDictationRoundJudgesWrongThenCorrect`、`testSettingsSyncSectionHasFolderButton`、`testOpenSampleBook`、`testCaptureScreenshots`）。
  - `xcodebuild ... -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` → BUILD SUCCEEDED（arm64）。
  - 截图核对：四个 Tab、听写进行中（键盘弹出时输入框与提交按钮都在可视区）、答错订正态、阅读章节、点词查词面板、词库（6063 + 阅读生词本 1 = 6064，说明「阅读点词 → 生词本 → 听写」链路通）。
- 未验证：真机签名安装与首次信任流程；真机 iCloud 文件夹授权、两台设备真实合并；真机语音音质与时延；EPUB 目前是连续滚动而非分页（`paged` 关闭），分页在手机宽度下的表现未调；TXT/Markdown/HTML 在设备上的中文编码。

## 2026-11-15 17:35:00 (UTC-07:00) · iPhone 版 1.0.0 (build 1)
由 DeepSeek 更改 在 17:35:00，本次新增 iPhone 版 Luma Reader（独立 Xcode 工程，不影响 macOS 版的 `release.json`），内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：new-product / ios
- 更新内容：
  - 新建独立工程 `iOS/LumaReaderIOS.xcodeproj`（iPhone only，`app.luma.reader.ios`，iOS 18+），只保留四块：听写、阅读、词库（阅读生词）、设置；写作、AI 对话、星漫、统计诊断、IELTS 批改全部不进 iOS 版。
  - 听写：`Core/DictationEngine.swift` 复刻 macOS 侧的判定与调度规则（空格/连字符/下划线可互换；快速过词与 5/55/155/255 四档循环复习；错 3 次挪本轮队尾；≥5 词长措辞只差虚词时只重拼一次不计错），当天看答案后的订正不算掌握，第二天才排进到期词。
  - 阅读：`Features/Reader/` 自带 `MiniZip` 解 EPUB（无第三方依赖）、解析 container/OPF/spine、把章节 HTML + `Reader.css` 内联后用 `WKWebView` 分页显示；左右各留 48pt 翻页带，翻到章节头尾自动切章；点选单词弹释义并可一键加进 `阅读生词本`（deckID `ios.reading`），第二天进听写。
  - 词库：按词本浏览、搜索、看复习档位；支持导入本 App JSON、macOS 版整份 `luma_study_store.json`、一行一个词的 TXT。
  - 数据：`Documents/StudyCenter/luma_study_store.json` 与 macOS 同 schema，App 只覆盖自己管理的键，Mac 独有字段原样保留；首次打开词库为空时用内置 6063 条阅读词表起底（deckID `ios.reading.core`），导入 mac 数据时若只有这层底表则整份替换而不是并集。
  - 云同步：设置里选一个文件夹（iCloud 云盘即可），每台设备写 `device-<设备>.json`，同步时合并其它设备文件（词条并集、复习进度取较晚的一次、日志按 id 去重）。
  - 朗读：iPhone 上改用系统 `AVSpeechSynthesizer`（离线、免下载）；macOS 版的 Kitten TTS nano（15M）依赖上位机 Python 守护进程做音素化，iOS 上没有对应运行时，README 里写明原因与后续 onnxruntime-swift 方案。
  - 修正两处移植期问题：`applySettings` 原本把排版宽度写死 680px（手机屏上会横向溢出），改为按 WebView 实际宽度减 36pt 并随旋转重算；章节内原本没有翻页入口（只能滑到下一章），补上左右翻页带并保留 JS 翻到边界后切章的兜底。
- 涉及文件：`iOS/LumaReaderIOS.xcodeproj/project.pbxproj`、`iOS/generate_project.py`、`iOS/README.md`、`iOS/LumaReaderIOS/{App,Core,Features,Resources}/**`（13 个 Swift 文件 + 3 个资源）、`CHANGELOG.md`
- 原因：用户要求「把这个打包为 iphone 版本，只要听写和阅读单词和阅读功能，其他全部不要，然后支持那种云同步，听力模型只保留那个 15m 的，UI 要按手机重新排」。
- 不变：macOS 版的任何源码、`release.json`、安装包。
- 验证：`xcodebuild -project LumaReaderIOS.xcodeproj -scheme LumaReader -sdk iphoneos -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` 编译通过（arm64，0 warning），产物含 `Reader.css`/`Reader.js`/`ReadingVocabulary.json`。
- 未验证：本机 `xcrun simctl` 缺 CoreSimulator 运行时、`security find-identity` 0 个签名身份，**iOS 应用无法运行验证**；界面观感、真机翻页手感、云同步真实合并均未在设备上验证。

## 2026-11-15 15:58:35 (UTC-07:00) · v1.32.2 (build 144)
由 DeepSeek 更改 在 15:58:35，本次更新的安装包为 v1.32.2（build 144），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：study-data / library-cleanup
- 更新内容：
  - 新增一次性词库清理 `VocabularyLibraryCleanup`（`Deferred/StudyCenter/VocabularyLibraryCleanup.swift`），在 `StudyPersistence.loadAndMigrateIfNeeded()` 里首次启动执行一次，原始 `luma_study_store.json` 先整份备份到 `backups/before-vocabulary-cleanup-<时间戳>.json`：
    1. 删掉重复导入留下的第二套 deck：`luma.c20.ch3/ch4/ch5/ch11`（剑20 语料库）与 `luma.p1–p4`（场景词），共 4320 条；保留 `c20.corpus.*` 与 `ielts.*`。
    2. 英式拼写统一改为美式（含复数与所有格：`favourites`、`traveller's`、`chequebook`、`organiser`）：`catalogue→catalog`、`cheque→check`、`civilisation→civilization`、`favourable→favorable`、`favourite→favorite`、`flavour→flavor`、`labour→labor`、`litre→liter`、`mould→mold`、`moustache→mustache`、`odour→odor`、`organisation→organization`、`organiser→organizer`、`chequebook→checkbook`、`traveller→traveler`；合并后仍只有占位释义的 `check` 补成「支票；检查」。
    3. 同一词本家族内按「忽略大小写/连字符/下划线」判重（`double grill` == `double-grill`），保留释义更完整的一条。
    4. 同一单元内「短语已经把单词完整练到」时删掉多余的单词条目（例如 `kangaroo` 与 `red kangaroo`、`cement` 与 `eco-cement` 同单元只留短语）：只认单词是短语的最后一个词、短语不超过三个词、且短语释义里确实包含单词释义，避免 `bus`、`rent` 这类核心词被 `bus stop`、`rent a flat` 顺手删掉。
    5. 把指向已删除 deck 的 `workspace.selectedDeckID` 与听写会话收回到现存词库，避免点开是空壳；被删词条留下的听写日志、顽固词、慢反应词、复习进度一并清掉，错词本不会出现空词条（用户已说明学习记录可以全部删除，此处只清理被删词条自己的记录）。
  - 实测（在用户真实 `luma_study_store.json` 上跑同一份逻辑）：词条 11410 → 7031（删 4379 条：重复词本/重复词条 4324、被短语覆盖的单词 55），deck 34 → 17；清理后只剩 `organism` 这类本来就属美式拼写的词命中英式正则。
  - 重复清理用 `installedVocabularyPackIDs` 里的 `vocabulary-dedupe-20261115` 标记保证只执行一次。
  - `Deferred/StudyCenter/Package.swift` 的 `sources` 清单登记新文件（SwiftPM 按显式文件列表编译，缺登记会报 `cannot find 'VocabularyLibraryCleanup' in scope`）。
- 涉及文件：`Deferred/StudyCenter/VocabularyLibraryCleanup.swift`（新增）、`Deferred/StudyCenter/Tests/VocabularyLibraryCleanupTests.swift`（新增）、`Deferred/StudyCenter/StudyPersistence.swift`、`Deferred/StudyCenter/Package.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户词库里同一份词本被导入两遍（11410 条中仅 7119 个不同词），并提出「我更想要美国拼写，把所有都改过来，然后全部删除多余的」。
- 不变：听写判定规则、错词调度、复习进度数据结构、本轮错题按词计数。
- 验证：`xcrun swift test --package-path Deferred/StudyCenter --filter VocabularyLibraryCleanupTests` 6 个用例全通过（重复词本、英美拼写合并、连字符判重、短语覆盖单词、中心词保留、记录清理）；`bash Scripts/build-macos.sh` 通过；`codesign --verify` 通过；静默安装到 `/Applications/Luma Reader.app`（不启动应用、不抢窗口）。清理逻辑在应用下次启动时生效。
- 未验证：未跑全量 `xcrun swift test`；未在真机上重启应用确认清理后的词库列表。

## 2026-11-15 13:10:00 (UTC-07:00) · v1.32.1 (build 143)
由 DeepSeek 更改 在 13:10:00，本次更新的安装包为 v1.32.1（build 143），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：ui / counting
- 更新内容：「本轮错题」彻底不显示错误次数，只显示错了几个词。行尾的「错 2 次」标记去掉；窗口标题从「N 个词 · 共错 M 次 · 已选 K」改为「N 个词 · 已选 K」；顶栏徽章的悬停提示不再提总次数。同一个词错十次仍然只有一行、只算一个词。导出 CSV 仍保留「错误次数」列（数据导出用，不在界面显示）。
- 涉及文件：`Deferred/StudyCenter/{DictationUnitWrongWindow,StudyHome}.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户指出「我明明只错了一遍，为什么显示数字二，应该只显示 1，因为我只错了一个单词，并不是计算我一共错了几遍」。
- 不变：按词归并逻辑、搜索、全选、导出、听写判定与错词调度。
- 验证：`bash Scripts/build-macos.sh` 通过；`codesign --verify` 通过；静默安装到 `/Applications/Luma Reader.app`，未启动应用、未抢窗口。
- 未验证：未跑 `xcrun swift test`；界面观感未做真机点击验证。

## 2026-11-15 12:58:00 (UTC-07:00) · v1.32.0 (build 142) 编译与安装
由 DeepSeek 更改 在 12:58:00，本次更新的安装包为 v1.32.0（build 142），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：build / verify
- 更新内容：
  - 对 v1.32.0 的前端改动做首次编译：`bash Scripts/build-macos.sh` 成功（179.35 秒），产物 `dist/Luma Reader.app`，`check-app-bundle.py` PASS。
  - 静默安装到 `/Applications/Luma Reader.app`：`rsync -a --delete`（不运行 `Install.command`，避免它末尾 `open` 抢窗口），未启动应用、未截图、未做界面点击验证。
  - `codesign --verify --deep --strict` 通过；`lsregister -f` 已刷新；Info.plist 版本确认为 1.32.0 / 142。
- 涉及文件：无源码改动（仅编译产物与安装副本）
- 原因：用户要求「帮我安装好，不要跟我抢窗口」。
- 验证：编译通过、签名校验通过、Info.plist 版本一致。
- 未验证：`xcrun swift test` 未跑；实际界面观感（SF Symbols 状态条、统计列表、去除悬停放大与回弹后的手感）未做真机点击验证。

## 2026-11-15 12:45:00 (UTC-07:00) · v1.32.0 (build 142)
由 Claude 更改 在 12:45:00，本次更新的安装包为 v1.32.0（build 142），更新的内容如下：
- 执行者：Claude（运行于 DSH agent · claude-opus-5-5）
- 类型：ui
- 更新内容（补完 `DESIGN.md` 里尚未落实的前端规范）：
  - 图标：状态提示不再用 ✓ / ✕ / ✨ 字符当图标，改用 SF Symbols。AI 设置页的连接/拉取模型结果改为「图标 + 文字」并用独立状态字段判断成功、失败（不再靠字符前缀上色）；写作导入提示、听写结果「已掌握」、易混词计数改用 `checkmark` / `checkmark.circle.fill`。
  - 文案：去掉提示里的感叹号（加入听写词库、加入写作错词本、加入听力生词本、星漫「差一点」）；半角「...」改为全角「…」（语音引擎检测、评估中、阅读搜索框、简答输入框；`sk-...` 是密钥格式，保留）；AI 对话空状态说明压成一句。
  - 悬停不放大：去掉星漫主页星球悬停 1.04 放大、主题选择卡悬停 1.012 放大、听力分类拖放目标 1.08 放大与回弹。
  - 动效不回弹：`LumaMotionSpring.press/release` 改为 `.snappy(0.14)`；设置齿轮去掉 1.18 弹跳与弹簧，只保留旋转；听写工具栏按钮悬停 0.12 秒淡入、按下 snappy；词库/分类拖拽重排、错词中心进度环改为 `.smooth(0.25)`。
  - 不用紫色装饰：错词中心「顽固」由紫色改为红色（配三角警示图标，非颜色线索仍在）。
  - 拒绝清单「大数字 + 小标签统计卡排成一排」：错词中心概览改为一行安静摘要（窄窗口自动折两行）；听写结果页、学习统计页的统计卡改为一个分组面板里的列表行（名称左、数值右，长说明进悬停提示）。学习统计页标题由「学习统计与能力诊断（原生 Swift Charts）」改为「学习统计」，长副标题压成一句并把细节放进 `.help`。
  - `README.md` 版本徽章与下载命令更新到 v1.32.0（build 142）。
- 涉及文件：`Sources/LumaReader/ContentView.swift`、`Sources/LumaReader/GlassControls.swift`、`Sources/LumaReader/LumaHomeView.swift`、`Sources/LumaReader/LumaIndependentThemes.swift`、`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/WrongWordsCenter.swift`、`Deferred/StudyCenter/ConfusableViews.swift`、`Deferred/StudyCenter/StudyReview.swift`、`Deferred/StudyCenter/StarMangaScenes.swift`、`Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`、`Deferred/StudyCenter/IELTSReadingPractice.swift`、`release.json`、`README.md`、`CHANGELOG.md`
- 原因：用户要求补完 `DESIGN.md` / `DESIGN_TOOLS.md` 中尚未完成的前端建议，只改源码并交付 ZIP，编译与验证由用户自行完成。
- 不变：听写判定、错词调度、听写输入框（`DictationPracticeLayout.swift` / `DictationAnswerMetrics`）、阅读顶栏与红黄绿、写作划词高亮、主题色值文件（`Theme.swift`、`MonetTheme.swift`、`LumaDesignTokens.swift`、`StudyAppearance.swift`）均未改动。
- 验证：无（按用户要求不编译、不测试、不操作电脑）。
- 未验证：`swift build`、`swift test`、安装与界面观感全部未验证，由用户在 Mac 上完成。

## 2026-11-15 11:52:00 (MST) · 1.31.2 (141)
由 DeepSeek 更改 在 11:52:00，本次更新的安装包为 v1.31.2（build 141），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：ui / counting
- 更新内容：「本轮错题」按**词**计数，不再按错误条目数。一个词错了 5 次，徽章仍然只加 1，行尾写「错 5 次」；只有「共错 N 次」时才在标题里补一句总次数。之前徽章数的是错误记录条数，错两次同一个词会显示「2」，容易被读成错了两个词。窗口标题改为「N 个词 · 共错 M 次 · 已选 K」，行内次数标记从「×N」改成「错 N 次」。
- 涉及文件：`Deferred/StudyCenter/{StudyHome,DictationUnitWrongWindow}.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户指出「只想错了一个单词，为什么显示两个」。
- 不变：判定规则、错词阶梯、分组与搜索逻辑、听写输入框尺寸与排版。
- 验证：`xcrun swift test` 103 个用例 / 27 个套件，失败 15 项，与改动前基线逐条一致。
- 安装：静默替换 `/Applications/Luma Reader.app`（未启动应用、未抢窗口），下次打开即生效。

## 2026-11-15 11:45:00 (MST) · 1.31.1 (140)
由 DeepSeek 更改 在 11:45:00，本次更新的安装包为 v1.31.1（build 140），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：learning-logic / ui
- 更新内容：
  - 「本轮错题」窗口按词归并：同一个词错十次也只占一行，旁边标「×10」，行里显示最近一次输入，鼠标停留可看全部写错的内容。之前一次错误一行，同一个词会重复出现好几条。
  - 「本轮错题」窗口新增搜索框：按单词、中文释义或写错的内容筛选，标题显示「匹配 N / 共 M 条」；全选按当前筛选结果来，导出新增「导出当前列表」并带「错误次数」列。
  - 学新词阶梯不再因为一次手滑把词「判成毕业」：队列里只剩这一个词时（第 3、4 档末尾最常见），之前答对一次就直接出列、从队列消失；现在必须走满四档才毕业，高档答错照旧退一档、隔一个确认步再回到较低档，词不会凭空消失。
- 涉及文件：`Deferred/StudyCenter/DictationUnitWrongWindow.swift`、`Deferred/StudyCenter/DictationEngine.swift`、`Deferred/StudyCenter/Tests/{WrongListDedupTests,NewWordLadderTests}.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户指出同一个词重复占行、需要搜索，以及第 3 轮不小心写错后词直接消失的问题。
- 不变：判定规则、错词阶梯数值（5/55/155/255）、快速过词默认值、听写页输入框尺寸与自适应字号、焦点与排版。
- 验证：`xcrun swift test` 103 个用例 / 27 个套件，失败 15 项，与改动前基线逐条一致（均为无窗口环境下的 AppKit／图表用例预存失败）；新增 15 个用例（跨天门槛 4、长措辞 6、按词归并 3、队列末尾不毕业 2）全部通过。
- 未验证：错题窗口的搜索框与「×N」标记没有在真机上截图确认（用户正在使用这台机器，没有抢占窗口）。

## 2026-11-15 10:36:00 (MST) · 1.31.0 (139)
由 DeepSeek 更改 在 10:36:00，本次更新的安装包为 v1.31.0（build 139），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：learning-logic
- 更新内容：
  - 当天订正不再冒充「掌握」：一个词真正拉长复习间隔，只认「换个时段／隔天无提示答对」。当堂看答案后改对只算练对（档位不动，保持原定到期日）。此前每次提交都写长期复习进度，错一次就把档位清零并立刻到期，队列里反复出现的正是刚看过的词。
  - 新词从「整单元全塞」改为「到期优先」：昨天该复习的词排在新词前面，仍然保持原有顺序，不额外增加轮次。此前新建会话直接把整个单元的单词倒进队列，不分新旧、不看是否到期。
  - 5 个词以上的长措辞走轻量门槛：首次只错冠词／介词这类虚词时，只标出差异片段并整条重拼一次，不计错、不入顽固词、不进四轮循环；错实词或第二次再错才回落原错词路径。4 个词以内的固定搭配仍按单词的标准和阶梯走。
- 涉及文件：`Deferred/StudyCenter/StudyReview.swift`、`Deferred/StudyCenter/DictationEngine.swift`、`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/Tests/{NextDayRecallGateTests,PhraseGateTests,StudyLearningRulesTests}.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户要求按评审方案落地「隔天首次无提示回忆」与「长措辞轻量门槛」，并明确 3–4 个词的固定搭配沿用单词标准、不特殊对待。
- 不变：判断是否正确的规则、错词阶梯与插回偏移、快速过词／循环复习两种策略的默认值、输入框尺寸与自适应字号、焦点与滚动行为、听写页排版。
- 验证：`xcrun swift test` 98 个用例 / 25 个套件，失败 15 项，与改动前基线（88 用例 / 23 套件 / 15 项）逐条一致 —— 均为无窗口环境下 AppKit／图表类用例的预存失败，本次未新增任何失败；新增的 10 个用例全部通过（跨天门槛 4 个、长措辞门槛 6 个）。
- 未验证：真机听写流程（隔天回忆、到期优先排序、长措辞提示语）未逐项手动点击确认。

## 2026-11-15 09:29:40 (MST) · 1.30.2 (138)
由 DeepSeek 更改 在 09:29:40，本次更新的安装包为 v1.30.2（build 138），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 安装 1.30.2（B138）到本机并做真机验证；本次未改动任何源码。
- 涉及文件：`release.json`、`Install.command`、`/Applications/Luma Reader.app`
- 原因：用户要求把 LumaReader-2 里的归档安装到本机。
- 验证：xcrun swift build -c release 构建通过（无错误）；bash Install.command 退出码 0；codesign --verify --deep --strict 通过；release_guard.py app 通过；真机打开 1.30.1 修复后的听写页（返回 / 错词 / 计时 / 输入框 / 提交）排版正常，无重叠。
- 未验证：专注模式默认关闭（新键 luma.dictation.focusMode.v2）只做了代码核对，没在界面里逐项点选确认。
- 测试：`xcrun swift test` 130 个用例 / 32 个套件，6 处失败全部集中在 ReaderChromePointerTests 与 ImmersiveReaderTests（窗口/焦点相关的环境型失败，与 1.30.0 基线完全一致，本次改动未新增失败）。

# LumaReader 1.30.2 B138

由 Claude 更改。听写专注模式默认关闭。
- 执行者：Claude（Opus 5.5）
- 打字时标题栏和底部按钮不再变淡，始终可点。想要专注效果可在「⋯ 练习选项」里打开。
- 设置换了新键名，升级后一律从「关」开始。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.30.1 B137

由 Claude 更改。修复听写页排版失效（1.25.0 起引入的回归）。
- 执行者：Claude（Opus 5.5）
- 原因：听写页的排版容器固定要求四块内容（标题栏 / 第二行 / 输入框 / 状态）。1.25.0 删除重复进度条后只剩三块，容器直接放弃排版，四块全部叠在窗口正中：返回按钮、进度、本轮错题、计时和「⋯ 练习选项」（倍速在里面）被输入框盖住无法点击，订正提示与输入框的占位文字重叠。
- 修复：在原进度条的位置放一个零高度占位，排版恢复为标题在上、输入框居中、订正提示在下。排版容器本身（冻结文件）未改。
- 不变：听写输入框、判定、队列、错词阶梯、数据隔离。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.30.0 B136

由 Claude 更改。全应用按钮统一成一套（impeccable 自检遗留项）。
- 执行者：Claude（Opus 5.5）
- 新增 `LumaButtonSystem.swift`：四种角色（主要 / 次要 / 安静 / 危险）、三档尺寸（28 / 36 / 44）、圆角统一 10、一条按下动效（0.97，无回弹）。
- 原来混用的十几种按钮样式（学习中心玻璃胶囊、阅读中心触感按钮、侧栏行、头部图标、工具栏图标、书封、色板、首页按钮、文件夹树按钮、按下反馈样式）全部改为读这组数值；调用处不动。
- 去掉：悬停放大（玻璃胶囊 1.02、工具栏图标 1.12、书封放大并上浮）、阅读顶栏图标的指针跟随高光、每次点击都弹一下的图标动画（只在状态真正切换时弹）。
- 系统 `.bordered` / `.borderedProminent` 全部换成统一按钮：设置里的试听 / 下载、AI 服务商保存、写作重写稿保存、错题窗口操作栏、听写「练习选项」里的两行、雅思阅读分屏比例（现在会高亮当前比例）。
- 首页「导入听写词表」从手画描边改为次要按钮。
- DESIGN.md 新增「按钮」一节。
- 不变：听写输入框、判定、队列、错词阶梯、数据隔离。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.29.0 B135

由 Claude 更改。学习 impeccable 与 taste-skill 两套设计规范（并参考 Ant Design / Element / EasyUI 的组件原则）后的一轮整体修正，并新增 DESIGN.md。
- 执行者：Claude（Opus 5.5）
- 新增根目录 DESIGN.md：模式（操作 / 阅读）、一屏一个主操作、组件尺寸与 8 点间距栅格、颜色、反馈层级（就地 → 行内 → 提示条 → 确认 → 模态）、空状态、动效、文案、拒绝清单与交付自检。AGENTS.md 指向它。
- 主页：去掉标题上方的小标签；「今日」三张大数字卡片改为一句话，只有「复习 N 个错词」可点；去掉与侧栏重复的六格功能卡片；去掉页面载入入场动画。
- 星漫主页：中心卡片去掉黑色小标签和「↵」字符；紫色星球换成青绿色。
- 漫画墨线外观只用于漫画系主题；尼尔、塞尔达、废土回到普通卡片外观。
- 星漫听写输入框去掉「月面基地 · 主控屏」装饰小字。
- 全局：按钮和标签里的 emoji（⚡🔥🎧📥☁️⚙️🔄📅📖✍️）换成纯文字或 SF Symbols。
- 文案：听写反馈压成一句（如「拼写正确 · 用时 3.2 秒」「第 2/4 档 · 隔 55 个词再听」）；提示条去掉感叹号。
- 不变：听写输入框、判定、队列、错词阶梯、数据隔离。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.28.0 B134

由 Claude 更改。深空与漫画合并为一个新主题「星漫 · 太空漫画」，听写页变成月球基地。
- 执行者：Claude（Opus 5.5）
- 主题：主题画廊里原来的「深空」和「漫画」两个主题合并为「星漫」（深空底色 + 漫画墨线与网点）。原来用深空或漫画的，升级后自动是星漫，不用重选。
- 主页（星漫）：六颗墨线星球绕着中间的「继续上次」公转（约 4 分钟一圈），各自自转；外圈一颗卫星反向绕行，每 26 秒一颗带速度线的彗星划过。鼠标停在任意星球上公转就暂停，名称以漫画对话气泡显示。今日数字放在漫画旁白框里。
- 听写页（星漫）：月球基地场景——网点月面与陨石坑、基地穹顶与舷窗、天线红灯闪烁、右上角自转的地球、左下角漫画宇航员（平常轻轻浮动；答错时挠头盔冒汗并提示「差一点！订正后 ⌘R 再听」；答对时竖大拇指）。场景只在四周空白处，不拦截点击；专注模式下随四周一起变暗。
- 输入框（星漫）：大小、位置、字号自适应、回车提交不变；底色换成深夜蓝面板，四角加分镜角线、底部渐隐网点、左上角「月面基地 · 主控屏」小字。
- 答错效果（星漫）：边框变红轻摇 → 一圈红色网点从框边扩散消失 → 右上角弹出墨线爆点，不到半秒；替换原来的雷达扫描线。
- 其它学习页（听力主页、雅思阅读、阅读词汇）在星漫下统一为深色面板 + 细浅描边，主按钮为青色实色块 + 墨线粗边 + 错位墨影；雅思阅读版面不变。书架与主页背景加一层漫画网点星空。
- 动效遵循「减少动态效果」：开启后所有场景静止。看书的正文页不加任何动效。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.27.0 B133

由 Claude 更改。新增主页，打开应用先到主页；⌘K 命令面板；听写专注模式。
- 执行者：Claude（Opus 5.5）
- 主页：最大一块是「继续上次」（听写本轮或正在读的书，取最近做的那件），回车直接继续；旁边是另一件可以继续的事；「今日 · 全部词本与书」三个数（听写词数、错词待复习、阅读分钟）；六个功能入口各带一句当前状态。第一次打开没有数据时显示「从这里开始」，可导入书或听写词表。
- 主题：同一个主页三种外观——默认卡片；深空主题是星轨，中心是「继续上次」，每颗行星一个功能，名称只在鼠标悬停时出现；漫画与尼尔、塞尔达、废土主题用墨线分镜框。
- 设置 › 主页字体、语言与图标：新增「打开应用时显示：主页 / 书架」。
- 侧栏：最上方新增「主页」；「阅读统计」和「学习统计」合并为一个「统计」，页内切换阅读 / 学习。
- 菜单「前往」：⌘K 搜索书和功能（方向键选、回车执行、Esc 关闭），⌘1 主页、⌘2 书架、⌘3 听力、⌘4 雅思阅读、⌘5 阅读词汇、⌘6 写作、⌘7 统计。⌘L 返回书库照旧。
- 听写页：专注模式（默认开，练习选项里可关）——开始打字后标题区和底栏淡出，鼠标一动就回来；进度改成「新词 · 重现中 · 已毕业」三个数；去掉与标题下进度行重复的通栏进度条。
- 空状态：本轮错题窗口没有错题时不再显示一排灰按钮；易混词没有词组时不显示灰色「练习」按钮。
- 不变：听写输入框、判定、队列、错词阶梯、学新词与错词复习的数据隔离。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.26.0 B132

由 Claude 更改。整理两处文件管理器，动效改得更克制自然。
- 执行者：Claude（Opus 5.5）
- 听力分类（听写单元文件夹）：去掉单独的「上级」按钮（后退键和面包屑已能返回）；视图从「图标 / 分栏 / 树形列表」三种减为「图标 / 分栏」两种，旧的列表偏好自动落到图标视图；面包屑起点改为「听力分类」；顶部「全部听写 (N)」改为「听写这里 · N 词」。
- 文件夹卡片：去掉书本图标、自定义铅笔标记、分隔线、「一键听写」按钮和右箭头；只留图标、名称、词数和一个圆形播放键。点卡片进入文件夹，点播放键听写本文件夹。右键菜单去掉表情符号。
- 云盘文件：整页只剩一个「⋯」（新建文件夹、上传、刷新、在 Finder 中打开）；项数只显示一次；用可点击的面包屑代替「上一级」按钮和整串路径；删除底部操作栏，单个文件的打开、重命名、显示、移到废纸篓都在右键菜单（双击打开）；空文件夹给出「上传文件…」引导；加载时不再让布局跳动。
- 动效：参照苹果 WWDC23《Animate with springs》与 Emil Kowalski 的原则，回弹系数全部降到 0.15 以内；按钮按下缩到 0.96–0.97，悬停基本不放大；答错摇晃缩短到约 0.3 秒；答对时进度环不再大幅弹跳。
- 不变：听写输入框、判定、队列、错词阶梯、答错后的中文与错字母展示；云盘文件只能在已连接的目录内操作的安全检查。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.25.1 B131

由 Claude 更改。学新词「循环复习」的错词滚动改为 5 / 55 / 155 / 255 四档，答错不再从头爬。
- 执行者：Claude（Opus 5.5）
- 只看整个单词 / 词组对不对，不按字母分。
- 词距严格按 5、55、155、255 个词；第四档拼对即毕业。说明文字与程序一致。
- 答错只退一档：在 155 或 255 档答错，订正后先隔 5 个词确认一次，对了直接回到上一档（255 错 → 5 → 155 → 255；155 错 → 5 → 55 → 155 → 255）；5、55 档答错从 5 档重走。
- 订正时手抖打错不算新的一次听错。
- 本轮同一个词真正听错第 3 次，挪到本轮最后单独练，不再插在中间拖慢整轮。
- 反馈文字会说明「隔几个词再确认、对了回到第几档」。
- 只影响「学新词 · 循环复习」；快速过词、错词复习、跨天复习暂不变。
- 新增 DictationTuning（阶梯、确认步、挪到最后的次数集中在一处）与 NewWordLadderTests。
- 验证：按用户要求未编译、未跑测试。

# LumaReader 1.25.0 B130

由 Claude 更改。学习中心前端重设计第一步（v4）：听写页降噪，「本轮」口径统一。
- 执行者：Claude（Opus 5.5）
- 听写页：底栏只留「重播 / 慢放」「意思不清」和唯一主按钮「提交」；「上一个」「显示中文」「首字母提示」「播报倍速」收进右上角「⋯ 练习选项」，快捷键 ⌘R、⇧⌘R、⌥⌘M、⌘/ 不变。标题写明归属（如「剑20 · 第3章 · 本轮」），右上新增「本轮错题 N」徽章，点开即编辑。计时暂停时加暂停符号。
- 本轮口径：新增 RoundScope（deckID + roundID）。错题徽章、本轮错题窗口、进度行、「本轮错词」全部经它过滤。去掉错题窗口按时间戳兜底的旧分支；听写页「最近错词」原先读全部记录，现在只显示本词本本轮；进度行「今日 N」改为「本轮已听 N」，全部词本的今日数字只在听力主页显示，标题为「今日 · 全部词本」。
- 听力主页：词本卡去掉装饰耳机图标和每张卡上的「⋯」；点整张卡开始 / 继续听写，右下角一个「查看单词」小图标，其余操作在右键菜单。删除未被使用的旧听写工具条（内含重复的倍速与「⋯」）。
- 图标：「⋯」统一为 ellipsis.circle；顽固 / 易错词改用火焰，感叹号三角只表示软件出错；拼错提示用叉号；「意思不清」只用问号。
- 文案：主题标题上方的小字去掉英文与「//」，降为说明级灰字。
- 新增 LumaTypeScale（11/13/15/17/22/28/40）、LumaShapeToken、LumaSymbol 图标语义表；新增 RoundScopeTests（验收场景 D1–D4）。
- 不变：听写输入框（DictationPracticeLayout / DictationAnswerMetrics）、判定、队列、落盘、答错后的中文与错字母展示。
- 验证：按用户要求未编译、未跑测试；如安装失败请把 Logs 里最新日志发回。

# LumaReader 1.24.0 B129

由 DeepSeek 更改。首次运行 B128 时先备份旧听写数据，再执行获授权的听写记录清零。
- 执行者：DeepSeek（DSH coding agent）
- 类型：feature + data migration
- 更新内容：新词与错词复习模式分队列；听写限于所选词本/单元、本轮 ID；错词短距订正与后续复习分开，高轮偶发错误不归零；本轮错题按 sessionID 和 deckID 双重过滤；学习记录按单元汇总、最近练习次数按独立轮次计算。
- 数据安全：启用有版本闸门的首次启动迁移，原始快照备份和校验成功后才清理旧听写历史；保留词本、阅读、写作；云合并不得恢复被清空的旧听写内容。
- 修复：语音引擎切换期间输入框与「提交」被禁用的耦合（切换卡住=整页不能用）；现在提交与记录不依赖引擎状态，切换 45 秒超时自动恢复并提示。
- 验证：`swift build`（`Deferred/StudyCenter`，debug）通过；`swift test` 全量 77 项 / 21 套件跑完，本版新增的 `DictationRollingQueueTests`、`DictationResetMigrationTests`、`WrongWordDataSafetyTests`、`DictationUnitWrongWindowRenderTests` 全部通过，剩余 18 条失败已用 `git worktree` 在 HEAD（1.23.6 之前）复跑确认同样失败（旧 workspace 落点断言、写作草稿落盘、雅思评分样例、原生文本探针），不是本版引入；`Scripts/build-macos.sh` release 构建通过；`release_guard.py app/pack/verify` 全部 PASS；安装后实机打开听写页与「编辑本轮错题」窗口核对。
- 未验证：云端真实多设备合并（本机只验证了 epoch 过滤的单元测试）、15 种主题配色逐一对照、小窗口下的排版。

# LumaReader 1.23.6 B127

由 DeepSeek 更改 在 22:52 (UTC-07:00)，本次更新的安装包为 v1.23.6（build 127），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：fix
- 更新内容：
  - 修掉「编辑本轮错题」窗口标题显示「1 条」但列表区域一片空白的问题：原来用 SwiftUI `List`（由 NSTableView 支撑），在这个独立窗口里行不绘制。改成 `ScrollView + LazyVStack` 手写行，并给每行加了自己的勾选框（`checkmark.square.fill` / `square`），点整行即可选中，全选/取消全选语义不变
  - 离屏渲染回归测试现在能真正验证行渲染（改前 List 版本的行在离屏位图里也是空白，改后能画出 side entrance / branch off from 两行及输入、时间）
- 涉及文件：`Deferred/StudyCenter/DictationUnitWrongWindow.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户在 1.23.5 上反馈「没有实现都没有实现」，实机核对确认三点面板两个入口都在、最近听的窗口正常，但「编辑本轮错题」窗口虽然有 1 条记录却不显示任何行
- 验证：`swift build`（`Deferred/StudyCenter`，debug）通过；`swift test --filter "WrongWordDataSafetyTests|DictationUnitWrongWindowRenderTests"` 6/6 通过且离屏位图可见两行内容；`Scripts/build-macos.sh` release 构建通过；`release_guard.py app/pack/verify` 全部 PASS；安装后实机打开该窗口已可见记录行（截图 `out-1236/screenshots/1236-wrong-window.png`）
- 未验证：未在全部 15 个主题下逐一核对配色

# LumaReader 1.23.5 B126

由 DeepSeek 更改 在 22:40 (UTC-07:00)，本次更新的安装包为 v1.23.5（build 126），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：fix + feature
- 更新内容：
  - 「本轮」不再因为你临时退出应用或点「继续听写」而重置：本轮起点改为持久化在 `StudyWorkspaceState.dictationRoundStartedAt`（随工作区一起存盘），退出应用再回来仍是同一轮，错题面板里的内容不会丢
  - 只有真正从头开始一轮听写才会重置：`selectDeckAndStartDictation(resume: false)`（含三点里的「重新开始本轮」）、`startDictation` 新建会话、`startDictationForFolder` 三处调用 `beginDictationRound()`
  - 升级后第一次进入听写页时，若工作区里还没有本轮起点，就地把当前时刻记为本轮起点（避免面板回溯出全部历史错题）
  - 三点设置面板里新增入口「最近听的词本 / 单元」（`study.dictation.recentDictions`）：打开独立窗口，按最近练习时间倒序列出听过写过的词本 / 单元，每行显示名称、已完成/总数、练习次数、错词数、最近一次时间，点一行直接切到那个单元继续听，支持按名称搜索
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/StudyWorkspace.swift`、`Deferred/StudyCenter/RecentDictationDecksWindow.swift`（新增）、`Deferred/StudyCenter/Package.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户指出「有时候因为会有一些事情要退出，这应该就不能改变，只有当我开始一轮新的听写重新开始，从零到最后一个…这才要清空」，并要求在三点里加一个能快速选择最近听的词本 / 单元的入口，而不是单词
- 验证：`swift build`（`Deferred/StudyCenter`，debug）通过；`swift test --filter "WrongWordDataSafetyTests|DictationUnitWrongWindowRenderTests"` 6/6 通过；`Scripts/build-macos.sh` release 构建通过；`release_guard.py app/pack/verify` 全部 PASS
- 未验证：新窗口「最近听的词本 / 单元」在真机上的点按与切换未逐一核对（按用户规则，小改动不做真机截图）

# LumaReader 1.23.4 B125

由 DeepSeek 更改 在 22:26 (UTC-07:00)，本次更新的安装包为 v1.23.4（build 125），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · claude-opus-5）
- 类型：fix
- 更新内容：
  - 1.23.3 的「本轮」判定用的是 `DictationSessionStateMachine.sessionID`，但续练会沿用同一个 session 一整天（本机实测该 session 已累积 395 条记录），所以面板仍显示 118 条——等于没生效。改为用新的 `dictationRoundStartedAt`（一个 `Date`）：每次进入或重新开始一轮听写都刷新为当前时刻，面板与按钮数字只统计这之后的错误尝试与「意思不清」词
  - `beginDictationRound()` 在 `selectDeckAndStartDictation`、`startDictation` 新建会话、`startDictationForFolder` 三处调用，并同时关闭旧的错题窗口；所以「重新听的时候这一面的错词应该要消失」现在真的成立
  - 输入框残留答案：补齐剩下三条恢复路径的守卫（`onAppear` 恢复、`startDictation` 续练恢复、合练续练恢复），统一规则为「本轮 `attemptLogs` 里出现过的词 → 一律空框」，不再只在提交后一处生效
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/DictationUnitWrongWindow.swift`、`Deferred/StudyCenter/Tests/DictationUnitWrongWindowRenderTests.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户实测 1.23.3「没有生效，没有实现」——错题面板仍是 118 条，输入框仍会带出上一次的内容
- 验证：`swift build`（`Deferred/StudyCenter`，debug）通过；`swift test --filter "WrongWordDataSafetyTests|DictationUnitWrongWindowRenderTests"` 6/6 通过；`Scripts/build-macos.sh` release 构建通过；`release_guard.py app/pack/verify` 全部 PASS
- 未验证：按用户规则（小改动不做真机点按与截图）未逐项实机核对

# LumaReader 1.23.3 B124

由 DeepSeek 更改 在 22:18 (UTC-07:00)，本次更新的安装包为 v1.23.3（build 124），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · claude-opus-5）
- 类型：fix
- 更新内容：
  - 「编辑本单元错题」改为「编辑本轮错题」：窗口与按钮上的数字现在**只统计当前这一轮听写**（按 `DictationSessionStateMachine.sessionID` 过滤错误尝试与「意思不清」词），不再把历史上所有错词堆进来。重新开始一轮听写时，这个列表自动清空，窗口也会关闭重建
  - 这个面板的定位就是「刚才打太快打错了，顺手改掉」，所以范围跟着当前听写走：听单词时就是这些词，听整单元时就是这一轮的整单元
  - 彻底修掉「下一个词输入框里还留着上一次的答案」：只要这个词在本轮已经提交过（`attemptLogs` 里有记录），再次出现时一律给空输入框，不再恢复任何草稿；提交时也会删掉该词草稿，新开一轮清空全部草稿
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/DictationUnitWrongWindow.swift`、`Deferred/StudyCenter/Tests/DictationUnitWrongWindowRenderTests.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户指出错题面板应与「我正在听写的这一轮」一致且是一次性的（重新听就该消失），并反馈输入框仍会带出上一个词的内容
- 验证：`swift build`（`Deferred/StudyCenter`，debug）通过；`swift test --filter "WrongWordDataSafetyTests|DictationUnitWrongWindowRenderTests"` 6/6 通过；`Scripts/build-macos.sh` release 构建通过；`release_guard.py app/pack/verify` 全部 PASS
- 未验证：按用户规则（小改动不做真机点按与截图）未逐项实机核对

# LumaReader 1.23.2 B123

由 DeepSeek 更改 在 21:56 (UTC-07:00)，本次更新的安装包为 v1.23.2（build 123），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：fix
- 更新内容：
  - 修「编辑本单元错题」显示 0 条：单元范围原来取的是「当前词库」选择器（`workspace.selectedDeckID`），但续练/今日计划的会话里装的是别的词本的词（本次是 `ielts.p2.work`／`ielts.p2.map`／`ielts.p2.travel`），选择器却是 `c20.corpus.u3`，两边对不上就统计成 0。现在改为按**本轮会话实际包含的词**所属词本统计（当前词 + 剩余队列 + 本轮已提交记录），词本数 >1 时标题显示「本轮 N 个词本」
  - 空格键继续计时：原来只在「今日计划」「错词复习」两个模式下生效，听写页其他模式（慢反应词、顽固单词、合练）按空格没反应；现在听写页任何模式都生效，且输入框里已经打了半截答案时空格仍然是打字，不会被抢走
  - 点底栏「意思不清」标记时，自动打开中文释义（会拼但不知道意思才需要标它，标的同时就把中文显示出来）
  - 修「输入框里还留着上一个词的答案」：提交后该词的草稿会被删掉，艾宾浩斯循环让同一个词再出现时输入框是空的；新开一轮听写时也会清掉上一轮遗留的草稿（`HostStateModel.discardStaleWordDrafts()`）
  - 「编辑本单元错题」的标题跟听写页顶部保持一致（仍是「剑20语料库 · 第3章」这类单元名），列表内容按本轮实际在听的词统计
  - `DictationShortcutPolicy.helpText` 里本来就写着「空格　计时已暂停时继续」，这一版才真正对齐实现
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`，以及技能文件 `/Users/sun/Documents/deepseek-harness/default-workspace/.dsh/skills/code-update-safeguard-v3/SKILL.md`（第 4 节验证分级、第 8 节交付措辞）
- 原因：用户报「为什么是 0」，并要求暂停后按空格继续、点翻译/意思不清时直接给中文；同时要求小改动不再强制真机测试与截图
- 验证：`swift build`（`Deferred/StudyCenter`，debug）通过；`swift test --filter "WrongWordDataSafetyTests|DictationUnitWrongWindowRenderTests"` 6/6 通过；`Scripts/build-macos.sh` release 构建通过；`release_guard.py app/pack/verify` 全部 PASS
- 未验证：按用户新规则（小改动不做真机测试、不截图），这三处没有逐一点按核对；「编辑本单元错题」条数变化依据的是 `luma_study_store.json` 里会话队列与错误日志的实际数据（`ielts.p2.map` 76 条、`ielts.p2.work` 60 条等）

# LumaReader 1.23.1 B122

由 DeepSeek 更改 在 21:44 (UTC-07:00)，本次更新的安装包为 v1.23.1（build 122），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：feature + ui
- 更新内容：
  - 听写计时新增「30 秒无操作自动停止」：连续 30 秒没有键盘或鼠标操作，今天的听写时长不再累加（琥珀色计时胶囊 + 反馈行提示「⏸ 已停止计时（30 秒无操作）· 动一下键盘或鼠标自动继续」）；一旦有键盘或鼠标操作，自动恢复累加并清掉提示。停止的只是计时，音频播放、判定、课程进度都照常
  - 听写设置面板去掉「更多」页：现在只有「练习」「发音」两个分类（原「更多」里的错词复习、慢反应提速、顽固单词、学习记录、云同步、多词本合练、重新开始本轮、词库管理、听写快捷键，在听写页右上角 ⋯ 菜单、听力主页与设置里都有同样的入口，因此不再重复占用一页）
  - 听写设置「练习」页去掉「当前词库」选择器：换词本请回听力主页选择，设置页不再重复
  - 每个单词独立保存听写记录：新增 `wordInputs` / `wordShowMeaning` / `wordRevealedWordIDs`（键为「模式|日期|词ID」）。切到下一个词会自动恢复这个词自己上次输入的内容与释义状态，别的词不会再把它的记录盖掉；点「上一个」回到之前的词同样取回它自己的记录；每次提交仍按原有方式追加一条尝试记录（历史不覆盖，只追加）
- 涉及文件：`Deferred/StudyCenter/StudyWorkspace.swift`、`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/StudyPersistence.swift`、`Deferred/StudyCenter/Tests/DictationUnitWrongWindowRenderTests.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户要求（1）超过 30 秒没操作就自动停止计时；（2）设置面板里的「当前词库」是多余的，可以自己退出去换；（3）「更多」那一页现在全都没用了，删掉只留两个分类
- 验证：`swift build -c debug` 通过；`swift test --filter WrongWordDataSafety` 5/5 通过（新增 `perWordDraftsSurviveRoundTripWithoutOverwriting`：两个词的记录互不覆盖、编解码往返保留、旧快照没有这三个字段时仍能解码）；`DictationUnitWrongWindowRenderTests` 通过；`StudyLearningRulesTests` 里 `wrongAnswersBlockAndCorrectionSchedulesDelayedCleanRecall`、`fourStageIntraSessionRetryLadder3_13_53_200AndShortEbbinghaus` 两个用例失败，已在 `git worktree` 用未改动的 HEAD（1.22.1 B118）复跑，**同样失败**，属既有问题、与本次改动无关
- 实机验证（1.23.1 build 122 安装于 /Applications，Info.plist 实测 1.23.1/122）：静置 40 秒后计时器停在 `00:38:19` 并转琥珀色、输入框下方出现「⏸ 已停止计时（30 秒无操作）· 动一下键盘或鼠标自动继续」（`out-1231/screenshots/1231-idle.png`）；随便点一下后计时恢复走动、提示消失（`1231-resume.png`）；听写设置面板只剩「练习」「发音」两页，且「练习」页已无「当前词库」（`1231-settings.png`）
- 未验证：每个单词独立记录只在单元测试与代码层面验证，未在真机上做「A 词输入 → 切到 B 词 → 回到 A 词」的完整点击核对；15 个主题下的琥珀色计时胶囊配色；多屏/小屏下的设置面板高度

# LumaReader 1.23.0 B121

由 DeepSeek 更改 在 21:27 (UTC-07:00)，本次更新的安装包为 v1.23.0（build 121），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：feature
- 更新内容：
  - 听写右上角三点打开的面板，第一屏（练习页）最上方新增整行主按钮「编辑本单元错题 N」：不用翻页、不用滚动就能看到并点击，N 是当前单元的有效错题条数
  - 点击后打开独立窗口「编辑本单元错题 · <词本名>」，一次列出本单元全部错题，不再只能处理当前这一个词；合练状态下按合练包含的多个词本汇总
  - 窗口内每一行区分两种类型：「拼写错误」（一条失败尝试，附你实际输入的内容与发生时间）和「意思不清」（会拼但不懂释义的词）
  - 支持逐条勾选与全选/取消全选；四个批量操作：「撤销所选错误」（只把选中的那几次错误尝试移出错题列表，原始练习日志与复习进度不动）、「标记意思不清」、「取消意思不清」、「导出」
  - 导出 CSV 支持「导出所选」与「导出本单元」，UTF-8 BOM + CRLF，列为单词、释义、类型、实际输入、发生时间，可直接在 Numbers/Excel 里筛选
  - 错词判定改为统一投影：错词中心、最近错词胶囊、错词复习、到期复习数、本轮报告、练习记录 TXT、分类总览错误计数、输入框下方的状态行全部按「已撤销的错误尝试不计入、意思不清计入」计算，撤销后各处数字一致
  - 练习记录 TXT 的类型列改为「误输（已撤销）／拼写错误／—」，意思不清以「 · 意思不清」后缀标注，只有意思不清、没有任何错误日志的词也会单独成行导出
  - 数据：StudyStoreSnapshot 新增可选 `suppressedWrongLogIDs`（按单条错误尝试的 UUID 撤销，不删除历史）与 `meaningUnclearWordIDs`（按词标记）；旧的 `wrongWordMarks` 字段仅用于读取旧快照并一次性迁移（旧「误输」按当时的错误尝试逐条迁移，不会遮蔽此后的新错误）
  - 云同步合并：两个新字段都做并集，撤销与标记在多台机器之间不会互相丢失
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/DictationUnitWrongWindow.swift`、`Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`、`Deferred/StudyCenter/StudyPersistence.swift`、`Deferred/StudyCenter/WrongWordsCenter.swift`、`Deferred/StudyCenter/DictationPracticeLayout.swift`、`Deferred/StudyCenter/Package.swift`、`Deferred/StudyCenter/Tests/WrongWordDataSafetyTests.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户要求把「不小心打错的词」和「会拼但意思不清的词」分开管理，并且要能一次看到、批量处理本单元的全部错题（而不是只能处理当前这一个词），入口必须在三点打开后第一眼就能看到
- 验证：- 验证：`swift build`（`Deferred/StudyCenter`，debug）编译通过（48 秒级，仅既有 warning）；`swift test --filter WrongWordDataSafetyTests` 4/4 通过（日志不被删除、按 UUID 撤销、旧数据迁移不误伤新错误、云合并并集、按词本投影）；`Scripts/build-macos.sh` release 构建通过（codesign --verify --deep --strict、plutil -lint、check-app-bundle.py 均 PASS，Info.plist 实际为 1.23.0/121）；`release_guard.py app` PASS、`pack`/`verify` PASS；本机安装 1.23.0（build 121）后实机核对：听写页右上角三点打开面板，**第一屏最上方就是整行的「编辑本单元错题」主按钮**（`out-1230/screenshots/t14-popover.png`），点击后独立窗口「编辑本单元错题 · 剑20 语料库 · 第3章」弹出，标题、条数、空态文案、底部「全选／标记意思不清／取消意思不清／撤销所选错误／导出」按钮与说明行均正常渲染（`out-1230/screenshots/step2-more.png`）
- 未验证：- 未验证：本机当前词库（剑20 语料库 · 第3章）当日没有错题，实机看到的是 0 条空态；**含内容的列表渲染、勾选、批量撤销、CSV 导出没有在实机点按核对**（未切换用户正在练的词库，避免打断练习），这几项仅有单元测试与代码路径支撑；「意思不清」标记后窗口内行是否立即刷新未实机核对；15 个主题下该窗口的配色未逐一核对；云盘跨机合并只跑了单元测试；窗口尺寸 940×570 在 1087×711 主窗口下不会遮挡主界面，但小屏（<940 宽）未试

# LumaReader 1.22.3 B120

> 说明（后补，不改上文历史记录）：本版为中间构建，只在本机安装过、未打包交付；其中的「误输」按词互斥标记语义已被 1.23.0 的逐条撤销方案取代。

由 DeepSeek 更改 在 19:53 (UTC-07:00)，本次更新的安装包为 v1.22.3（build 120），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 新增错词类型标记「意思不清」：底部操作栏第 7 个功能键（问号图标）一句话标记当前词「我会拼，但意思不清楚」，再次点击取消；只写标记，不改拼写判定、不改输入框、不改进度与练习数据
  - 新增错词类型标记「误输」：听写设置（三个点）→ 更多 → 当前词，可「不小心打错 · 删掉这个词的错词记录」；标记后该词不再计入错词，也不出现在错词复习、今日错词队列、错词合练与「最近错词」胶囊里；同一处可取消，面板底部另有「恢复全部误输标记（N 个）」
  - 错词中心：每个错词显示类型徽章（「误输」灰色 /「意思不清」蓝色），「操作」菜单里的已选单词区新增标记与取消标记两个入口
  - 导出：练习记录 TXT 新增「类型」列（误输 / 意思不清 / 拼写错误），并在文件开头加一行类型说明
  - 数据：StudyStoreSnapshot 新增可选字段 `wrongWordMarks`（wordID → "typo" / "meaning"），旧数据缺字段时按无标记解码
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/WrongWordsCenter.swift`、`Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户希望把「手滑打错」的词移出错词，并把「会拼但不懂中文」的词单独归成另一类错题，且两类都能导出
- 验证：`swift build`（`Deferred/StudyCenter`，debug）编译通过；`Scripts/build-macos.sh` release 构建通过（codesign --verify --deep --strict、plutil -lint、check-app-bundle.py 均 PASS）；`release_guard.py app` 版本/构建号校验 PASS；安装 1.22.3（build 120）后在 1087×711 窗口实机核对：底栏第 7 个问号按钮存在且点击后高亮，标记已写入 `luma_study_store.json` 的 `wrongWordMarks`；三个点 → 更多 → 当前词 面板正常显示当前词与两个标记按钮
- 未验证：错词中心里的类型徽章与「操作」菜单标记入口未实机打开核对；标记为「误输」后从错词复习/今日错词队列中消失的效果仅走了代码路径，未做实机演练；未逐一切换 15 个主题检查两种徽章配色；未在快速过词策略下复检

# LumaReader 1.22.2 B119

由 DeepSeek 更改 在 18:46 (UTC-07:00)，本次更新的安装包为 v1.22.2（build 119），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 修复听写答错后看不到中文释义与错在哪：反馈区（中文、订正提示、结果行）此前被排到比窗口更高的画布底部，初始滚动停在顶部时整块落在可视区之外
  - `DictationPracticeLayout` 改为「装得下就上下等距居中、装不下就紧凑排布」，状态行始终紧跟输入框下方；输入框在进度条下方的绝对位置与 B118 保持一致（两种分支的输入框顶端都在 topHeight + 16）
  - 快速过词（B113 默认策略）答错后新增「刚才这个词拼错了」卡片：保留这一题的正确拼写（错字母红字标出）、中文释义、用户实际输入与「已记入错词（本次第 N 次）」，直到下一次提交
  - 提交反馈文本此前只有赋值、从未渲染，现在显示在输入框下方（拼写正确 / 已记入错词 / 错词循环第几轮 / 进入顽固单词）
  - 答错不再把「下一个词」的中文释义提前显示（原来 `showMeaning` 直接取 `last.isCorrect == false`，快速过词切词后会泄题）
  - 提交后自动把反馈区滚进视野（答对则回到画布顶部），减少动态效果时改为直接跳转、不加动画
- 涉及文件：`Deferred/StudyCenter/DictationPracticeLayout.swift`、`Deferred/StudyCenter/StudyHome.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户反馈最新版听写打错之后看不到下方中文翻译，也不知道自己错在哪里、错成什么样
- 验证：`swift build`（`Deferred/StudyCenter`，debug）编译通过；`Scripts/build-macos.sh` release 构建通过（codesign --verify --deep --strict、plutil -lint、check-app-bundle.py 均 PASS）；`release_guard.py app` 版本/构建号校验 PASS；`release_guard.py pack` 与 `verify` PASS；安装后在 1087×711 窗口（与用户截图同尺寸）实机核对：输入框下方重新出现「词条 · 第 N 次出错 · 最近反应时间 X.Xs」状态行，答错时显示中文释义、红字标错拼写与「拼写有误（今日第 N 次），请订正」
- 未验证：快速过词（快速跳词）分支下「刚才这个词拼错了」卡片已在代码中实现并编译通过，但实机核对时本机词库设置为循环复习、未切换到快速过词复检该卡片；未逐一切换 15 个主题与 Space / Manga 检查卡片配色；未验证连续快速提交时滚动动画的手感；队列最后一个词答错时会直接进入本轮回执页，卡片不在该页显示

# LumaReader 1.22.1 B118

由 DeepSeek 更改 在 22:28:00 (UTC-08:00)，本次更新的安装包为 v1.22.1（build 118），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 用 2261 行新实现替换雅思阅读练习视图，内置原创文章、十个题组、图示与全屏机考布局
  - 主窗口接入练习状态通知：进入机考时收起侧栏与 AI 面板，返回题组后恢复
  - 新文件 4 处不存在的 studyGlassSurface 改为项目既有的 studyGlassCapsule，修复编译错误
- 涉及文件：`Deferred/StudyCenter/IELTSReadingPractice.swift`、`Sources/LumaReader/ContentView.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户要求检查两个 gemini 生成文件的语法错误并加入安装
- 验证：release 编译通过；实机从侧栏雅思阅读进入题库目录、选题组、开始机考，确认计时/分屏/拖放槽/题号导航、练习时侧栏收起、返回后恢复
- 未验证：未逐题作答并交卷验证判分与错题跳转；未在全部 15 个主题下截图

# LumaReader 1.22.0 B117

雅思阅读新增题型样例入口，内置原创文章、十个题组和图示，供单独试做。

# LumaReader 1.21.3 B116

雅思阅读按题型区分拖放、段落选择、单选、多选和填空。标注操作条在选区下方打开，练习沿用主窗口侧栏和可调整宽度的左右分栏。

# LumaReader 1.21.2 B115

补齐听写操作栏的返回语句，修复 B114 编译报错。

# LumaReader 1.21.1 B114

听写订正输入匹配时直接显示正常拼写，避免旧提示标红。

# LumaReader 1.21.0 B113

新词听写新增快速过词和循环复习，订正提示随输入更新。

# LumaReader 1.20.3 B112

听写操作栏固定在窗口底部，正文单独滚动。

# LumaReader 1.20.2 B111

雅思阅读使用实色纸面和清晰的题组排版。单选展开、匹配题统一展示选项、摘要在原位填空。

# LumaReader 1.20.1 B110

雅思阅读原文复用写作题干的高亮与笔记交互，兼容已有阅读标注。

# LumaReader 1.20.0 B109

雅思阅读新增题库搜索、按篇保存未完成练习、未答题和待复查定位、交卷确认及错题跳转。Swift 语法和后端测试通过，macOS 原生交互待验证。

# LumaReader 1.19.0 B108

雅思阅读新增原文高亮与笔记、专项计时、题号跳转、待复查标记和独立字号滑杆。Swift 语法与后端测试通过，macOS 原生交互待验证。

# LumaReader 1.18.1 B107

雅思阅读题库按题型筛选，进入文章后可勾选所有可用题组。已导入 PDF 目录第 1、50 篇。

# LumaReader 1.18.0 B106

新增雅思阅读试点。题型与 Passage 位置独立筛选，导入本地题库目录第 1、50 篇。原题未标注考试位置，可手动归类。

## 1.17.1 · Build 105 (2026-11-12)

- 阅读四选一答对自动前进的停顿缩短到 80 毫秒，快速切题动画缩短到 100 毫秒。

## 1.17.0 · Build 104 (2026-11-12)

- 阅读四选一继续使用所选神经语音，必要时重新启动语音进程。
- 阅读四选一增加独立每日计时，切后台、锁屏、离开练习或完成本轮时暂停。

## 1.16.1 · Build 103 (2026-11-12)

- 将听写设置的三个标签拆为独立视图，修复 B102 安装日志中的泛型类型推断错误。

## 1.16.0 · Build 102 (2026-11-12)

- 听写设置使用三标签布局，发音模型细节可展开，词库管理收进子菜单。每日词数目标在词库首页设置。
- 阅读四选一支持手柄面键答题、肩键重播／继续和菜单键操作说明。

## 1.15.1 · Build 101 (2026-11-12)

- 听写页首屏共享进度统计，读取最近错词时避免复制完整记录。
- 从词库卡片打开练习时，输入框随页面就绪并请求焦点。
- 神经语音先生成当前词，再预读后续词。

## 1.15.0 · Build 100 (2026-11-12)

- 保留词库浏览位置，听写与背词卡片可继续未完成的练习。
- 听力与阅读错词优先显示到期词，并简化练习结束页。
- 阅读四选一保存当前轮次、原选项排列与作答状态。

## 1.14.3 · Build 99 (2026-11-12)

- 对齐听力与阅读词库的页头和网格，缩短卡片，收紧听力到期复习栏。
- 每日听写进度保持为首个内容区，阅读导入和易混词收进操作菜单。

## 1.14.2 · Build 98 (2026-11-12)

- 阅读四选一独立打乱题序，随机分配每四题的 A/B/C/D 正确位置，并过滤重复、共享义项及已知同义释义。
- 移除听力首页的慢反应词快捷按钮，菜单入口仍可使用。

## 1.14.1 · Build 97 (2026-11-12)

- 修复阅读词库卡片多余的花括号。
- 恢复听力词库原操作菜单，将阅读内置词库的编辑限制放到阅读分类菜单。

## 1.14.0 · Build 96 (2026-11-12)

- 阅读词库、背词、错词和分类使用同一套内置与导入词条，易混词可从阅读词库发现并引用词条。
- 「词库」「错词」「分类」为阅读区的三个主入口。词库详情可直接背词，错词可筛选和复习，分类可管理文件夹及词库归属。

## 1.13.1 · Build 95 (2026-11-12)

- 阅读词汇采用听力词库的卡片布局，点开词表后显示单词与中文释义。
- 「词库」「背词」「易混词」统一置于阅读词汇页顶部。

## 1.13.0 · Build 94 (2026-11-11)

- 新增独立的「学习 → 阅读词汇」入口，支持按词表、List 筛选与英文、中文检索。
- 保留 Excel 底本的 3,631 条原词、顺序和音标，加入去重后的 877 条阅读补充词和 1,555 条阅读进阶词。
- 常用中文释义采用清理后的 ECDICT 与补写释义，多义词保留常用义项。

## 1.12.4 · Build 93 (2026-11-11)

- 悬浮练习小窗的词库独占一行，放大听写输入区并按可用宽度适配长词。窗口较矮时题目区可滚动，提交和进度保留在底部。
- 小窗可选择跟随学习设置、Kitten 本地神经语音或 Apple 系统语音。浮在其他 App 上方时可按需启动 Kitten，休眠和关窗时停止小窗发音。

## 1.12.3 · Build 92 (2026-11-11)

- 听写使用已有词库索引建立队列，练习页直接采用最终宽度，动态模式下只为顶部练习栏添加轻微淡入。
- 首词自动播放合并成可取消的单次任务。分类文件夹启动沿用延后保存路径。
- AI 侧栏弹簧只用于面板的位移、缩放和透明度。正文直接采用目标宽度，调整尺寸后合并定位更新。阅读搜索的转场范围缩小到浮层。

## 1.12.2 · Build 91 (2026-11-12)

- 新增快捷键：切到后台计时会自动暂停，回到听写页后单按空格即可继续计时并开始播放，不用再点计时器。已写入快捷键说明。
- 听写设置面板整理：去掉重复项（听力页里重复的「语音声线」、重复的倍速下拉，只保留倍速滑块）；「当前默认发音人」改名「当前声线」；各声线的具体音色折叠起来；去掉「在 Finder 打开模型目录」「更多发音与语音服务设置」「返回词库主页」「继续阅读」（左上角有返回、菜单有⌥⌘5）；「模块与同步」改名「复习与数据」。
- 未改动：听写输入框、进度条、错误动效、分类与错词布局等红线功能。

## 1.12.1 · Build 90 (2026-11-12)

- 修复听力倍速失效：原先每播一个词都会把整个音频引擎关掉再重开，重开后变速单元会回到 1.0×。现在引擎在播放期间保持运行，倍速在引擎启动后再次写入，重复播放的间隔里引擎被空闲关闭也会自动补启动并恢复倍速。
- 修复发音最后一个声音奇怪：你的 kokoro_neural_daemon.py 里有一段自己加的「v1.10.14 Hook」（官方 KittenTTS 没有）。它会无条件把音频尾部砍掉约 46 毫秒，正好切进最后一个音素，还会把短词语速偷偷改成 1.06。现在不再硬切，只裁掉真正的静音尾巴，保留 70 毫秒余量并做 25 毫秒平滑淡出，也不再改语速。音频缓存版本升到 v10，旧音频会自动重新生成（首次听每个词会稍慢一点）。
- 优化卡顿：进入/退出词汇听写时不再同步写盘，改为稍后合并保存；首个单词在转场渲染完成后再播放；去掉了整页随模式切换的隐式动画（它让整个听写页和侧栏一起做布局动画）。
- 学习中心动效整体变快：页面切换 0.36→0.20 秒、标签 0.34→0.20 秒、悬停 0.22→0.13 秒、按下 0.18→0.09 秒，并改为先快后慢的曲线，跟手感更好。仍遵守「减少动态效果」设置。
- 未改动：听写输入框、进度条、错误动效、分类与错词布局等红线功能。

## 1.12.0 · Build 89 (2026-11-12)

- 新增「易混词」系统（侧栏 学习 → 易混词），自带独立词组库，不读写听力和背词词库。像 curse / course / coarse 这样容易混的词按组管理。
- 添加方式：手动新建一组；粘贴或导入文本（一行一组，逗号 / | 分隔，可带中文释义，缺的自动补）；从听力词库、背词词库里自动发现（拼写只差一个字母、相邻字母颠倒、音标相同）。导入和自动发现都先列出来由你勾选，已存在的会标出，不会悄悄跳过。
- 支持编辑、分类、搜索、删除（需确认）、统计每组练习与答错次数，可只练「易错」。
- 练习方式：听写，或听音选词（选项就是同组的易混词，答错时并排显示各词释义）。出题顺序：顺序 / 组内打乱 / 全部打乱。听写沿用听力的组合键：⌘R 重播、⇧⌘R 慢放、⌘/ 提示首字母、⌥⌘M 显示中文、⌘' 看答案。
- 新增悬浮小窗（⌥⌘6，或菜单 学习 → 悬浮小窗练习）：置顶、可拖动、可调透明度、所有桌面可见（包括全屏视频的桌面）；点它不会把正在看的视频或浏览器切到后台。小窗里可练易混词，也可做听力词库听写（含「全部错词」），答题按普通听写记录写回听力错词本（可在小窗设置里关闭）。
- 听力页「⋯」菜单新增「小窗听写（悬浮置顶）」。
- 主窗口和小窗现在共用同一个学习会话，避免两份数据互相覆盖。
- 未改动：听力听写输入框、进度条、错误动效、分类与错词布局等红线功能。

## 1.11.1 · Build 88 (2026-11-11)

- 「背词」改为与听力完全独立的系统：侧栏「学习」下新增独立入口「背词」，自带独立词库文件（ChoiceQuiz/choice_vocab_store.json，原子写入 + .bak 备份）；不读写听力词库、听写会话和错词记录。
- 移除 1.11.0 放在听力顶栏和听力词库右键菜单里的背词入口。
- 导入：txt / csv / tsv / json，沿用原来的导入预览（同词不同义、完全重复、忽略行全部列出，由你勾选决定）；可导入为新词库，或「追加导入到此词库」。
- 编辑：新增/修改/删除词条，可编辑音标；允许同一单词保留多个不同释义。新建空词库、重命名、删除（需确认）。
- 文件夹与分类：多级文件夹；新建、重命名、移动、删除（内容自动移到上一级，不丢词）；词库和文件夹可拖到文件夹或路径栏，也可用「移动到…」。
- 词库卡片显示词数和背诵进度，可「从头重新背」；搜索可按词库名、单词或释义查找。

## 1.11.0 · Build 87 (2026-11-11)

- 新增「背词」：ABCD 四选一中文释义的背单词模式（不听写）。入口：听力顶栏「背词」、词库卡片右键「选择题背词」。
- 每题自动播放发音；干扰项优先取同词库、同词性的释义，并排除与正确答案重复或包含关系的释义。
- 快捷键：1–4 / A–D 选择，Space / R / ⌘R 重播，Return / → 下一个，H 提示（排除两项），E 看答案，P 自动播放开关，W 复习错题，? 快捷键，Esc 返回。
- 护眼：静态背景 + 四周暗角把视线收拢到单词；文字不用纯黑纯白，护眼模式下降低饱和度；无循环动画，静态设计/减少动态效果时关闭全部过渡。
- 跟随当前主题（Monet / Space / Manga 等）的纸张、墨色、强调色与玻璃设置；Manga 使用墨线框，不使用玻璃。
- 进入背词后侧栏自动收起（与听写练习相同的专注模式）。
- 每个词库单独记住背到哪里；每组 10/20/30/50 词可选；结果页可只复习选错的词。
- 不写入听写错词本和听写日志，不改动听写输入框、进度条、错误动效等红线功能。

## 1.10.3 · Build 86 (2026-11-11)

- Kitten 预设按男女声过滤，移除未经证实的美音／英音标签，并纠正旧配置中不匹配的选择。

## 1.10.2 · Build 85 (2026-11-11)

- 恢复 B82 的 Kitten 合成、淡入淡出和前后 80 ms 静音缓冲，继续从 App 读取内嵌权重。
- 保留 B84 的听写输入框等比缩放和滚动区域裁切。

## 1.10.1 · Build 84 (2026-11-11)

- 恢复听写宽版输入框，按窗口可用宽度同步缩放宽高。
- 裁切词库网格和侧栏的滚动区域，避免覆盖顶部按钮。

## 1.10.0 · Build 83 (2026-11-11)

- 听力分类树形列表改用局部裁切和主题行底色，路径栏固定在列表上方。
- 听写输入框按窗口宽高使用同一缩放系数，保持居中与长词自适应。
- Kitten Nano 和 Micro 随 App 内嵌，首次成功生成语音后清理旧模型下载副本。
- EPUB 新增可选 StPageFlip 纸张翻页，兼容现有单页、双页和自动排版。

## 1.9.6 (Build 82) — 2026-11-11

- 限制听力分类内容在列表区域内滚动，移除层级标签、子目录数量和重复提示。
- 书库拖放改为卡片局部落点高亮，并统一落下后的排序动画。

## 1.9.5 · Build 81 (2026-11-11)

- 剑20 词库恢复原始 Excel 三级结构：**剑桥20 → 第X章 → sheet（3.3-1…3.3-9、4.3-1…4.4、5.3-1…5.3-12、11.1…11.4）**；3,487 词按 sheet 归位，29 个 Excel 未收录的英式变体归入“其他”。
- 阅读器选中文字的高亮从固定灰蓝改为跟随主题强调色（`color-mix`），失焦时自动变淡，不再是一块突兀的灰框。
- 图标/分栏/列表三种视图切换改为瞬时切换，避免大视图交叉淡入造成的文字重影/叠影。
- release 编译通过；实机确认 剑桥20/第11章/11.1 层级正确。

## 1.9.4 · Build 80 (2026-11-11)

- 书库网格视图补齐拖放目标：之前只能拖动书封、不能放到另一本上，所以拖动排序在网格里不生效；现在拖到任意书封上即可排序并自动切到“自定义排序”。
- 列表视图去掉重复的 dropDestination 与两处静态置顶图标。
- 每本书新增圆角置顶按钮（悬停显示、置顶时常显），点击即可置顶/取消置顶；置顶书始终排最前，拖到置顶书会自动置顶。
- release 编译通过；实机确认置顶按钮可点、状态持久化、书封回到首位。

## 1.9.3 · Build 79 (2026-11-11)

- 所有“展开/折叠”按钮改为圆角大热区（听力三级树 30/26pt、云盘文件区 30pt，带悬停底色与旋转动画），解决“点了没反应”。
- 听力分类分栏删除最右侧空白单词预览栏，三栏均分宽度；一键“全部听写”移到面包屑最右侧（根目录=全部单词，文件夹=该文件夹）。
- 听写流程彻底分离：普通听写每个词只过一遍（答错只记入错词本，不再本轮插队）；错词循环只在“错词复习”里进行。
- 错词中心新增“全部错词听写 N”，把全部词库的错词合并成一个循环听写会话。
- 恢复剑20语料库 3,498 词（第3/4/5/11章），并完成深度去重：同释义短语/单词删 33 个，保留美式删英式 2 个，单复数全部保留；词库从 3,627 变为 7,090。
- release 编译通过；新增的普通听写/错词复习两条测试通过。

## 1.9.2 · Build 78 (2026-11-11)

- 修复 1.9.0 源码无法编译的三处错误：`NSCache` 并发隔离、主视觉渐隐遮罩的 `blendMode` 歧义、`VisualThemeBackdropDrawing` 的 `Equatable`（`@AppStorage` 不参与合成）。
- 个性化修复：输入框透明度只淡化底色（文字保持可读）；顶栏透明度只淡化顶栏底色（按钮与红黄绿保持清晰）；阅读顶栏按钮大小改为等比缩放，窗口过窄时自动限制，红黄绿中线不变。
- “导入主题主视觉”补全为可用功能：实时预览（140ms 防抖）、缩略图、拖放导入、参数范围校验、缓存并发修复、导入/移除/重置状态反馈。
- 侧栏回到左侧：主题布局不再把侧栏移到右边。
- 阅读顶栏恢复原始 split 布局：左侧四键、右侧三键、书名居中，七键与原生红黄绿同一条水平中线（不再按主题合并/居中）。
- release 编译通过；根测试 130 项中 6 项失败与 1.7.3 基线一致（窗口悬停/探针的环境性失败）。StudyCenter 包测试 80 个 issue 与 1.7.3 基线相同。

## 1.9.0 · Build 76 (2026-11-11)

- 新增「自定义主视觉」（设置 › 主题）：为当前主题导入自己的漫画 / 插画，可调不透明度、遮罩（压低过深或过亮的图）、模糊、右下角大小与水平 / 垂直位置，或铺满背景；左、上边缘可渐隐；可替换内置矢量图或叠在其上。图片缩到最长边 2000px 存本机，设置变化时才重绘。
- 新增「界面透明度与大小」：按钮栏不透明度（30–100%）与大小（80–125%）、输入框不透明度。默认 100%，与旧版一致；听写输入框的尺寸与位置不变。
- 全部用系统 ImageIO / SwiftUI 实现，无新依赖、无计时器、无动画。
- 未验证：Mac 原生编译、界面截图与测试运行。
- 参考：VS Code 背景插件、Obsidian 壁纸插件的「不透明度 / 模糊 / 大小 / 位置」做法。

## 1.8.3 · Build 75 (2026-11-11)

- 主视觉改为漫画风：所有场景加上粗细有别的墨线轮廓、斜向排线阴影（按形状裁剪）、左上角网点（半调）天空、星芒高光，角色眼睛加白色高光；半透明光束不再描边。
- 沿用 1.8.2 的伏见稻荷鸟居、神奈川冲浪里、Space 天文台重绘。`HeroScenes.swift` 新增裁剪标记，仍为静态绘制，无计时器与动画。
- 新增测试：裁剪标记成对。未验证：Mac 原生编译与界面截图（排线裁剪在 SwiftUI Canvas 中的实际效果需在 Mac 上确认）。

## 1.8.2 · Build 74 (2026-11-11)

- 重绘三幅主视觉：京都提灯的伏见稻荷改成一整条向远处延伸的千本鸟居隧道；镰仓海风把神奈川冲浪里移到左侧，富士山与红日完整露出，增加远浪与渔船；Space 天文台重做肋骨圆顶、直达天顶的快门缝、窗列与望远镜。
- 无其它改动。未验证：Mac 原生编译与界面截图。

## 1.8.1 · Build 73 (2026-11-11)

- 主题主视觉：14 个主题改为一幅大尺寸标志性建筑 / 原创角色场景（新文件 `HeroScenes.swift`），不再是角落里的小插画。
  - 真实地标：京都八坂塔 + 伏见稻荷千本鸟居（京都提灯）、东京天空树（晴空夏影）、东京塔（都市漫绘）、江之岛灯塔 + 富士山（海风漫绘）、富士山与神奈川冲浪里（镰仓海风）、平等院凤凰堂（抹茶白玉）、道后温泉式三层汤屋（千与千寻）、姬路城（Manga）、巨大杉树 + 石灯笼（森之漫绘）、天文台圆顶（Space）。
  - 原创角色：废墟流浪者与环绕球体（尼尔）、复古机器人「Rivet」与冷却塔群（废土终端）、石狐像、灯笼精灵、茶碗精灵、苔藓精灵、宇航猫、骑车少女、撑伞少女。
  - 场景用 SVG 风格路径数据描述，启动后解析一次，静态绘制，无计时器与动画；尼尔与废土保留 CRT 扫描线。
- 不绘制 2B、千寻、白龙、无脸男等现有作品角色；如需使用自己的图片，后续可加「导入主题主视觉」。
- 未验证：此环境无法编译 macOS 原生应用；场景数据已在浏览器中用同一份路径做过预览，Swift 渲染仍需在 Mac 上确认。

## 1.8.0 · Build 72 (2026-11-11)

- 主题重设计：每个主题拥有自己的布局档案（新文件 `LumaThemeLayout.swift`）——侧栏在左/右、阅读顶栏七键为「分组 / 长栏 / 居中浮岛」、书库标题区为「左 / 右 / 堆叠 / 居中」、主题标题字体与说明小字、书封装饰（纸摞、墨线分镜、战术角框、铆钉钢板、和纸胶带、朱印等）。设置 › 主题可关闭「主题专属布局」回到统一布局。
- 尼尔机械纪元：背景重绘为苔绿废墟都市（坍塌高楼、藤蔓、断裂高架、光束 + 米灰战术 HUD），新增默认预设「废墟都市 · 苔绿藤蔓」。不再绘制角色剪影。
- 新增「废土终端 · Wasteland Terminal」：荧光绿 / 琥珀 CRT 与地堡日光三种预设，铆钉钢框、指针仪表、线框废土天际线；书封以单色荧光显示；专属听写错误反馈与 AI 面板样式。
- 五个经典配色：强调色与表面色加深（对比度全部提高），纸张色不变以保持与 Reader.js 同步。
- 性能：所有新增装饰为静态形状/单 Path 绘制，无模糊阴影、无计时器或常驻动画。
- 不变：听写输入框尺寸与位置、进度条、错误判定、写作高亮与笔记流程。
- 未验证：本环境无法进行 macOS 原生编译与界面截图，需在 Mac 上运行安装后确认。

## 1.7.3 · Build 71 (2026-11-11)

- 云盘总览并入“云盘”：移除页面上多余的“云盘总览”名称与侧栏的独立入口，现在只有侧栏一个“云盘”大按钮，点按直达该页。
- 把 `~/Applications` 的旧副本一并更新，避免 Dock 打开 1.7.0。

## 1.7.2 · Build 70 (2026-11-11)

- 云盘页融入主题：移除不透明黑底，改用与书库相同的主题画布；云盘卡片与文件区改用主题玻璃/独立材质与主题强调色，文件列表不再使用系统深色 Table。
- 云盘布局统一：三张云盘卡片等高对齐；文件列表改为可主题化的自绘列表（同一套 ink/muted/accent）。
- 侧栏云盘只保留一个 50pt 大按钮（连接状态圆点 + 同步指示），删除 iCloud/OneDrive/Google Drive 三行；点按直接进入云盘总览。
- 点按任意云盘卡片弹出小窗：立即同步 / 在文件管理中浏览 / 更换同步目录… / 断开 / 接入。
- 云盘文件区支持伸缩：标题栏箭头折叠/展开，列表高度随窗口高度自适应，卡片按宽度 3/2/1 列自适应。
- release 编译通过；126 项测试中 6 项失败与 1.7.0 基线完全相同（窗口悬停与探针的环境性失败）。

## 1.7.1 · Build 69 (2026-11-11)

- 阅读目录：扁平化可见行渲染，展开/折叠只重建当前行；去掉列表隐式动画与整体折叠的逐行动画，点击即时生效且不再闪烁跳动。
- 阅读目录：打开面板不再自动聚焦搜索框；“当前位置 / 全部展开 / 全部折叠”改为大热区胶囊按钮并增加悬停反馈。
- 阅读目录：面板打开期间保持顶部红黄绿与功能胶囊常驻，鼠标移入目录不再让整条顶栏消失又出现。
- 云盘：总览页改为固定返回书库标题栏；删除统计卡、独立空状态与底部长说明；云盘卡片与文件管理操作合并为“主按钮 + ⋯”。
- 云盘：从云盘总览点击书库、分类、学习入口或打开图书时立即回到书库。
- 实机验证：真实点击目录展开/折叠与全部展开/全部折叠均即时生效；打开目录不再聚焦搜索框；云盘总览与“云盘→书库”即时跳转通过截图确认。

## 1.7.0 · Build 68 (2026-11-11)

- Restore Kitten Nano and Micro provisioning during installation and provide a retry action in speech settings.
- Report neural model loading and playback failures accurately. Keep dictation usable with its existing fallback.
- Add saved global text size for the app interface, EPUB reading, writing, and AI chat.
- 19 backend tests passed. Native macOS installation, audible neural playback, and UI interaction await verification.

## 1.6.1 · Build 67 (2026-11-10)

- Fix the Swift 6 `sending note risks causing data races` compiler error reported by the B66 native installation log.
- Extract the Sendable Bool from Notification before entering MainActor.assumeIsolated; keep lifecycle and resource policies unchanged.
- Source correction only; a successful native macOS build is still pending.

## 1.6.0 · Build 66 (2026-11-10)

- Resource audit: incremental transactional essay writes, unchanged-JSON write suppression, external SQLite connection invalidation.
- Bound decoded-cover cache by cost, coalesce seed-index writes, limit/deduplicate thumbnail decoding, release offscreen images and derived vocabulary caches.
- Limit pinned Kitten ONNX sessions to two CPU threads with spinning off; release owned speech workers after background/idle periods; cap regenerable WAV cache.
- Preserve visual output while isolating static backdrop evaluation; stop speculative reader preparation in background and deduplicate native hover reconciliation.
- Replay: resume paused dictation, keep latest playback settings during synthesis, reject stale playback generations, decode repeated audio once, reuse matching audio graph format.
- Add listening shortcuts scoped to the active practice window; preserve the macOS Command-H shortcut.
- Validation: 18 backend/SQL/HTTP tests and static/syntax checks passed. macOS build, native tests, audible replay, real CPU/RSS/GPU measurements remain unverified.

## 1.5.0 · Build 65 (2026-11-10)

- Lifecycle and background-work fixes; remove duplicate activation-time saves and synchronous allocator pressure relief.
- Manage speech child-process lifetime, bound service requests and queues, cancel pending synthesis on pause.
- Crash capture installs independently of verbose logging and reports installation errors.
- Retire Kokoro 82M; preserve Kitten Micro/Nano and Apple speech; installer removes known retired weights only.
- Add cloud-folder file browser with upload, rename, folder creation and confirmed Trash operations.
- Stop forcing new app instances from installers; add duplicate-instance check and read-only local diagnostics.
- Validation: eight Python regression tests and static/syntax checks passed. Native macOS build, UI, sleep/wake and mouse-event reproduction remain unverified.

# Changelog

## 2026-11-11 12:36:00 (-07:00) · 1.9.5 (81)
由 DeepSeek 更改 在 12:36:00，本次更新的安装包为 v1.9.5（build 81），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - `VocabularyWord` 新增可选 `folderPath`，导入数据可直接携带原始工作簿层级；`effectiveThreeLevelPath` 优先使用它。
  - 剑20 全部 3,487 词按原 Excel 报告重新写入 folderPath：剑桥20/第3章/3.3-1…3.3-9、第4章/4.3-1…4.3-3 与 4.4、第5章/5.3-1…5.3-12、第11章/11.1…11.4；29 个 Excel 未收录的英式变体归入“其他”。
  - 阅读器 `::selection` 改为 `color-mix(var(--accent) 34%)`，并在注入 CSS 时补充 `--accent`；窗口失焦时降为 18%，不再使用固定灰蓝色。
  - 视图切换（图标/分栏/列表）改为禁用动画的单次事务，消除两张大视图交叉淡入导致的文字叠影。
- 涉及文件：`Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`、`Deferred/StudyCenter/StudyHome.swift`、`Sources/LumaReader/ReaderController.swift`、`Sources/LumaReader/Resources/Reader.css`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 数据变更：`~/Library/Application Support/LumaReader/StudyCenter/luma_study_store.json` 的 c20 词条写入 folderPath；备份 `backups/pre-c20-folders-20261111-123001.json`。
- 原因：用户要求“剑桥20 是专门文件夹，里面再按 Excel 的 3.3-1/5.3-2… 分小节”，并指出选中文字的灰框很怪、列表切换有重影。
- 验证：`build-macos.sh` 通过并生成/安装 1.9.5（81）；实机确认“剑桥20 → 第11章 → 11.1”层级与 4 个章节、30 个三级小节；安装包内 Reader.css 已含新的 `::selection` 规则；1.9.4 的拖动排序/置顶仍可用。
- 未验证：真实鼠标拖拽与真实拖选文字的视觉截图未自动验证；未重跑全量测试（本次为视图/数据改动，编译通过）。

## 2026-11-11 12:30:00 (-07:00) · 1.9.4 (80)
由 DeepSeek 更改 在 12:30:00，本次更新的安装包为 v1.9.4（build 80），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 网格视图的书封补齐 `.dropDestination`：此前网格卡片只有 `.draggable`，拖起后没有可放置的目标，导致“拖动排序”在默认网格布局里完全无效；现在拖到任意书封即可排序，并自动切换到自定义排序。
  - 列表视图移除重复的 `.dropDestination`，并删除两处不可点击的静态置顶图标。
  - 新增统一的圆角置顶按钮（28pt，悬停或已置顶时显示），网格在左上角、列表在右侧；点击置顶/取消置顶，置顶书始终排最前。
  - 列表行补充悬停状态，置顶按钮在列表里也能出现。
- 涉及文件：`Sources/LumaReader/ContentView.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户要求新增书库拖动排序并支持置顶。
- 验证：`build-macos.sh` 通过，生成 1.9.4（80）并安装；实机点击置顶按钮后书封移动到首位、按钮变为“取消置顶”，`luma.books.pinnedIDs` 持久化；取消后恢复。
- 未验证：真实鼠标拖拽未自动验证（无法注入拖放事件）；未重跑全量测试（本次仅 SwiftUI 视图改动，编译通过）。

## 2026-11-11 12:18:00 (-07:00) · 1.9.3 (79)
由 DeepSeek 更改 在 12:18:00，本次更新的安装包为 v1.9.3（build 79），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 听力三级树与云盘文件区的展开按钮统一为圆角大热区（30pt / 26pt），带悬停底色、旋转动画和“展开/折叠”无障碍标签；点击不再需要精确命中小箭头。
  - 听力分类分栏视图删除最右侧几乎空白的单词预览栏，三栏均分可用宽度；面包屑右侧新增“全部听写 (N)”按钮（根目录为全部单词，进入文件夹后为该文件夹）。
  - DictationSessionStateMachine：普通听写（newTask）答错订正后不再回到本轮队列，只记录错词；错词复习（wrongWordReview）保留 10/50/100/200 四轮循环。
  - 错词中心新增“全部错词听写 N”按钮与菜单项，把全部词库的错词合并为一个循环复习会话。
  - 词库数据恢复：把上次保存的剑20语料库 3,498 词（第3/4/5/11章）重新并入用户词库；同释义短语去重 33 个、保留美式删英式 2 个（color/colour、labor/labour）、单复数全部保留；现有 3,627 + 新增 3,498 - 删除 35 = 7,090 词。
  - 数据备份：`~/Library/Application Support/LumaReader/StudyCenter/backups/pre-vocab-restore-20261111-121356.json`。
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/WrongWordsCenter.swift`、`Deferred/StudyCenter/DictationEngine.swift`、`Deferred/StudyCenter/Tests/DictationAnswerRegressionTests.swift`、`Deferred/StudyCenter/Tests/StudyLearningRulesTests.swift`、`Sources/LumaReader/CloudFileManager.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户要求把所有展开按钮做成圆角大热区、删除听力分栏右侧空白栏并把“全部听写”放到面包屑、听写与错词听写彻底分开并支持全部错词听写，同时恢复之前 Excel 词表并深度去重。
- 验证：`swift build -c release` 与 `build-macos.sh` 通过并生成 1.9.3（79）；新增的 `testNormalDictationPassesOnceAndRecordsTheWrongWord` 与 `testWrongWordReviewStillRequeuesTenWordsLater` 通过；实机确认剑20四个词库（1,276/621/266/1,324）恢复、“全部听写 (7,090)”、“全部错词听写 7”、三栏布局与 30/26pt 展开按钮。
- 未验证：安装启动脚本端到端重装；全量 StudyCenter 测试仍有与 1.7.3 基线相同的既有失败；未逐主题截图。

## 2026-11-11 11:57:00 (-07:00) · 1.9.2 (78)
由 DeepSeek 更改 在 11:57:00，本次更新的安装包为 v1.9.2（build 78），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 修复 1.9.0 的编译错误：HeroImageStore 的 NSCache 加 @MainActor；对角渐隐遮罩改用单一 LinearGradient；VisualThemeBackdrop 把 heroRevision 改为普通 Int 传入 drawing，恢复 Equatable。
  - 输入框透明度现在只作用于底纹与描边，文字保持 100% 不透明；顶栏透明度只作用于顶栏底色，按钮与原生红黄绿保持清晰。
  - 阅读顶栏按钮大小改为等比缩放（宽、高、胶囊高度一致），并按可用宽度限制缩放；红黄绿与胶囊中心仍在 30pt 中线。
  - 主视觉设置：滑块实时预览（140ms 防抖保存）、缩略图、拖放导入、参数 clamped、导入/移除/重置即时反馈；缩略图读取使用公开的缓存接口。
  - 侧栏恢复固定在左侧，主题布局不再把它移到右边。
  - 阅读顶栏恢复 split 布局：左四键、右三键、书名居中，与红黄绿同一中线；主题布局不再改变阅读键排布。
- 涉及文件：`Sources/LumaReader/ContentView.swift`、`Sources/LumaReader/LumaThemeScope.swift`、`Sources/LumaReader/LumaPersonalizationView.swift`、`Deferred/StudyCenter/HeroImageOverride.swift`、`Deferred/StudyCenter/VisualThemeBackdrop.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户反馈 1.9.0 个性化设置（按钮大小/透明度）与“导入主题主视觉”需要检查修复，并要求主页功能键回到左侧、阅读七键恢复原位置与红黄绿中线。
- 验证：`swift build -c release` 与 `build-macos.sh` 通过并生成 1.9.2（78）；根测试 130 项 6 个既有环境性失败与基线一致；实机确认侧栏在左、阅读七键恢复左侧四键/右侧三键并与红黄绿同中线、主视觉可铺满背景、透明度/大小设置生效。
- 未验证：安装启动脚本端到端重装；全部 15 套主题逐主题截图；主视觉导入面板的完整鼠标流程（通过 defaults 注入图片验证渲染，导入按钮可打开面板）。

## 2026-11-10 22:24:00 (-07:00) · 1.7.3 (71)
由 DeepSeek 更改 在 22:24:00，本次更新的安装包为 v1.7.3（build 71），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 删除云盘页头部多余的“云盘总览”名称，页面标题直接使用“云盘”，与侧栏入口完全一致。
  - 侧栏保持单一“云盘”大按钮；帮助文字同步改为“打开云盘 · <连接状态>”，不再出现“云盘总览”字样。
  - 同时更新 /Applications 与 ~/Applications 两份安装副本到 1.7.3，避免 Dock 启动旧版。
- 涉及文件：`Sources/LumaReader/ContentView.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户认为“云盘总览”按钮多余，要求取消并合并到“云盘”。
- 验证：`build-macos.sh` 通过并生成 1.7.3（71），签名/安装后实机确认侧栏只剩“云盘”、页面标题为“云盘”、全 UI 无“云盘总览”字样。
- 未验证：安装启动脚本端到端重装；逐主题截图。

## 2026-11-10 22:20:00 (-07:00) · 1.7.2 (70)
由 DeepSeek 更改 在 22:20:00，本次更新的安装包为 v1.7.2（build 70），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 云盘总览移除不透明 paper 底色，页面改为透明以显示当前主题画布（Monet 纸面、Space 星空、Manga 网点等），与书库观感一致。
  - 云盘卡片与文件区改用 readerGlass 主题材质 + 读色 accent/ink/muted；删除系统 Table，改为同主题的自绘文件列表（名称/大小/修改时间）。
  - 三张云盘卡片统一等高、顶对齐，且“尚未选择目录”占位保证行数一致。
  - 侧栏删除 iCloud/OneDrive/Google Drive 三行，只保留一个 50pt 高的“云盘”大按钮（带连接状态圆点与同步中转圈），点按直接打开云盘总览。
  - 云盘卡片整张可点，弹出小窗完成：立即同步、在文件管理中浏览、更换同步目录…、断开、接入。
  - 云盘文件区新增伸缩：标题栏箭头折叠/展开；列表高度按窗口高度自适应（220–560pt）；卡片网格按宽度 3/2/1 列自适应；多连接时出现云盘切换器。
- 涉及文件：`Sources/LumaReader/ContentView.swift`、`Sources/LumaReader/CloudFileManager.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户要求云盘界面与现有多种主题统一、支持伸缩，并删除侧栏三个云盘行，改为点大按钮进入、点云盘卡片用小弹窗修改。
- 验证：`swift build -c release` 与 `build-macos.sh` 通过并生成 1.7.2（70），签名/校验后安装；`swift test` 126 项中 6 项失败与 1.7.0 基线一致（环境性）；实机确认侧栏只剩一个云盘大按钮、云盘页显示主题画布、三卡等高、卡片弹窗四项操作、文件区折叠/展开与主题化列表。
- 未验证：浅色/Manga/Space 主题的逐主题截图对比（本次逐项使用主题 Token，未切换全部主题实拍）；安装启动脚本端到端重装未执行。

## 2026-11-10 20:46:00 (-07:00) · 1.7.1 (69)
由 DeepSeek 更改 在 20:46:00，本次更新的安装包为 v1.7.1（build 69），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：docs
- 更新内容：
  - 补充 1.7.1 的实机 GUI 验证记录：真实点击目录箭头、全部展开、全部折叠均即时生效（点击到状态返回约 0.23 秒，含 osascript 启动时间）。
  - 打开目录后 AX 焦点为窗口而非“搜索目录标题”输入框，确认不再自动聚焦搜索框。
  - 目录面板打开期间顶部红黄绿与功能胶囊保持显示，未再出现整条顶栏消失/重现。
  - 云盘总览新布局截图确认：固定返回书库标题栏、三张合并后的云盘卡片、单行文件管理工具栏。
  - 在云盘总览点击“全部图书”立即回到书库，验证从云盘到书库的即时跳转。
- 涉及文件：`CHANGELOG.md`
- 原因：上一条 1.7.1 记录写作时实机 GUI 验收尚未开始，需按实际完成的检查更正记录。
- 验证：`swift build -c release`、`swift test`（126 项，新增 2 项目录行测试通过，6 项与 1.7.0 基线的环境性失败一致）、`release_guard.py pack/verify`、`release_guard.py app`、实机点击与截图。
- 未验证：安装启动脚本端到端重装（解压后完整重编译）、全屏与不同窗口尺寸下的视觉回归。

## 2026-11-10 20:40:00 (-07:00) · 1.7.1 (69)
由 DeepSeek 更改 在 20:40:00，本次更新的安装包为 v1.7.1（build 69），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 阅读目录改为扁平可见行渲染：展开/折叠只重建当前可见行，点击即时生效，不再递归重建整棵目录树。
  - 移除目录列表的隐式布局动画，仅保留箭头 0.12 秒旋转；全部展开/全部折叠在单一禁用动画事务中完成，消除整面板闪烁与跳动。
  - 打开目录时不再把光标自动放进搜索框：面板出现后清除一次初始第一响应者，点击搜索框才进入输入。
  - “当前位置 / 全部展开 / 全部折叠”改为 26pt 高胶囊按钮，扩大点击热区并加入悬停底色。
  - 目录、书签、笔记、搜索或设置面板打开期间保持顶部红黄绿与功能胶囊显示，鼠标移入目录不再让顶栏消失后再出现。
  - 云盘总览改为固定顶部栏（返回书库 + 标题 + 立即同步全部），删除四张统计卡、独立空状态与底部长篇说明，移除学习数据目录扫描。
  - 云盘卡片将“同步 / 目录 / 断开”合并为“同步 + ⋯菜单”，未连接只保留“连接…”；文件管理工具栏压缩为单行，底部操作合并为“打开 + ⋯菜单”。
  - 从云盘总览点击图书、分类、学习入口、云盘筛选行或打开图书时，立即关闭云盘总览回到书库。
- 涉及文件：`Sources/LumaReader/ReadingOutlineView.swift`、`Sources/LumaReader/ReadingOutline.swift`、`Sources/LumaReader/ContentView.swift`、`Sources/LumaReader/CloudFileManager.swift`、`Tests/LumaReaderTests/ReadingOutlineTests.swift`、`release.json`、`CHANGELOG.md`、`RELEASE_NOTES.md`
- 原因：用户要求优化阅读目录展开/折叠的响应与闪烁、打开目录不要自动聚焦搜索框、整理云盘布局（删除与合并）并让从云盘返回书库立即生效。
- 验证：`swift build -c release` 通过；`swift test` 126 项中新增的 2 项目录行测试通过，其余 6 项失败与 1.7.0 基线完全相同（窗口悬停与探针可执行文件的环境性失败）；`build-macos.sh` 生成 1.7.1（69）应用并通过 check-app-bundle，安装到 /Applications 后成功启动并渲染书库窗口。
- 未验证：真实指针下的目录展开/折叠、全部展开/折叠与云盘页面的逐项视觉对比（验收时屏幕被其他应用占用并锁定），因此未取得前后截图证据。

## 2026-11-10 15:21:40 (UTC-07:00) · 1.4.3 (64)
由 DeepSeek 更改 在 15:21:40，本次更新的安装包为 v1.4.3（build 64），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.4.3 (build 64)：自动同步时间/电源/网络/后台/低电量限制与用户开关
  - 源码 ZIP、Info.plist、启动器版本统一为 1.4.3/64
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求不要总是自动同步，并提供可选择的限制
- 验证：/Applications 版本 1.4.3 (64)；codesign 通过
- 未验证：电源/网络/低电量真实拦截未逐项实测

## 2026-11-10 15:18:06 (UTC-07:00) · 1.4.3 (64)
由 DeepSeek 更改 在 15:18:06，本次更新的安装包为 v1.4.3（build 64），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 自动同步增加开关、15/30/60/180 分钟间隔与仅手动；默认仅接通电源、需网络、后台不同步、低电量暂停
  - 手动同步不受限制；跳过时显示原因
- 涉及文件：`Sources/LumaReader/LibraryStore.swift`、`Sources/LumaReader/ContentView.swift`、`release.json`、`RELEASE_NOTES.md`
- 原因：用户要求不要总是自动同步，并按电源/网络/后台/低电量限制
- 验证：Debug 编译通过
- 未验证：电源/网络/低电量条件下的真实拦截未逐项实测

## 2026-11-10 15:12:36 (UTC-07:00) · 1.4.2 (63)
由 DeepSeek 更改 在 15:12:36，本次更新的安装包为 v1.4.2（build 63），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.4.2 (build 63)：云盘总览页
  - 源码 ZIP、Info.plist、启动器版本统一为 1.4.2/63
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求云盘专门界面
- 验证：/Applications 版本 1.4.2 (63)；codesign 通过
- 未验证：云盘总览实机交互未截图

## 2026-11-10 15:10:17 (UTC-07:00) · 1.4.2 (63)
由 DeepSeek 更改 在 15:10:17，本次更新的安装包为 v1.4.2（build 63），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 新增云盘总览页：连接数、图书/批注、学习数据大小、同步百分比、每盘状态与操作
  - 入口复用现有云盘分组，不新增工具栏按钮
- 涉及文件：`Sources/LumaReader/ContentView.swift`、`release.json`、`RELEASE_NOTES.md`
- 原因：用户要求为云盘设置专门界面
- 验证：Debug 编译通过
- 未验证：云盘总览真实交互与数据大小显示未实机截图

## 2026-11-10 15:07:10 (UTC-07:00) · 1.4.1 (62)
由 DeepSeek 更改 在 15:07:10，本次更新的安装包为 v1.4.1（build 62），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.4.1 (build 62)：作文 SQLite 单一长期副本，JSON 只做云快照/导出，失败回退 JSON
  - 源码 ZIP、Info.plist、启动器版本统一为 1.4.1/62
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求只保留一份 SQLite 数据，JSON 仅临时导出
- 验证：/Applications 版本 1.4.1 (62)；codesign 通过；2 个 SQLite 测试通过
- 未验证：真实写作保存/云同步往返未实机验证

## 2026-11-10 15:03:48 (UTC-07:00) · 1.4.1 (62)
由 DeepSeek 更改 在 15:03:48，本次更新的安装包为 v1.4.1（build 62），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：data
- 更新内容：
  - SQLite 作文单一长期副本；本机 JSON 不再保存草稿/提交；SQLite 失败回退 JSON
  - 新增 JSON 不重复保存作文测试，2 个 SQLite 测试通过
- 涉及文件：`Deferred/StudyCenter/StudyPersistence.swift`、`Deferred/StudyCenter/Tests/WritingArchiveTests.swift`、`RELEASE_NOTES.md`
- 原因：用户要求只保留一份 SQLite 数据，JSON 只做临时导出/云快照
- 验证：WritingArchiveTests 2/2 通过；Debug 编译通过
- 未验证：云同步往返、导出临时 JSON 未实机验证

## 2026-11-10 15:00:55 (UTC-07:00) · 1.4.1 (62)
由 DeepSeek 更改 在 15:00:55，本次更新的安装包为 v1.4.1（build 62），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：data
- 更新内容：
  - 作文草稿/提交写入本地 SQLite（WAL）；JSON 继续做导出/云快照；失败回退 JSON
  - 空库开始，不迁移旧作文；新增 SQLite 往返测试
- 涉及文件：`Deferred/StudyCenter/StudyPersistence.swift`、`Deferred/StudyCenter/Tests/WritingArchiveTests.swift`、`release.json`、`RELEASE_NOTES.md`
- 原因：用户确认可直接迁移且尚未开始写作文
- 验证：SQLite 往返测试通过；Debug 编译通过
- 未验证：真实写作保存/重启恢复未实机走完

## 2026-11-10 14:56:57 (UTC-07:00) · 1.4.0 (61)
由 DeepSeek 更改 在 14:56:57，本次更新的安装包为 v1.4.0（build 61），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.4.0 (build 61)：云盘同步百分比、移除 82M 模型、无效模型回退系统语音
  - 源码 ZIP、Info.plist、启动器版本统一为 1.4.0/61
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求同步百分比、删除 82M 模型并修复无效语音模型
- 验证：/Applications 版本 1.4.0 (61)；codesign 通过
- 未验证：同步中断百分比与模型缺失回退未实机验证

## 2026-11-10 14:54:24 (UTC-07:00) · 1.4.0 (61)
由 DeepSeek 更改 在 14:54:24，本次更新的安装包为 v1.4.0（build 61），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 设置云盘新增同步百分比、阶段与失败停点；100% 才代表完成
  - 移除 82M Kokoro 模型 UI，默认 Kitten Micro；旧配置自动迁移
  - 模型启动失败自动切换系统语音，不再假装就绪
- 涉及文件：`Sources/LumaReader/LibraryStore.swift`、`Sources/LumaReader/ContentView.swift`、`Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`、`release.json`、`RELEASE_NOTES.md`
- 原因：用户要求同步百分比、删除 82M 模型、修复无效语音模型，且优化不得影响日常使用
- 验证：Debug 全量编译通过
- 未验证：同步失败中断的百分比显示、模型缺失时的系统语音切换未实机验证

## 2026-11-10 14:27:09 (UTC-07:00) · 1.3.3 (60)
由 DeepSeek 更改 在 14:27:09，本次更新的安装包为 v1.3.3（build 60），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.3.3 (build 60)：词组空格/-/_ 宽松判定
  - 源码 ZIP、Info.plist、启动器版本统一为 1.3.3/60
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求词组/固定搭配只要字母正确就算对
- 验证：/Applications 版本 1.3.3 (60)；codesign 通过；7 个听写回归测试通过
- 未验证：真实长词组与 IME 输入未实机验证

## 2026-11-10 14:24:47 (UTC-07:00) · 1.3.3 (60)
由 DeepSeek 更改 在 14:24:47，本次更新的安装包为 v1.3.3（build 60），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 词组判定宽松：空格、-、_ 视为同一分隔符，只比较字母；单词中间不允许空格
  - 新增 2 个回归测试，听写测试共 7 个全部通过
- 涉及文件：`Deferred/StudyCenter/DictationEngine.swift`、`Deferred/StudyCenter/Tests/DictationAnswerRegressionTests.swift`、`release.json`、`RELEASE_NOTES.md`
- 原因：用户要求词组/固定搭配多打少打空格或 -_ 不判错，只要字母正确
- 验证：7 个回归测试通过（含空格/连字符/下划线/无分隔符/字母错误）
- 未验证：真实 IME 与长词组输入未实机验证

## 2026-11-10 14:08:05 (UTC-07:00) · 1.3.2 (58)
由 DeepSeek 更改 在 14:08:05，本次更新的安装包为 v1.3.2（build 58），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.3.2 (build 58)：错词 +10/+50/+100/+200 四轮复现，答对推进，全角/零宽归一化
  - 源码 ZIP、Info.plist、启动器版本统一为 1.3.2/58
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求修正听写判错与重复问题，并指定 10/50/100/200 复现频率
- 验证：/Applications 版本 1.3.2 (58)；codesign 通过；5 个听写回归测试通过
- 未验证：真实 200+ 词长会话与 IME 输入未实机跑完

## 2026-11-10 14:02:12 (UTC-07:00) · 1.3.2 (58)
由 DeepSeek 更改 在 14:02:12，本次更新的安装包为 v1.3.2（build 58），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 错词复现间隔改为 +10 / +50 / +100 / +200，共 4 轮；答对后当前词前进，错词按间隔再来
  - 保留全角/零宽归一化修复
- 涉及文件：`Deferred/StudyCenter/DictationEngine.swift`、`Deferred/StudyCenter/Tests/DictationAnswerRegressionTests.swift`、`RELEASE_NOTES.md`
- 原因：用户要求写错的词按 10/50/100/200 的频率复现四次
- 验证：5 个回归测试通过：全角、零宽、首次答对推进、错后答对第10位复现、间隔常量
- 未验证：真实 200+ 词长会话未实机跑完

## 2026-11-10 14:02:04 (UTC-07:00) · 1.3.2 (58)
由 DeepSeek 更改 在 14:02:04，本次更新的安装包为 v1.3.2（build 58），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 错词复现间隔改为 +10 / +50 / +100 / +200，共 4 轮；答对后当前词前进，错词按间隔再来
  - 保留全角/零宽归一化修复
- 涉及文件：`Deferred/StudyCenter/DictationEngine.swift`、`Deferred/StudyCenter/Tests/DictationAnswerRegressionTests.swift`、`RELEASE_NOTES.md`
- 原因：用户要求写错的词按 10/50/100/200 的频率复现四次
- 验证：5 个回归测试通过：全角、零宽、首次答对推进、错后答对第10位复现、间隔常量
- 未验证：真实 200+ 词长会话未实机跑完

## 2026-11-10 13:59:03 (UTC-07:00) · 1.3.2 (58)
由 DeepSeek 更改 在 13:59:03，本次更新的安装包为 v1.3.2（build 58），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 普通听写答对后立即推进到下一词并计入完成数，不再重复同一词
  - 归一化全角/零宽字符，修复看似正确却判错
  - 四轮错词循环仅保留在错词复习模式
- 涉及文件：`Deferred/StudyCenter/DictationEngine.swift`、`Deferred/StudyCenter/Tests/DictationAnswerRegressionTests.swift`、`release.json`、`RELEASE_NOTES.md`
- 原因：用户反馈答对仍显示错误、进度不跳动、反复听同一词
- 验证：StudyCenter 4 个回归测试全部通过（全角、零宽、答对推进、先错后对推进）
- 未验证：真实 IME 输入与 206 词完整会话未实机跑完

## 2026-11-10 20:04:42 (UTC) · 1.3.1 (57)
由 DeepSeek 更改 在 20:04:42，本次更新的安装包为 v1.3.1（build 57），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 为《尼尔：机械纪元》新增完整标志性场景插画：寄叶部队双翼剑徽、2B与白之契约太刀/Pod 042剪影、废墟都市与巨型机械生命体（Engels）及月之泪花朵
  - 为《塞尔达传说》新增完整标志性场景插画：真实结构希卡之眼（三睫毛+泪滴）、海拉鲁王室双翼三角神力、石座大师之剑（退魔之剑）、静谧公主花丛与双子山剪影
  - 为大海/城市/森林清新漫画及原有 6 款日漫主题（新海诚双轨彗星与踏切、千与千寻白龙与油屋汤屋、镰仓红日富士山、晨曦盛放樱枝、京都八坂五重塔、抹茶茶室圆窗修竹）全面升级多层次场景插画
  - 在主题画廊缩略卡、设置面板宽幅插画预览横幅及学习中心根背景全面启用 Metal 离屏缓存（drawingGroup）插画渲染，提升版本至 v1.3.1 (build 57)
- 涉及文件：`Deferred/StudyCenter/VisualThemeBackdrop.swift`、`Deferred/StudyCenter/StudyHome.swift`、`Sources/LumaReader/LumaIndependentThemes.swift`、`Sources/LumaReader/CustomizationPanel.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户上传尼尔机械纪元原画参考，要求为尼尔、塞尔达及所有动漫/漫画主题补充具有高辨识度特征的场景与角色/徽章插画
- 验证：check-ui-resources.py PASS；release_guard.py check 受保护基线字节级一致 PASS；release_guard.py pack & verify PASS
- 未验证：当前环境非 macOS，原生 Xcode/Swift 编译与实机 GUI 视觉呈现待在 Mac 上执行安装验证

## 2026-11-10 19:40:48 (UTC) · 1.3.0 (56)
由 DeepSeek 更改 在 19:40:48，本次更新的安装包为 v1.3.0（build 56），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 升级「Manga · 多元漫画原稿」，新增经典黑白原稿、大海清新漫、城市清新漫、森林清新漫 4 套分镜画风与对角速度线特效
  - 新增 3 款独立清新漫画主题：「海风漫绘 · Ocean Manga」（Kanagawa海盐分镜/海浪星芒）、「都市漫绘 · City Pop Manga」（Tokyo Night霓虹双阴影/天际线电线杆）、「森之漫绘 · Forest Manga」（Everforest木漏日树冠/萤光孢子）
  - 新增 2 款殿堂级游戏主题：「尼尔机械纪元 · YoRHa UI」（寄叶米灰/2B暗夜/逻辑病毒绯红、左侧重型战术边条、CRT扫描线与几何雷达环）與「塞尔达传说 · Sheikah & Hyrule UI」（希卡之石夜光蓝/左纳乌翠金/王室羊皮卷、4px/2px双层角框、三角神力与精力轮）
  - 为全部新增主题补齐专属卡片物理材质、静态背景 Canvas 特效、听写错误动效及 AI 面板 CSS 作用域样式，并提升版本至 v1.3.0 (build 56)
- 涉及文件：`Sources/LumaReader/LumaIndependentThemes.swift`、`Sources/LumaReader/MonetLiquidGlass.swift`、`Sources/LumaReader/LumaThemeScope.swift`、`Sources/LumaReader/LibraryStore.swift`、`Sources/LumaReader/ContentView.swift`、`Sources/LumaReader/StudyCenterScreen.swift`、`Sources/LumaReader/Resources/AIChat.css`、`Deferred/StudyCenter/VisualThemeBackdrop.swift`、`Deferred/StudyCenter/DictationThemeErrorAccent.swift`、`Tests/LumaReaderTests/IndependentThemeTests.swift`、`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求按照 Code_Update_Safeguard_V3.5 规范深度优化漫画主题（增加大海/城市/森林清新漫画风）并新增《尼尔：机械纪元》与《塞尔达传说》游戏主题及专属独特视觉特效
- 验证：check-ui-resources.py PASS；release_guard.py check 受保护基线字节级一致 PASS；test_release_guard.py 20/20 PASS；release_guard.py pack & verify PASS
- 未验证：当前环境非 macOS，原生 Xcode/Swift 编译、应用安装及实机 GUI 渲染待在 Mac 上执行启动器验证

## 2026-11-10 12:13:53 (UTC-07:00) · 1.2.5 (55)
由 DeepSeek 更改 在 12:13:53，本次更新的安装包为 v1.2.5（build 55），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.2.5 (build 55)：写作工具栏下移，避开 traffic lights
  - 源码 ZIP、Info.plist、启动器版本统一为 1.2.5/55
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户反馈写作工具栏与红黄绿按钮冲突
- 验证：/Applications 版本 1.2.5 (55)；codesign 通过；Debug 截图确认间距
- 未验证：不同窗口尺寸下未逐一检查

## 2026-11-10 12:10:33 (UTC-07:00) · 1.2.5 (55)
由 DeepSeek 更改 在 12:10:33，本次更新的安装包为 v1.2.5（build 55），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 考试/自由写作工具栏顶部留白 36→44，整体下移避开红黄绿
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`release.json`、`RELEASE_NOTES.md`
- 原因：用户反馈工具栏与 Apple traffic light 冲突
- 验证：Debug 截图确认工具栏下移，返回胶囊与红黄绿之间有间距
- 未验证：不同窗口尺寸下未逐一检查

## 2026-11-10 12:06:33 (UTC-07:00) · 1.2.4 (54)
由 DeepSeek 更改 在 12:06:33，本次更新的安装包为 v1.2.4（build 54），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.2.4 (build 54)：写作工具栏上移、更多按钮并入、字号滑动条、确认框等宽
  - 源码 ZIP、Info.plist、启动器版本统一为 1.2.4/54
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求精简写作页并统一确认框按钮
- 验证：/Applications 版本 1.2.4 (54)；codesign 通过；自由写作布局截图确认
- 未验证：Task 1 暂停状态与滑动条拖动未逐项实测

## 2026-11-10 12:03:09 (UTC-07:00) · 1.2.4 (54)
由 DeepSeek 更改 在 12:03:09，本次更新的安装包为 v1.2.4（build 54），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 移除暂停提示小字；写作工具栏上移，... 移到 AI 助手左侧
  - 题目字号改为滑动条 12–30pt
  - 离开写作确认框三个按钮统一等宽
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`、`Deferred/StudyCenter/StudyPromptView.swift`、`release.json`
- 原因：用户要求精简写作页、移动更多按钮、字号滑动调节、统一确认框按钮
- 验证：Debug 编译通过；自由写作界面截图确认工具栏上移、... 位于 AI 左侧、无暂停小字、三按钮等宽
- 未验证：Task 1 暂停状态的实机视觉与滑动条拖动未逐项实测

## 2026-11-10 11:54:40 (UTC-07:00) · 1.2.3 (53)
由 DeepSeek 更改 在 11:54:40，本次更新的安装包为 v1.2.3（build 53），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.2.3 (build 53)：模拟考试独立界面、自由写作、写作布局精简、阅读器独立主题
  - 源码 ZIP、Info.plist、启动器版本统一为 1.2.3/53
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求模拟考试不直接开始、新增自由写作、精简写作页并统一/独立阅读器主题
- 验证：/Applications 版本 1.2.3 (53)；codesign 通过；模拟考试设置页与自由写作页已实机截图
- 未验证：完整两篇模拟考试交卷与阅读器独立主题切换未逐项实测

## 2026-11-10 11:50:47 (UTC-07:00) · 1.2.3 (53)
由 DeepSeek 更改 在 11:50:47，本次更新的安装包为 v1.2.3（build 53），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - Task 2 页右侧下拉改为独立「模拟考试」界面：自选 Task 1 + Task 2，60 分钟两篇
  - 新增无题目自由写作（收进更多菜单），全宽编辑可交卷
  - 写作编辑页移除多余 Task 1/2 按钮与正在练习小字；重新开始移入菜单
  - 修复保存并退出按钮颜色，阅读器新增跟随/独立主题
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`、`Sources/LumaReader/LibraryStore.swift`、`Sources/LumaReader/ReaderController.swift`、`Sources/LumaReader/ContentView.swift`、`release.json`
- 原因：用户要求模拟考试独立界面、自由写作、精简写作布局、阅读器主题统一且可独立
- 验证：Debug 全量编译通过；模拟考试设置界面与自由写作界面已实机截图
- 未验证：模拟考试完整两篇作答与阅读器独立主题的实机切换未逐项验证

## 2026-11-10 11:36:51 (UTC-07:00) · 1.2.2 (52)
由 DeepSeek 更改 在 11:36:51，本次更新的安装包为 v1.2.2（build 52），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.2.2 (build 52)：后台降载、关闭窗口退出、退出前落盘与内存回收
  - 源码 ZIP、Info.plist、启动器版本统一为 1.2.2/52
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求限制后台运行、切回可继续、强制退出不丢数据
- 验证：/Applications 版本 1.2.2 (52)；codesign 通过；前台 footprint 169MB，切后台 RSS 260MB→219MB、CPU 0%，store 已落盘
- 未验证：SIGKILL 强制退出无法拦截；真实强制退出丢失窗口未实测

## 2026-11-10 11:33:09 (UTC-07:00) · 1.2.2 (52)
由 DeepSeek 更改 在 11:33:09，本次更新的安装包为 v1.2.2（build 52），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 关闭最后一个窗口即退出，减少后台驻留
  - 失焦时暂停听写/计时/语音、立即落盘、清空封面与调色板缓存并归还空闲内存页；回到前台继续原状态
  - 强制退出采用持续自动保存策略（输入 0.8s 落盘，正常退出强制 flush）
- 涉及文件：`Sources/LumaReader/LumaReaderApp.swift`、`Sources/LumaReader/ContentView.swift`、`RELEASE_NOTES.md`、`release.json`、`CHANGELOG.md`
- 原因：用户要求限制后台运行、切回可继续、强制退出不丢数据，并优先使用磁盘而不是内存
- 验证：Debug 全量编译通过；已有 willResignActive/willTerminate flush 链路复用
- 未验证：强制退出（SIGKILL）无法拦截，实际丢失窗口与内存下降幅度未仪器化测量

## 2026-11-10 11:28:30 (UTC-07:00) · 1.2.1 (51)
由 DeepSeek 更改 在 11:28:30，本次更新的安装包为 v1.2.1（build 51），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.2.1 (build 51)：主题画廊筛选保持、瞬时切换、轻量缩略图与调色板复用
  - 源码 ZIP、Info.plist、启动器版本统一为 1.2.1/51
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求切换主题后不跳回全部主题，并优化切换性能
- 验证：/Applications 版本 1.2.1 (51)；codesign 通过；Debug 实机截图显示日漫小清新筛选在 shinkai 主题下保持
- 未验证：真实鼠标连续切换主题的帧率未仪器化测量

## 2026-11-10 11:23:22 (UTC-07:00) · 1.2.1 (51)
由 DeepSeek 更改 在 11:23:22，本次更新的安装包为 v1.2.1（build 51），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 主题画廊筛选持久化：切换主题后保持原分类，不再跳回全部主题
  - 主题切换改为瞬时事务，移除弹簧动画，消除闪动
  - 8 个实时 Canvas 预览改为轻量静态缩略图；调色板每帧只计算一次
- 涉及文件：`Sources/LumaReader/LumaIndependentThemes.swift`、`RELEASE_NOTES.md`、`release.json`、`CHANGELOG.md`
- 原因：用户反馈切换主题时会闪一下并跳到全部主题，且切换性能有优化空间
- 验证：Debug 全量编译通过
- 未验证：主题切换帧率与真实鼠标点击未仪器化验证

## 2026-11-10 18:09:29 (UTC) · 1.2.0 (50)
由 DeepSeek 更改 在 18:09:29，本次更新的安装包为 v1.2.0（build 50），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 优先在 Skills 库创建并升级 anime-fresh-themes Skill，收录包含《千与千寻》在内的 6 款日漫小清新主题设计体系与 Scale 画廊规范
  - 新增 6 款绝不重复的日漫小清新独立主题世界：晴空夏影（Shinkai Sky）、千与千寻（Spirited Away：琥珀川白龙碧玉/油屋红桥提灯/海上列车铁轨/煤球精灵与金平糖错误反馈）、镰仓海风（Kanagawa Lotus）、晨曦白桃（Rosé Pine Dawn）、京都提灯（Akari Dawn）、抹茶白玉（Matcha Latte），总计 9 大独立主题世界 + 5 款经典主题
  - 为每款日漫小清新主题提供原生纯粹非玻璃材质（赛璐璐硬边、油屋朱金双框、浮世绘直角双线、手账缝线、提灯顶光、白瓷釉边），并新增两个独立用户开关：可自由选择是否融入液态玻璃半透明或当前书籍封面 Monet 强调色
  - 按 Scale 标准重构设置与外观工作台的「视觉主题画廊（Scale 矩阵）」：提供顶部分类筛选栏（全部主题 9 / 日漫小清新 6 / 科幻与漫画 2 / 莫奈与经典 1）、自适应 Bento 实时微缩画布卡片网格与按需折叠的参数检查器
- 涉及文件：`Sources/LumaReader/LumaIndependentThemes.swift`、`Sources/LumaReader/MonetLiquidGlass.swift`、`Sources/LumaReader/LumaThemeScope.swift`、`Sources/LumaReader/LibraryStore.swift`、`Sources/LumaReader/StudyCenterScreen.swift`、`Sources/LumaReader/ContentView.swift`、`Sources/LumaReader/CustomizationPanel.swift`、`Sources/LumaReader/BookMonetFooter.swift`、`Sources/LumaReader/Resources/AIChat.css`、`Deferred/StudyCenter/VisualThemeBackdrop.swift`、`Deferred/StudyCenter/DictationThemeErrorAccent.swift`、`release.json`、`CHANGELOG.md`
- 原因：用户要求优先从 skills 学习并加入千与千寻等全部 6 款日漫小清新主题，要求每个主题各有特色绝不重复，提供是否融入莫奈与玻璃的自由开关，并按 Scale 标准重构设置中的主题排列界面
- 验证：check-ui-resources.py 静态校验通过；release_guard.py pack & verify 完整性、权限与 SHA-256 校验通过；Swift 括号与语法静态检查通过
- 未验证：macOS 实机编译与 GUI 视觉切换待用户在 Mac 终端执行一键命令验证

## 2026-11-10 10:42:31 (UTC-07:00) · 1.1.3 (49)
由 DeepSeek 更改 在 10:42:31，本次更新的安装包为 v1.1.3（build 49），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：config
- 更新内容：
  - 变更日志改为固定句式：由 DeepSeek 更改 在 HH:mm:ss，本次更新的安装包为 vX.Y.Z（build N），更新的内容如下
  - skill 升级 V3.5，并重新格式化项目历史日志
- 涉及文件：`~/.dsh/skills/code-update-safeguard-v3/SKILL.md`、`~/.dsh/skills/code-update-safeguard-v3/scripts/changelog.py`、`CHANGELOG.md`、`release.json`
- 原因：用户要求每次更新都总结谁、何时、安装包版本和更新内容
- 验证：changelog.py 输出符合指定句式；历史条目已转换
- 未验证：v1.1.3 安装包待重新构建

## 2026-11-10 10:38:08 (UTC-07:00) · 1.1.2 (48)
由 DeepSeek 更改 在 10:38:08，本次更新的安装包为 v1.1.2（build 48），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 重新构建并安装 v1.1.2 (build 48)：包含版本化交付规则、变更日志、安装器修复、4,320 词词库
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：按新规则，每次更改后输出全新的 vX.Y.Z 安装包
- 验证：/Applications 版本 1.1.2 (48)；codesign --verify --deep --strict 通过；源码 ZIP 重新生成
- 未验证：无
## 2026-11-10 10:36:53 (UTC-07:00) · 1.1.2 (48)
由 DeepSeek 更改 在 10:36:53，本次更新的安装包为 v1.1.2（build 48），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：config
- 更新内容：
  - skill 升级 V3.4：每次更改必须提升版本号并重新构建安装包，交付必须写明“更改后的安装包为 vX.Y.Z (build N)”
  - 本次按新规则升级到 v1.1.2 (build 48)
- 涉及文件：`~/.dsh/skills/code-update-safeguard-v3/SKILL.md`、`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求以后的每次更改都记录到 skill，并输出新的 vX.Y.Z 安装包
- 验证：skill 已同步到用户与项目目录并生成 V3.4 ZIP；版本已改为 1.1.2/48
- 未验证：安装包重新构建与安装待执行
## 2026-11-10 10:36:02 (UTC-07:00) · 1.1.1 (47)
由 DeepSeek 更改 在 10:36:02，本次更新的安装包为 v1.1.1（build 47），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 版本升级 1.1.1 (47)：变更日志规范、安装器文件提供器修复、括号拆分后的 4,320 词词库
  - 重新构建并安装到 /Applications 与 ~/Applications，生成 1.1.1 源码包
- 涉及文件：`release.json`、`RELEASE_NOTES.md`、`CHANGELOG.md`
- 原因：用户要求安装包使用 1.1.1，并把变更记录纳入交付
- 验证：Release 构建成功；/Applications 版本 1.1.1 (47)；codesign --verify --deep --strict 通过
- 未验证：无
## 2026-11-10 10:34:41 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 10:34:41，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：config
- 更新内容：
  - 变更日志规范升级：每条必须写明“由 DeepSeek 在 HH:mm:ss 更改，更改内容如下”，并记录执行者、精确到秒的时间、类型、内容、文件、原因、验证、未验证
  - skill 升级为 V3.3，新增 scripts/changelog.py 统一生成记录
- 涉及文件：`~/.dsh/skills/code-update-safeguard-v3/SKILL.md`、`~/.dsh/skills/code-update-safeguard-v3/scripts/changelog.py`、`CHANGELOG.md`
- 原因：用户要求每次改动都能查到谁、何时、改了什么，并写入 skill
- 验证：changelog.py 可生成标准条目；skill 文本已更新
- 未验证：无
## 2026-11-10 10:33:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 10:33:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：docs
- 更新内容：
  - 建立项目 CHANGELOG.md 并纳入源码 ZIP 必需文件；交付说明引用最新记录
- 涉及文件：`CHANGELOG.md`、`release.json`、`deliverables-1.1.0/交付说明.md`
- 原因：用户要求记录每次改动的执行者、时间、内容
- 验证：release_guard 打包后校验包含 CHANGELOG.md
- 未验证：无
## 2026-11-10 10:31:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 10:31:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：data
- 更新内容：
  - 括号组内两个词互相豁免长短语删除，避免 confidence/road 被同组短语再次删掉
  - 最终词库 4,320 词 / 17 词库；长短语规则删除 525 词
- 涉及文件：`vocab-replace-1.1.0/build_pack.py`、`vocab-replace-1.1.0/listening_pack.csv`、`vocab-replace-1.1.0/phrase_pruned.csv`
- 原因：保证括号拆分后的两个词都保留
- 验证：store 4,320 词；piano、pianist、confidence、road 均存在；7 份数据副本已更新
- 未验证：无
## 2026-11-10 10:29:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 10:29:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：data
- 更新内容：
  - 英文括号拆成两个词条：piano (pianist) → piano + pianist；ATM、maintenance、confidence、road 等同理
  - 专有名词短语（Church Road）不再删除通用词 road
- 涉及文件：`vocab-replace-1.1.0/build_pack.py`、`vocab-replace-1.1.0/listening_pack.json`
- 原因：用户要求带括号的内容按两个不同单词处理
- 验证：词库 4,318 词；piano/pianist、ATM/automatic teller machine 均存在
- 未验证：无
## 2026-11-10 10:18:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 10:18:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：release
- 更新内容：
  - 修复 ~/Applications 文件提供器附加属性导致安装中止：ditto --norsrc --noextattr，副本校验失败时继续安装 /Applications
- 涉及文件：`Install.command`、`Install-LumaReader.command`、`Σ╕ÇΘö«τ╝ûΦ»æσ╣╢σ«ëΦúàLumaReader.command`
- 原因：首次运行 Install.command 在 ~/Applications 校验阶段失败
- 验证：Install.command 退出码 0；/Applications 与 ~/Applications 签名校验通过
- 未验证：无
## 2026-11-10 10:12:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 10:12:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：data
- 更新内容：
  - 旧听力词库 7,509 条全部删除，替换为指定 docx + c20 CSV
  - 深度去重、统一英式拼写、按长短语规则删除被覆盖单词
  - 清理旧错词/慢反应/顽固词/未完成听写会话；保留历史听写记录
  - 本机与 iCloud/OneDrive/Google Drive 共 7 份数据副本同步
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`vocab-replace-1.1.0/build_pack.py`、`vocab-replace-1.1.0/apply_pack.py`、`~/Library/Application Support/LumaReader/StudyCenter/luma_study_store.json`
- 原因：用户要求原听力全部删除并由两份文件覆盖
- 验证：迁移后 4,292 词/17 词库；旧 Cora 词条为 0；应用重启未重新播种
- 未验证：无
## 2026-11-10 10:05:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 10:05:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 分类网格删除整页单词明细表
  - 文件夹拖动改为可连续解析的移动规则，源位置消失
  - 新增 30 个学习/系统主题文件夹图标，名称自动推荐、可更换
  - 图标底色跟随主题与莫奈取色
  - 查看单词改为 720×560 紧凑弹窗
- 涉及文件：`Deferred/StudyCenter/StudyHome.swift`、`Deferred/StudyCenter/Tests/FinderPathResolutionTests.swift`
- 原因：用户要求删除长表、修复拖动后不消失、提供多图标选择、主题色统一、查看单词小弹窗
- 验证：Debug 实机截图；7/7 路径解析单元测试通过；Release 编译通过
- 未验证：真实鼠标拖拽未自动验证（未授予辅助功能权限）
## 2026-11-10 09:52:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 09:52:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：code
- 更新内容：
  - 设置按当前任务打开（听力/写作/阅读）；设置分类细化为 9 类，听力与语音拆成听力与听写、语音与发音
- 涉及文件：`Sources/LumaReader/ContentView.swift`
- 原因：用户要求从听力页打开时优先听力设置，并重新细分设置分类
- 验证：Debug 实机截图：听力页打开直达听力与听写；编译通过
- 未验证：无
## 2026-11-10 09:45:00 (UTC-07:00) · 1.1.0 (46)
由 DeepSeek 更改 在 09:45:00，本次更新的安装包为 v1.1.0（build 46），更新的内容如下：
- 执行者：DeepSeek（运行于 DSH agent · deepseek-flash）
- 类型：config
- 更新内容：
  - 安装 code-update-safeguard-v3 skill（V3.2 → V3.3），加入强制变更日志规范与 scripts/changelog.py
- 涉及文件：`~/.dsh/skills/code-update-safeguard-v3/SKILL.md`、`~/.dsh/skills/code-update-safeguard-v3/scripts/changelog.py`
- 原因：用户要求把每次改动的执行者、时间、内容、文件写入 skill
- 验证：skill 已进入本会话目录并成功调用
- 未验证：无