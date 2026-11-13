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