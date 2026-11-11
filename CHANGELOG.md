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