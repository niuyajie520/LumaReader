# Luma Reader · iPhone 版

只保留三块：**听写**、**阅读**、**词库（阅读生词）**，加上 **云同步**。
写作、AI 对话、星漫、统计诊断、IELTS 批改全部不进来。

## 打开与安装

1. 双击 `iOS/LumaReaderIOS.xcodeproj`，Xcode 会打开 `LumaReader` 这个 app target。
2. 选中工程 → target `LumaReader` → **Signing & Capabilities**：
   - Team 选你自己的 Apple ID（勾选 Automatically manage signing）；
   - 如果 bundle id `app.luma.reader.ios` 被占用，改成 `app.luma.reader.ios.<你的名字>`。
3. 手机用数据线连 Mac（或同一 Wi-Fi 的无线调试），在 Xcode 顶部选中你的 iPhone → 点运行。
4. 首次运行时手机会提示「不受信任的开发者」：设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID。
   （免费 Apple ID 签的包 7 天过期，重新点一次运行即可续期。）

命令行验证（不需要签名）：

```bash
cd iOS
python3 generate_project.py                        # 新增 Swift 文件后重跑，重新生成 pbxproj

# 1. 设备构建（arm64，不签名）
xcodebuild -project LumaReaderIOS.xcodeproj -scheme LumaReader \
           -sdk iphoneos -configuration Debug \
           CODE_SIGNING_ALLOWED=NO build

# 2. 在模拟器上跑 UI 回归（真的点、真的打字、真的导入书）
xcrun simctl boot "iPhone 17" || true
xcodebuild test -project LumaReaderIOS.xcodeproj -scheme LumaReader \
                -destination 'platform=iOS Simulator,name=iPhone 17' \
                CODE_SIGNING_ALLOWED=NO
```

`iOS/LumaReaderIOSUITests/LumaReaderSmokeTests.swift` 里 6 个用例覆盖：四个 Tab、词库列表、听写一轮（打错 → 立刻跳下一个词并留下正确答案 → 看答案 → 队列继续）、设置页云同步分区、EPUB 导入后左右翻页与点词查词、以及四张界面截图。

## 共享内核与出包

判题、四档词距、错词插回、复习间隔、云同步合并都在 `../Packages/LumaCore`（纯 Foundation），
本工程通过 `XCLocalSwiftPackageReference` 链接它，`Core/LumaCoreBridge.swift` 只有一行
`@_exported import LumaCore`。所以改听写规则只需改内核一处，macOS 与 iPhone 同时生效；
`spec/behaviour.json` 是给将来 Android 的验收清单。

一条命令出包（从仓库根目录）：

```bash
bash Scripts/release.sh --target ios            # 生成工程 → Release 编译 → 打源码包
bash Scripts/release.sh --target ios --test     # 额外跑上面那 6 个 UI 用例
bash Scripts/release.sh --target macos|both     # 另一个平台 / 两个平台
```

版本号只改根目录的 `version.json`，脚本会把它同步进 `release.json` 与本工程的
`CURRENT_PROJECT_VERSION` / `MARKETING_VERSION`；`python3 Scripts/sync-version.py --check` 可检查漂移。

## 四个 Tab

**听写**：一屏一个词，听 → 打 → 当场订正。
- 两种策略：「快速过词」（错的隔 10 个词回来）与「循环复习」（5 / 55 / 155 / 255 个词距的四档阶梯，第四档拼对才毕业）。
- 范围：到期优先、只练到期、按顺序过一遍、只练做错的词。
- 5 个词以上的长措辞：首次只差冠词/介词这类虚词时只标一次、重拼一遍即可，不计错；实词错照常计错。
- 一个词错到 3 次挪到本轮最后单独练；当天看答案后的订正不算掌握，第二天才会排进到期词。

**阅读**：导入 EPUB / TXT / HTML（也可以直接在「文件」里选一整个文件夹，会把夹里的书一次导入）→ 分章看书；**点一下单词**就弹出释义（内置 6063 条阅读词表），可一键加进「阅读生词本」，明天就出现在听写里。**一屏就是一页**：点左右边缘 48pt 的窄条翻页（底栏同时显示「第 1/3 章 · 2/5 页」），翻到本章头尾自动切章；阅读时底部 TabBar 收起，正文更宽、更接近纸书。

**词库**：按词本浏览、搜索、看每个词的复习档位与下次复习时间；导入 JSON 词表或一行一个词的 TXT。

**设置**：朗读口音/语速/重复遍数、云同步文件夹、导入 Mac 学习数据、立即保存。

## 阅读分页是怎么做的

`Reader.js` 原本是给 macOS 窗口写的：它靠 CSS 多栏（`column-count`）横向分栏来实现「翻页」。
手机上屏宽只有一列，超出视口的内容既不分栏也不产生横向滚动宽度，于是永远算成 1 页、后面的字被静默裁掉
（这也是早期版本「长章节只显示到屏幕底部就断掉」的原因）。

iPhone 版改成自己分页（`Features/Reader/ReaderViews.swift` 里的 `Coordinator.iosPagerScript`）：

- 按 `innerHeight` 与正文 `lineHeight` 算出每页能放几整行：`step = floor(available / lineHeight) * lineHeight`；
- 把 `body` 高度设成正好 `step`，正文用 `translate3d(0, -页码 * step, 0)` 整页位移（180ms 缓动），
  所以页与页之间不会露出半行字；页底再压一条 6px 纸色遮罩，盖住跨页处那半个字的字头；
- `body` 的内边距归零（`Reader.css` 里给 macOS 的 `48px 44px 100px` 在手机上会把正文右移并裁掉右边），
  `#luma-content` 的宽度与左右留白由脚本按 `window.innerWidth` 显式设定，旋转屏幕或改字号都会重新排版；
- `window.Luma.turn(delta)` 被接管：翻到本章第一页/最后一页时返回 `false`，由 Swift 侧切到上一章/下一章。

## 云同步怎么用

1. 在「文件」App 的 iCloud 云盘里建一个文件夹，比如 `LumaReader`。
2. App → 设置 → 云同步 → 选择 iCloud 文件夹 → 选中它。
3. 以后每台设备点「立即同步」：各自写 `device-<设备>.json`，同步时把别的设备文件合并进来（词条按 id 取并集、复习进度取更靠后的一次、听写日志按 id 去重），所以两台机同时练也不会互相覆盖。
4. 从 Mac 迁过来：Mac 上 `~/Library/Application Support/LumaReader/StudyCenter/luma_study_store.json` 传到手机，设置 → 学习数据 → 导入 Mac 的学习数据。之后两台机的词库与进度就能对上。

## 数据文件

所有学习数据在 `Documents/StudyCenter/luma_study_store.json`，与 macOS 版同一套字段
（`importedWords`、`reviewSchedule`、`dictationLogs`、`stubbornWords`…）。
App 只覆盖自己管理的键，Mac 独有的字段（写作、AI、星漫）原样保留，来回同步不丢数据。
「文件」App 里可以看到这个文件（Info.plist 开了文件共享）。

## 朗读为什么是系统语音

macOS 版那套 Kitten TTS（15M 参数的 nano / micro 版 ONNX）依赖上位机的 Python 守护进程做音素化和推理，
iOS 上没有对应的运行时，硬搬会带来 40 MB 模型 + ONNX Runtime + espeak 音素表三件套。
这一版先用系统的英语语音（离线、免下载、随系统更新）；要接回 nano 模型需要单独做一层
onnxruntime-swift + 音素前端，属于下一步的事，不影响听写与阅读的其它功能。

## 目录

```
iOS/
├── LumaReaderIOS.xcodeproj/          # Xcode 工程（pbxproj 由脚本生成）
├── generate_project.py               # 生成 pbxproj，新增文件后重跑
└── LumaReaderIOS/
    ├── App/                          # 入口、Tab、主题与按钮样式
    ├── Core/                         # 数据模型、仓库、听写状态机、朗读、云同步
    ├── Features/Dictation/           # 听写界面
    ├── Features/Reader/              # 阅读（解压、书库、WKWebView、查词）
    ├── Features/Vocabulary/          # 词库
    ├── Features/Settings/            # 设置
    └── Resources/                    # Reader.css / Reader.js / ReadingVocabulary.json / sample.epub
LumaReaderIOSUITests/                 # 模拟器 UI 回归（6 个用例）
```

`Resources/sample.epub` 是 3 章的小样书，只在 Debug 构建、且带 `-seed-sample-book` 启动参数时才会被种进书架，用来跑阅读与查词的回归；Release 包里它不会被用到。
