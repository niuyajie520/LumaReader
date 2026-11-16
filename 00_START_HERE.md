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

# 当前交付：LumaReader 1.17.1 B105

阅读四选一答对后快速进入下一题。双击 Install.command 安装。

# 当前交付：LumaReader 1.17.0 B104

阅读练习支持独立计时，切到后台自动暂停。神经语音按原设置恢复。双击 Install.command 在 Mac 本机编译安装。

# 当前交付：LumaReader 1.16.1 B103

修复 B102 的听写设置面板 Swift 泛型推断错误。双击 Install.command 在 Mac 本机编译安装。

# 当前交付：LumaReader 1.16.0 B102

双击 Install.command 在 Mac 本机编译安装。听写设置分为练习、发音和更多，阅读四选一支持兼容手柄。

# 当前交付：LumaReader 1.15.1 B101

双击 Install.command 在 Mac 本机编译安装。本版优化听写首屏统计、输入焦点和语音预读顺序。

# 当前交付：LumaReader 1.15.0 B100

双击 Install.command 在 Mac 本机编译安装。听力与阅读词汇支持从卡片继续练习，到期错词优先，练习结束页显示正确率和错词。

# 当前交付：LumaReader 1.14.3 B99

听力与阅读词库使用统一的页头、搜索框和卡片尺寸。每日听写进度仍位于听力首页上方。

# 当前交付：LumaReader 1.14.2 B98

修复阅读四选一的选项生成和答案位置分布。双击 Install.command 在 Mac 本机编译安装。

# 当前交付：LumaReader 1.14.1 B97

修复 B96 安装时的两处 Swift 语法错误。双击 Install.command 在 Mac 本机编译安装。

# 当前交付：LumaReader 1.14.0 B96

阅读词汇顶部只有「词库」「错词」「分类」。双击 Install.command 在 Mac 本机编译安装。

# 当前交付：LumaReader 1.13.1 B95

阅读词汇采用词库卡片和统一搜索，背词与易混词移入阅读词汇。双击 Install.command 在 Mac 本机编译安装。

# 当前交付：LumaReader 1.13.0 B94

新增「学习 → 阅读词汇」，内置 6,063 条雅思阅读词条。双击 Install.command 在 Mac 本机编译安装。以下为历史说明。

# 当前交付：LumaReader 1.12.4 B93

悬浮练习小窗输入区和发音优化。双击 Install.command 在 Mac 本机编译安装。以下为历史说明。

# 当前交付：LumaReader 1.12.3 B92

听写启动与阅读 AI 面板动效优化。双击 Install.command 在 Mac 本机编译安装。以下为历史说明。

# 当前交付：LumaReader 1.12.2 B91

新增「易混词」系统与悬浮小窗练习（⌥⌘6）。双击 Install.command 在 Mac 本机编译安装。以下为上一版说明。

# 上一版：LumaReader 1.11.1 B88

「背词」改为独立系统：独立词库，支持导入、编辑、文件夹分类；ABCD 选择题背单词。双击 Install.command 在 Mac 本机编译安装。以下为历史说明。

# 当前交付：LumaReader 1.9.0 B76

自定义主视觉导入与界面透明度调节。以下为上一版说明。

# 上一版：LumaReader 1.8.3 B75

主视觉漫画风（墨线、排线、网点、星芒）。以下为上一版说明。

# 上一版：LumaReader 1.8.2 B74

重绘伏见稻荷鸟居、神奈川冲浪里与 Space 天文台三幅主视觉。以下为上一版说明。

# 上一版：LumaReader 1.8.1 B73

主题主视觉版：每个主题一幅大尺寸标志性建筑或原创角色场景。以下为上一版说明。

# 上一版：LumaReader 1.8.0 B72

主题重设计版：各主题布局各不相同，尼尔改为苔绿废墟都市，新增废土终端主题。运行 Install.command 在 Mac 本机编译安装。此环境未完成 Mac 原生编译，以 Mac 本机结果为准。详见 CHANGELOG.md。

# 当前交付：LumaReader 1.7.0 B68

运行 Install.command 在 Mac 上编译安装。安装器会尝试恢复 Kitten Nano 和 Micro。可以在「语音与发音 → 模型文件管理」重试，并查看语音安装日志。「主题与外观 → 主页字体、语言与图标」可调节全局字号。

已通过 19 项后端测试。此环境未完成 Mac 原生构建、语音试听或界面验证。以下是历史交付说明。

# 当前交付：LumaReader 1.6.1 B67

根据 B66 的 Mac 编译日志修复 Swift 6 Notification 跨隔离捕获错误。功能、布局、主题、性能策略和快捷键均保留 B66。完整说明见 Review/BUILD_FIX_B67_ZH.md。此环境仍无法完成 Mac 原生构建，安装成功需以 Mac 本机结果为准。

以下为历史交付说明；以 release.json 为准。

# 当前交付：LumaReader 1.6.0 B66

完整源码候选优化版，基于上一版 B65。优先降低无风扇 Mac 的持续资源占用，保留现有功能、主题和动画。详细体检及权衡见 Review/PERFORMANCE_AUDIT_B66_ZH.md。仅删除旧 Kokoro 82M，继续保留 Kitten Micro/Nano 与苹果语音。

Install.command：Mac 本机编译安装。Verify-LumaReader.command：Mac 原生构建与测试。尚未在此环境编译或实机验证。听写快捷键：⌘R 重播，⇧⌘R 慢放，⌥⌘P 暂停/继续，⌥⌘M 中文，⌘/ 首字母，⌥⌘← 上一个完成单词，⇧⌘/ 帮助。

以下全部是历史交付说明；当前版本以 release.json 为准。

# 当前交付：LumaReader 1.5.0 B65

本包是完整源码候选修复版，不是已经在 macOS 编译通过的二进制安装包。先阅读 Review/FIX_REPORT_B65_ZH.md。双击 Install.command 在 Mac 本机编译安装；仅删除旧 Kokoro 82M 模型，保留 Kitten 两款模型与学习文件。鼠标点击失效及强退后再启动的唯一根因尚待 Mac 记录确认，可用键盘运行 Diagnose-Mac.command 获取只读诊断。

以下为历史说明，版本信息以 release.json 为准。

# Luma Reader：听写与阅读中心改版交付说明

状态：源码已修改；已静态审查；待 Mac 编译与实机验证。没有运行 macOS App，没有完成视觉验收。

本报告所有行号均对应本交付包，而非原 ZIP。完整现行代码在工程内；`Review/changes.patch` 按文件列出原代码（减号）、替换代码（加号）和上下文。不要把历史报告中的 PASS 当成本次构建结果。

## 1. 范围确认

| 范围 | 本次处理 | 证据 |
|---|---|---|
| 听写整体布局 | 上方信息、中央输入、下方提示与操作三层；减少卡片边框和重复标题 | `Deferred/StudyCenter/StudyHome.swift:3090`、`Deferred/StudyCenter/StudyHome.swift:3191` |
| 听写输入排版 | 默认上限 140pt、下限 36pt；超长输入允许折行 | `Deferred/StudyCenter/StudyHome.swift:2878`、`Deferred/StudyCenter/DictationPracticeLayout.swift:24` |
| 按钮整理 | 六个动作保持为六个独立 Button，视觉上合为四组 | `Deferred/StudyCenter/StudyHome.swift:3111` |
| 说明文案 | 删除重复教学说明，保留空状态、状态行和结果数据 | `Deferred/StudyCenter/StudyHome.swift:3265`、`Deferred/StudyCenter/StudyHome.swift:3538` |
| 阅读中心 | 保留原左四右三七键；调整热区、顶栏占位、导航面板和目录行 | `Sources/LumaReader/ContentView.swift:475`、`Sources/LumaReader/ContentView.swift:774`、`Sources/LumaReader/ReadingOutlineView.swift:139` |
| 业务算法 | 听写判断、循环、慢反应、计时器、语音与阅读数据算法没有修改 | `Review/static-review.json` 的函数与字节比较记录 |
| 保护区 | 错误震动、红光参数与触发函数保持原代码；写作功能没有修改 | `Deferred/StudyCenter/StudyHome.swift:559`、`Deferred/StudyCenter/StudyHome.swift:4895` |

必须说明的一项输入实现变化：原单行 TextField 改为始终存在的 `axis: .vertical` TextField。单行控件无法在 36pt 下容纳任意长度的词，又同时让所有字母完整可见；所以采用折行。保留直接绑定和 `.onSubmit`，并在原 AppKit 事件监听中增加普通回车与小键盘 Enter 的兼容分支，调用原提交函数。它过滤当前焦点、主窗口、弹窗、输入法组字和禁用状态。没有改写输入字符串，也没有增加拼写清洗或自动纠错。

这是输入呈现和事件接线的变化，不能仅凭静态比较宣称其运行行为完全等价。多行控件的 Tab、粘贴带换行文本、输入法确认及回车长按仍需 Mac 回归；若实机表现不同，须修复后才可验收。相关位置：`Deferred/StudyCenter/StudyHome.swift:2902`、`Deferred/StudyCenter/StudyHome.swift:3221`。

## 2. 现状核对

基线是本次上传的 `LumaReader_Listening_Menu_Settings_Full_Source(1).zip`，没有从 GitHub 上另取版本替换它。

| 用户描述 | 原包实际情况 |
|---|---|
| 输入框约 2911 行 | 一致；原 2911 行定义，原 2928 行 TextField |
| 顶部胶囊约 2454 行 | 一致；计时、倍速、更多菜单原本就已存在 |
| 主布局约 3112 行 | 一致；原 3112 行定义，六按钮位于其内部 |
| 输入字号目标 140/36pt | 原来为空值 56pt、非空 80pt，附 minimumScaleFactor(0.4) 与 lineLimit(1)，没有基于实际字体的宽度适配 |
| 输入区高度约 260pt | 原来 minHeight 214、maxHeight 224，不是 260pt |
| App macOS 26+ | 主 Package.swift 的确是 26.0；本地 StudyCenter 子包原为 macOS 15，保持原值 |
| 可修改全部排版 | 写作与错误动效保护条件仍优先；未调整它们的时间、数值或行为 |
| 阅读中心七键 | 原包确实左四右三，当前仍保留相同七项动作与顺序 |

原窗口最小 940×620 定义在 `Sources/LumaReader/LumaReaderApp.swift:18`，没有修改。

## 3. 大改方案与布局草图

听写页从上到下：返回与模式标题 / 计时、倍速、更多 → 细进度条与完成、剩余、今日数量 → 一行最近错词 → 位于画布正中央的输入区 → 中文、首字母、订正拼写 → 状态行 → 四个操作胶囊。

布局通过三兄弟视图的实际高度计算留白：输入中心放在画布 midY，上下分别预留两侧较高区域的高度再加 16pt，避免提示和按钮覆盖输入。输入区至少 260pt。常规窗口内保持垂直居中；当窗口高度、提示长度或输入行数使内容超过可用高度时，整张画布垂直滚动，中心相对于完整画布。此时无法同时满足“任意长文本全显示、窗口绝对居中、所有操作同时在屏幕内”，所以优先保留完整文本和不重叠。没有给编辑器设置固定最大高度或嵌套的编辑区滚动窗口。见 `Deferred/StudyCenter/DictationPracticeLayout.swift:65`、`Deferred/StudyCenter/StudyHome.swift:3191`。

输入统一使用圆体粗体的实际 NSFont 宽度测量，二分查找字号，并给光标与系统边距留出 24pt。超过下限的长词通过纵向 TextField 折行；移除 lineLimit(1) 和最大高度。纯 SwiftUI 的实际断行及焦点编辑器绘制需要实机确认，不能以测量函数代替视觉证据。见 `Deferred/StudyCenter/DictationPracticeLayout.swift:11`、`Deferred/StudyCenter/DictationPracticeLayout.swift:24`、`Deferred/StudyCenter/StudyHome.swift:2902`。

字号放大需要至少 3pt 的空间变化才生效，放大过渡 0.10 秒；缩小直接切换以避免动画经过过大字号。折行模式进入/退出采用 24/48pt 余量，形成 24pt 滞后带；切换直接完成。减少动态效果开启时，新增字号过渡直接切换。输入超过四行等极端情况会增加内容高度，进入整页滚动，不能承诺画布高度完全不变。见 `Deferred/StudyCenter/DictationPracticeLayout.swift:39`、`Deferred/StudyCenter/DictationPracticeLayout.swift:44`、`Deferred/StudyCenter/StudyHome.swift:2921`。

动态字号通过输入上限的 ScaledMetric 接入：默认 140pt，系统放大时允许提高至 180pt，下限仍为 36pt；它仍受可用宽度约束。辅助控件沿用明确字号，不宣称所有历史页面都已支持动态字号。见 `Deferred/StudyCenter/StudyHome.swift:1270`、`Deferred/StudyCenter/StudyHome.swift:2886`。

### 操作合并对照

| 修改前六按钮 | 修改后四个视觉组 | 具体行为与快捷键 |
|---|---|---|
| 上一个 | 上一个 | 原回退、清输入、保存、播音与聚焦顺序保持；禁用条件保持 |
| 重播 | 播放组左半 | 准备中/重播状态保持，Cmd+R 保持 |
| 慢放 | 播放组右半 | 原 overrideRate: 0.75，Cmd+Shift+R 保持 |
| 显示/隐藏中文 | 提示组左半 | 原 showMeaning 切换并保存，Cmd+H 保持 |
| 首字母提示 | 提示组右半 | 原 showFirstLetterHint 切换，Cmd+/ 保持 |
| 提交 | 提交 | 原 submitCurrentDictation 与禁用条件保持 |

合并的是共同外轮廓，没有把两项动作藏进菜单。这样保留六个原生 Button 的顺序、各自焦点和状态。正常按钮高度 44pt；宽度不足时通过同一 AnyLayout 的布局切换为两列，进一步不足时单列。见 `Deferred/StudyCenter/StudyHome.swift:2988`、`Deferred/StudyCenter/StudyHome.swift:3111`、`Deferred/StudyCenter/DictationPracticeLayout.swift:87`。实际 Tab 仍待实机验证。

### 删除的说明文字

| 原文字 | 处理与理由 | 修改后位置 |
|---|---|---|
| “先导入你自己的单词表，听写答错的单词会自动出现在这里。” | 删除；“还没有词库/还没有错词”及导入按钮已表达当前状态和操作 | `Deferred/StudyCenter/StudyHome.swift:3021` |
| “在听写练习中答错的单词会自动收录到这里，方便你随时专项复习。” | 删除；保留“当前词库还没有错词”和去听写按钮 | 同上 |
| “统计从语音播完到敲下回车的时间：虽然拼写正确但犹豫超过 5.0 秒的词在真题语速下极易漏听，系统自动将其归入此处进行倍速听写提速。” | 删除长段教学文案；计时阈值与统计实现没有修改 | `Deferred/StudyCenter/StudyHome.swift:3265` |
| 慢反应空状态中对“超过 5.0 秒”的重复解释 | 缩为“暂无慢反应词记录。”，保留状态 | 同上 |
| “当日累计第 6 次答错进入顽固单词，当前词订正后不再自动循环；按错误次数从高到低排序，独立记录复习会话。” | 删除说明；触发条件、循环与排序代码保留 | `Deferred/StudyCenter/StudyHome.swift:3538` |
| “本轮进度”及顶栏重复计数 | 改由同一行“已完成 / 总数、剩余、今日”和百分比表达，不删除数量数据 | `Deferred/StudyCenter/StudyHome.swift:2688` |
| 阅读导航面板的“阅读导航”加第二行当前标签双标题 | 整理为当前页标题和下方三标签，仍有目录、书签、笔记全部入口 | `Sources/LumaReader/ContentView.swift:774` |

没有删除或改写 vm.dictationFeedback 的任何状态与结果赋值。原主布局本来主要展示 dictationStaticStatusLine，该函数原样保留，也没有新增另一个结果展示机制。

### 阅读中心具体改动

| 区域 | 改动 | 保留项 | 位置 |
|---|---|---|---|
| 两侧胶囊 | 图标 17pt、热区高 40pt、常规宽 44pt；窄阅读窗按七键预算收窄 | 七键功能与左右顺序 | `Sources/LumaReader/ContentView.swift:475` |
| 顶栏与正文 | 使用一个 workspaceHeaderHeight 同时计算顶栏高度、正文上边距、ReadingLayoutSlot 高度；窗口 60pt，全屏按现有原生控制中心测量值计算 | 原 NativeWindowControls 和显隐时机 | `Sources/LumaReader/ContentView.swift:40`、`Sources/LumaReader/ContentView.swift:282` |
| 书名 | 14pt、现有 ink；安全中心空间不足 72pt 时隐藏书名，让七个操作保留空间 | 书籍数据与阅读位置 | `Sources/LumaReader/ContentView.swift:487` |
| 导航面板 | 宽 360pt；单标题、等宽 36pt 高目录/书签/笔记标签 | 原面板绑定与选中动作 | `Sources/LumaReader/ContentView.swift:774` |
| 目录 | 14pt 文本、44pt 最小行高；允许长标题完整换行 | 原层级、折叠、搜索、跳转和禁用条件 | `Sources/LumaReader/ReadingOutlineView.swift:139` |

没有修改 Reader.css、Reader.js、PagedWebView.swift、ReaderController.swift、ReaderKeyboard.swift 和 NativeWindowControls.swift。顶栏占位改变会自然改变阅读可用视口，分页是否保持原阅读位置属于实机回归范围；分页算法本身没有修改。

## 4. 文件、替换方式、API 与 Swift 6

| 文件 | 交付变化 | 位置 |
|---|---|---|
| StudyHome.swift | 替换听写 UI 区块，增加宽度/字号/折行呈现状态；删除上述文案；扩展回车兼容分支 | `Deferred/StudyCenter/StudyHome.swift:1267`、`Deferred/StudyCenter/StudyHome.swift:2878`、`Deferred/StudyCenter/StudyHome.swift:3191` |
| DictationPracticeLayout.swift | 新增字体度量、字号滞后、可动画字体、三层居中布局和按钮自适应布局 | `Deferred/StudyCenter/DictationPracticeLayout.swift:6`、`Deferred/StudyCenter/DictationPracticeLayout.swift:51`、`Deferred/StudyCenter/DictationPracticeLayout.swift:65`、`Deferred/StudyCenter/DictationPracticeLayout.swift:87` |
| StudyCenter/Package.swift | 只将新文件加入显式 sources；没有改变部署目标或依赖版本 | `Deferred/StudyCenter/Package.swift:18` |
| Tests/DictationAnswerMetricsTests.swift | 新增 4 个测试，覆盖短词、长词宽度、最小字号和滞后；尚未运行 | `Deferred/StudyCenter/Tests/DictationAnswerMetricsTests.swift:8` |
| ContentView.swift | 替换阅读顶栏与导航面板 UI | `Sources/LumaReader/ContentView.swift:40`、`Sources/LumaReader/ContentView.swift:475`、`Sources/LumaReader/ContentView.swift:774` |
| ReadingOutlineView.swift | 仅目录行字体、高度、文字布局 | `Sources/LumaReader/ReadingOutlineView.swift:139` |

直接使用交付包中的完整工程；若需要查看每段待替换的原代码，请打开 `Review/changes.patch`。补丁是上述六个文件的完整统一差异，新增文件以 `/dev/null` 为原文件。没有把“示例片段”冒充完整实现。

版本要求：主 App 仍要求 macOS 26.0+，并需要支持该 SDK 的 Xcode。新增的 TextField(axis:)、Layout、AnyLayout 可用于 macOS 13+；两参数 onChange(initial:) 用于 macOS 14+；onGeometryChange 在本工程按现有 macOS 15 子包下限使用，不需要提高原子包目标。没有新增第三方库；Liquid Glass 继续使用工程已有封装与版本判断。

Swift 6：原 HostView 保持 @MainActor，NSFont 宽度度量集中在 @MainActor 的 DictationAnswerMetrics；新增状态仅用于呈现。布局函数只做尺寸计算与摆放，不修改 VM，不启动后台任务，不把 NSFont、视图或 VM 跨 actor 传递。没有新增全局可变缓存或计时任务。实际 Swift 6 类型检查仍待 Mac 编译，静态脚本不替代编译器。

官方 API 依据：

- [TextField 多行支持（macOS 13 发布说明）](https://developer.apple.com/documentation/macos-release-notes/macos-13-release-notes)
- [TextField 的 axis 初始化方式](https://developer.apple.com/documentation/swiftui/textfield/init%28_%3Atext%3Aprompt%3Aaxis%3A%29)
- [onSubmit](https://developer.apple.com/documentation/swiftui/view/onsubmit%28of%3A_%3A%29)
- [macOS 14 发布说明中的桥接控件按键限制](https://developer.apple.com/documentation/macos-release-notes/macos-14-release-notes)

因此最终代码复用了原 AppKit 本地事件监听，没有仅依赖 SwiftUI onKeyPress 拦截桥接输入控件的回车。

## 5. 功能保留的静态证据

这里提供的是代码证据，不是运行中“功能不变”的验收结论。

| 原功能/修饰符 | 当前代码位置 | 静态结论 |
|---|---|---|
| TextField 标题与 $vm.dictationInput | `Deferred/StudyCenter/StudyHome.swift:2902` | 直接绑定未加代理 setter；只新增 prompt 与 axis |
| .focused($answerFocused) | `Deferred/StudyCenter/StudyHome.swift:2904` | 保留，FocusState 声明也保留 |
| .autocorrectionDisabled() | `Deferred/StudyCenter/StudyHome.swift:2905` | 保留，没有加入输入改写 |
| .disabled(!listeningDailyTimer.running || kokoro.isSwitching) | `Deferred/StudyCenter/StudyHome.swift:2917` | 与原字段禁用条件相同 |
| .onSubmit → submitCurrentDictation | `Deferred/StudyCenter/StudyHome.swift:2918` | 保留原调用；原提交函数代码一致 |
| study.dictation.answer | `Deferred/StudyCenter/StudyHome.swift:2916` | 字符串保留；全文件 identifier 集合一致 |
| 普通回车与小键盘 Enter | `Deferred/StudyCenter/StudyHome.swift:3221` | 新增本地兼容分支；处理后消费事件，避免重复提交；实际行为待验证 |
| Tab/Shift+Tab | `Deferred/StudyCenter/StudyHome.swift:3111` | 没有拦截 Tab，没有移除任何按钮；布局切换使用 AnyLayout；原生遍历待验证 |
| Cmd+R | `Deferred/StudyCenter/StudyHome.swift:3148` 与 `Deferred/StudyCenter/StudyHome.swift:3231` | 原声明和原命令监听分支均保留 |
| Cmd+Shift+R | `Deferred/StudyCenter/StudyHome.swift:3156` | 保留，仍调用 0.75 倍速 |
| Cmd+H、Cmd+/、Cmd+' | `Deferred/StudyCenter/StudyHome.swift:3231` | 原命令判断及切换/保存/揭晓动作一致 |
| 上一个禁用条件 | `Deferred/StudyCenter/StudyHome.swift:3131` | 保留 previous == nil 或 requiresCorrection |
| 提交按钮禁用条件 | `Deferred/StudyCenter/StudyHome.swift:3182` | 保留 timer 未运行或模型切换中 |
| 计时器、倍速、更多 | `Deferred/StudyCenter/StudyHome.swift:2458` | 原操作与条件不变，只有暂停数字颜色改为已有主文字色 |
| 语音、听写、循环、慢反应 | `Deferred/StudyCenter/StudyHome.swift:4834`、`Deferred/StudyCenter/StudyHome.swift:4913` | 函数体与原包完全一致 |
| 震动与红光 | `Deferred/StudyCenter/StudyHome.swift:559`、`Deferred/StudyCenter/StudyHome.swift:4895`、`Deferred/StudyCenter/StudyHome.swift:2938` | 几何效果、0.46/680ms/0.25 时序、减少动态效果分支、边框/阴影参数与原代码一致 |
| 写作高亮与笔记 | StudyHome.swift 的改动只落在列出的听写 UI 范围；独立写作文件逐字节一致 | 原混合文件中的写作区域和全部独立写作源码未改 |
| 阅读七键与沉浸 | `Sources/LumaReader/ContentView.swift:475`；原 revealReaderChrome/scheduleChromeHide 等函数体相同 | 动作与显隐算法保留 |

`Review/verify-preservation.py` 可以传入原包解压后的工程目录复核。当前执行结果：262 项静态比较/条件核对；169 个未改业务、资源与依赖文件逐字节一致。它检查的是源码保存关系，不会运行 SwiftUI、TTS 或阅读引擎。

## 6. 对比度与验证清单

新增听写正文、辅助文案和提示分别使用原有 dictTextPrimary、dictTextSecondary、dictAccentPink，不新增颜色常量。提交由原来的浅色字配粉色底改为已有 dictBgColor 配 dictAccentPink，降低低对比风险；placeholder 明确使用 dictTextSecondary。

| 文字/背景组合 | 静态对比度 |
|---|---|
| dictTextPrimary / dictBgColor | 16.64:1 |
| dictTextSecondary / dictBgColor | 7.15:1 |
| dictTextSecondary / dictCapsuleColor | 5.28:1 |
| dictAccentPink / dictCardColor | 8.65:1 |
| 提交文字 dictBgColor / dictAccentPink | 9.52:1 |

以上只证明列出的不透明 token 组合达到普通文字 4.5:1，不能证明所有系统禁用态、透明材质、错误红光、动态莫奈背景和所有历史页面的实际合成结果。保护区的系统红色保持原样。阅读新文字使用现有 ink，提高对比度/减少透明度继续走原材质封装；实际全状态 AA 仍待 Mac 验证。

| 验证项 | 结论标记 | 已有证据与待做动作 |
|---|---|---|
| 短词、中等词、30+字母长词完整显示 | 待 Mac 实机验证 | 已静态审查：移除单行限制/最大高度；用 apple、accommodation、pneumonoultramicroscopicsilicovolcanoconiosis、31个W和100个W测试；4个新增测试尚未执行 |
| 聚焦/失焦均无省略号 | 待 Mac 实机验证 | 同一 TextField 无条件存在，没有 focused 分支替换；逐字检查前后与插入点 |
| 最小窗口至全屏布局与居中 | 待 Mac 实机验证 | 已静态审查：三层布局无交叠公式；940×620、1280×800和全屏拖动验证；不足时整页滚动是明确退路 |
| 回车、Tab、Cmd+R、Cmd+Shift+R | 待 Mac 实机验证 | 已静态审查：原声明、动作保留；补测 Shift+Tab、小键盘 Enter、长按、Caps Lock、输入法确认与带换行粘贴 |
| 禁用条件与之前一致 | 已静态审查 | 字段与提交用原条件，上一个用原条件；实际点击和焦点仍待 Mac 验证 |
| 合并后每个操作与选中状态 | 待 Mac 实机验证 | 已静态审查：六个动作闭包一致，状态绑定不变，顺序不变 |
| 计时器、倍速、更多菜单 | 待 Mac 实机验证 | 已静态审查：动作、数据流及 sheet/popover 代码保留 |
| 答错震动与红光 | 已静态审查 | 保护代码和参数一致；需在新输入区域实际触发，并测试减少动态效果 |
| 写作高亮与笔记 | 已静态审查 | 本次没有改动其源码；全工程构建后仍需一次集成回归 |
| 减少动态效果 | 待 Mac 实机验证 | 新字号动画条件有 reduceMotion；保护区仍按原代码运行 |
| 提高对比度与 WCAG AA | 待 Mac 实机验证 | 不透明听写组合已计算；实际材质、系统禁用态、错误态和所有主题尚未测量 |
| 动态字号 | 待 Mac 实机验证 | 输入上限接入 ScaledMetric；辅助文字仍沿用显式字号，检查最大设置下布局与滚动 |
| 阅读七键与全屏红黄绿对齐 | 待 Mac 实机验证 | 已静态审查：七键保留、共享顶栏占位；需在 AI 开/关与全屏切换时观察 |
| 阅读目录、书签、笔记 | 待 Mac 实机验证 | 原导航算法与闭包保持；验证长标题换行、折叠、搜索、跳转、返回与键盘操作 |
| Debug / Release / Swift 6 编译 | 待 Mac 实机验证 | 当前环境是 Linux，没有 swift/xcodebuild，未执行任何 Swift 构建 |

在有 macOS 26 SDK 的 Mac 上，于解压后的新工程根目录执行：

```bash
xcrun swift build -c debug
xcrun swift test --package-path Deferred/StudyCenter --no-parallel
bash Scripts/verify-macos.sh
```

再按上表做真实交互验证。现有 `Install-LumaReader.command` 仍可用于本地构建安装，但本交付没有生成新版二进制、签名结果或安装验收记录。

## 7. 交付内容与排除项

工程内含完整源码、原必要资源与依赖源码、新增度量测试、本报告、完整补丁、可重跑的保留核对脚本和本次静态核对结果。已对交付目录运行现有 privacy-gate.py，未发现其规则涵盖的凭据或私人路径；此扫描不等于全面秘密扫描或 Gitleaks 验收。

原包的 dist 旧预编译 App，以及 CI-PREP-TESTS.json、PRIOR-PASS.csv、PRIVACY-FILES.csv、PRIVACY-SOURCE.json、SECOND-PASS-REPORT.txt 和两个 Web 性能结果 JSON 没有收入新源码包，以免把旧二进制或旧运行结果当作本次结果。项目的诊断实现与合成测试夹具是源码，仍按原包保留。没有上传 GitHub、合并 PR 或发布 Release。
