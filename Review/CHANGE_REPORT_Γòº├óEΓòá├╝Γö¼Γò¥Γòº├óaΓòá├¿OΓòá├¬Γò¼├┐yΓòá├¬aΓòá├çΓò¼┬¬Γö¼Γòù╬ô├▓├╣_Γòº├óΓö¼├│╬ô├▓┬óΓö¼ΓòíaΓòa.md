# 第二版更新：动态 / 静态两套设计 + 听写页跟随主题、莫奈与玻璃

本节优先于下文第一版的同名内容（第 6、7、12 节中“动效”的描述以本节为准）。状态仍为：**未编译、未运行，待 Mac 实机验证**。

## A. 设置入口
设置 › 外观与排版 › 动画 › 视觉效果 › **界面风格：动态 / 静态**（默认为动态）。
- 存储键：`luma.ui.motionStyle`（AppStorage，阅读页与学习中心共用）。
- 实际生效值是 `dynamicInterface`（ContentView），它同时满足：设置为动态，没有开启系统“减少动态效果”，App“动画强度”不是“关闭动画”，也没有处于省电模式（`effectiveMotionLevel`）。这个值通过环境值 `lumaDynamicMotion` 传给所有控件。
- 位置：`CustomizationPanel.swift`（动画强度下方），`AppStrings.json` / `.js` 增加了英文翻译。

## B. 两套设计对照
| 元素 | 动态 | 静态 |
|---|---|---|
| 按钮悬停 | 弹簧放大 ×1.07（0.24s，回弹 0.32）+ 跟随指针的强调色柔光（24%） | 淡底直接出现，无缩放 |
| 按下 / 松手 | 压缩 ×0.90（0.14s），松手回弹（0.25s，回弹 0.45） | 底色加深，无缩放 |
| 图标 | 松手、选中变化时弹跳一次（bounce.down，不循环） | 无 |
| 选中切换 | 弹簧过渡；阅读页搜索 / 目录 / 笔记的选中底色在按钮间滑动（matchedGeometryEffect，0.32s） | 直接切换（颜色 + 淡底 + 实心图标） |
| 书签、开关图标 | 符号替换动画 | 直接替换 |
| 听写进度 | 小进度环弹簧推进；数字滚动；答对时进度环轻跳一次（keyframe 0.14 + 0.32s） | 进度环与文字直接更新 |
| 语音准备 | 沙漏图标旋转，准备结束即停 | 显示静止的沙漏图标 |
| 最近错词 | 从左侧弹入（0.30s，回弹 0.35） | 直接出现 |

两套设计的控件、位置、快捷键和状态表达完全相同，区别只在于动效。
底线：动态设计中所有动画都由事件触发，结束后停止。没有 repeatForever、TimelineView 或空闲动画。正文与听写输入框内不加动效。进度环只在提交后（完成数增加时）跳动，输入过程中不会触发。

## C. 主题、莫奈与玻璃
- 听写页语义色保留原有名称，取值改为来自 `StudyAppearance`（由 ReadingPalette 生成，包含莫奈取色）：

  | 语义色 | 取值 |
  |---|---|
  | dictBgColor | paper |
  | dictCardColor / dictCapsuleColor | surface |
  | dictTextPrimary | ink |
  | dictTextSecondary | ink × 68%（深色）/ 78%（浅色） |
  | dictAccentPink | accent |

- 选“玫瑰 / 暗莓”主题时仍是暗莓配色；开启莫奈时随封面或壁纸变化；浅色模式下听写页也变为浅色。
- 只有暂停用的琥珀色和答错红色是固定的功能色。答错震动与红光的代码未改动。
- 提交按钮上的文字颜色按强调色亮度自动在纸色和墨色之间选择（`dictOnAccent`）。
- 返回胶囊、计时 / 倍速 / 更多胶囊、底部操作区改用 `studyGlassCapsule`。它和阅读页顶栏走同一个玻璃渲染器，跟随“液态玻璃效果”开关、玻璃强度与主题色调。

对比度（经典主题，WCAG）：

| 主题 | 主文字 / 纸色 | 次要文字 / 纸色 | 次要文字 / 表面色 |
|---|---|---|---|
| 玫瑰深色 | 12.0 | 6.3 | 6.0 |
| 纸白深色 | 11.5 | 6.1 | — |
| 午夜 | 13.3 | 6.8 | — |
| 纯黑 | 15.6 | 7.2 | — |
| 玫瑰浅色 | 10.8 | 5.7 | 5.2 |
| 纸白浅色 | 11.8 | 6.0 | 5.6 |
| 薄荷浅色 | — | 5.6 | 5.3 |

莫奈色板由 Material 方案生成（surface / onSurface），需要实机抽查。

## D. 发现的原有问题（未修改）
`AppStrings.js` 原文件末尾多一个 `}`，在 JavaScript 中解析失败，AI 网页界面的英文翻译可能因此一直没有生效。它不属于本次范围，没有修复；新增的翻译沿用了原结构。如需修复请告诉我。

---

# Luma Reader：听写页 / 阅读顶栏 / 图标按钮 / 动效 / 红黄绿对齐 — 改动报告

状态：**源码已修改，已静态核对（57 项通过，见 `verify-icons-motion-alignment.txt`）；未编译、未运行。** 所有视觉与对齐数值均为“待 Mac 实机验证”。
基线：上传的 `LumaReader_Listening_Reading_Redesign_Full_Source.zip`（work/study-center-integration @ fbc23dc + 本地补丁）。行号为本包内新文件行号；原行号标注“原”。

## 1. 源码核对表

| 需求描述位置 | 源码实际 | 结论 |
|---|---|---|
| `workspaceHeaderHeight = 60`（第 42 行） | 原 40–43 行计算属性；非全屏阅读为 60 | 一致 |
| 胶囊在 60pt 栏内居中（第 9 行附近） | 原 538 行 `.frame(height:readingBarHeight)` | 位置不同，逻辑一致 |
| 顶栏块约 476–565 | 原 475–575 `appHeader` | 一致 |
| `studyPractice` 时顶部 padding 0（299）、顶栏隐藏（307） | 原 299、307 | 一致 |
| `DictationPracticeLayout` 外层 `.padding(.vertical,16)`（3201–3202） | 原 3202 | 一致 |
| `dictationBackButton` 约 2423 | 原 2423 | 一致 |
| `dictationTopRightCapsules` 约 2458 | 原 2458 | 一致 |
| `dictationProgressCard` 约 2688 | 原 2688 | 一致 |
| `dictationAnswerBox` 约 2911 | 原 2878 定义，TextField 约 2902 | 偏差约 30 行 |
| 底部六按钮 3129/3143/3151/3161/3170/3179 | 原同 | 一致 |
| AppKit 键盘监听约 3221 | 原 3221 | 一致 |
| 阅读页目标 30、其他 22（1800/1817/1840） | 原同 | 一致 |
| **听写练习页目标“应为 36”** | 宽布局（≥560）返回胶囊与 50pt 计时胶囊同行居中 → 0+16+25 = **41**；窄布局 = 36 | **需求数值需修正** |
| **听写非练习页 96** | `studyPractice` 按模式判断，无当前词时 padding 仍为 0；结算页 24+25 ≈ **49**（窄 44）；错词空页 26+25 ≈ **51** | **96 不会出现** |
| 设置图标 `gear` | 实际 `gearshape`（AnimatedSettingsGlyph） | 名称差异，未改 |
| 快捷键冲突（原有） | ⇧⌘R 同时为“慢放”与菜单“同步已接入云盘” | 未改；是慢放不能收进菜单的原因 |

## 2. 阅读页七键核对（修改前后一致）

| # | 按键 | 动作（原样保留） | 图标 | 快捷键 / help | 新位置 |
|---|---|---|---|---|---|
| 1 | 返回书库 | `closeReaderPanels(); store.returnToLibrary()` + `.focused($readerBackFocused)` | chevron.left | ⌘L | ContentView 510 |
| 2 | 搜索 | `activeReaderPanel = nil; showBookSearch.toggle()` | magnifyingglass | ⌘F（菜单） | 514 |
| 3 | 目录 | `readerPanelButton(.contents)` | list.bullet | — | 519 |
| 4 | 书签高亮笔记 | `readerPanelButton(.notes)`，popover 不变 | note.text | — | 520 |
| 5 | 设置 | `closeReaderPanels(); showSettings = true` | gearshape | — | 631 起 |
| 6 | AI | `store.aiPanelVisible.toggle()` | sparkles | ⌥⌘A | 631 起 |
| 7 | 书签 | `controller.addBookmark()` | bookmark / bookmark.fill | ⌘D | 622 |

顶栏高度计算（40–43 行）未改。只改：统一 `readerToolbarGlyph`（754）与 `readerToolbarStyle`（763）。

## 3. 听写页控件数量对照（练习页，有当前词）

| 区域 | 简化前 | 简化后 | 理由 |
|---|---|---|---|
| 头部 | 返回胶囊 1；标题；三合一胶囊 1（3 控件） | 同；标题下合并进度文字 | — |
| 进度 | 独立行：文字 2 段 + 通栏进度条 | 并入标题下一行文字（含百分比） | 去掉突兀进度条，数据不减 |
| 最近错词 | 标签 + 0–5 胶囊 | 同（胶囊去描边，点击区 40pt） | 功能保留 |
| 底部 | 6 按钮 / 4 视觉胶囊 / 6 文字标签 | 6 按钮 / 1 操作区 / 1 文字标签（提交） | 合并外观，不隐藏动作 |
| **合计** | 视觉胶囊 6；含控件行 4；进度条 1 | 视觉胶囊 3；含控件行 3；进度条 0 | 按钮数 10 不变 |

不把慢放、中文、首字母收进菜单的原因：SwiftUI 菜单项的 `.keyboardShortcut` 只在菜单展开时生效；⇧⌘R 还会落到菜单“同步已接入云盘”。

## 4. 动作归属表

| 动作 | 层级 | 入口 | 快捷键 |
|---|---|---|---|
| 提交 | 常驻（主按钮） | 操作区右侧，文字 + 图标 | 回车（onSubmit + AppKit 监听） |
| 上一个 | 常驻 | 操作区图标 | — |
| 重播 | 常驻 | 操作区图标；准备中显示 hourglass | ⌘R |
| 慢放 | 次级（一步可达） | 操作区图标 | ⇧⌘R |
| 显示/隐藏中文 | 次级（一步可达） | 操作区开关图标 | ⌘H |
| 首字母提示 | 次级（一步可达） | 操作区开关图标 | ⌘/ |
| 查看拼写 | 条件出现 | 提示区按钮 | ⌘' |
| 计时 / 倍速 / 更多 | 常驻 | 右上胶囊 | — |
| 返回 | 常驻 | 左上胶囊 | — |

## 5. 图标清单

| 功能 | 旧样式 | 新样式 | SF Symbol | 语义 |
|---|---|---|---|---|
| 阅读七键 | 17pt medium，仅目录/笔记有选中底 | 17pt medium 单色；打开时强调色 + 淡底 | 同原名 | 不变 |
| 书签 | 颜色区分 | 实心 + 强调色（active），符号替换过渡 | bookmark ↔ bookmark.fill | 不变 |
| 上一个 | 图标 + 文字 | 44×44 图标 | backward.end.fill | 不变 |
| 重播 | 图标 + 文字“准备中…” | 图标；准备中换 hourglass | speaker.wave.2.fill / hourglass | 状态保留（静态） |
| 慢放 | 图标 + 文字 | 图标 | tortoise.fill | 不变 |
| 中文 | 图标 + 文字 | 开关：outline → fill + 强调色 + 底色 | character.bubble(.fill) | 不变 |
| 首字母 | 图标 + 文字 | 同上 | lightbulb(.fill) | 不变 |
| 提交 | 粉色胶囊 | 主按钮（实底） | return | 不变 |

所有图标保留 `help` 与 `accessibilityLabel`；开关附加 `.isSelected`。

## 6. 按钮六态（`LumaIconButtonStyle`，LumaDesignTokens.swift）

| 状态 | 视觉 | 数值 |
|---|---|---|
| 默认 | 透明底，ink 前景 | — |
| 悬停 | ink 淡底，轻微放大 | 8%；×1.04；0.18s |
| 按下 | ink 底加深，缩小 | 14%；×0.94；0.14s，松手 0.22s |
| 聚焦 | 内嵌强调色焦点环 | 2pt，内缩 2pt |
| 禁用 | 整体降低不透明度，无悬停 | 38% |
| 选中 | 强调色前景 + 强调色淡底（+ 实心符号） | 20% |
| 主按钮 | 强调色实底，文字用背景色 | 悬停 93%，按下 84% |
| 提高对比度 | 选中/悬停加 1pt 描边 | — |

## 7. 动效清单与底线核对

| 动效 | 触发 | 时长/缓动 | 减少动态效果 | 对输入与阅读 |
|---|---|---|---|---|
| 按钮悬停/按下 | 指针、点击 | smooth 0.18 / snappy 0.14、0.22 | 无缩放、无动画 | 仅控件 |
| 选中切换 | 开关状态 | smooth 0.22 + 符号 replace（macOS 14） | 静态切换 | 仅控件 |
| 进度数字 | 完成数变化（提交后） | numericText，smooth 0.24 | 无 | 不在输入时触发 |
| 错词胶囊出入 | 错词列表变化（提交后） | 淡入 + 缩放 0.92，smooth 0.22 | identity | 不在输入时触发 |
| 书签 | 添加/移除 | 原 phaseAnimator + 符号 replace | 原逻辑 | 仅控件 |
| 保留不动 | AI 面板、设置、答错震动红光、字号放大 0.10s | 原值 | 原值 | 原值 |

底线：未新增 `repeatForever`、`TimelineView` 或任何持续动画；正文和输入框没有加动效；状态都同时有颜色、图标或文字表达。

未执行：面板分层出场、页面融合过渡、答对反馈。原因：需要改动现有面板代码或接入提交结果，回归风险超出本次范围。

## 8. Token 文件结构

`Deferred/StudyCenter/LumaDesignTokens.swift`（新增，已加入子包 Package.swift）：
- `LumaMotionToken`：时长、缩放、缓动、原有 7 个 spring（数值与原 MotionTokens 相同）、`resolve()`。
- `LumaControlMetric`：40/44 高度、17/16pt 图标、5pt 操作区内边距、27/22 圆角、30pt 胶囊、40pt 最小热区、焦点环、各状态不透明度、`customFocusRing` 开关。
- `LumaIconButtonStyle`：六态样式。
- `LumaWindowControlsAnchorKey` 与 `.lumaWindowControlsAnchor()`。

主 App 的 `SurfaceMotion.swift` 中 MotionTokens 改为引用上述 token，数值不变。

## 9. 红黄绿对齐

| 页面 | 代码推算 | 修改前目标 | 修改前实际 | 修改后目标 | 修改后实际 / 误差 |
|---|---|---|---|---|---|
| 阅读 | 30 | 30 | 未测 | 左胶囊实测（≈30） | 待 Mac |
| 听写练习（宽） | 41 | 22 | 截图估 ≈15 | 返回胶囊实测（≈41） | 待 Mac |
| 听写练习（窄 <560） | 36 | 22 | 未测 | 实测（≈36） | 待 Mac |
| 听写结算页 | 49 / 44 | 22 | 未测 | 实测 | 待 Mac |
| 错词空页 | 51 | 22 | 未测 | 实测 | 待 Mac |
| 写作模拟机考、书库、其他 | — | 22 | — | 22（不变） | — |

实现：
- 胶囊上报 `.global` 中心 y。听写页用 `onScrollGeometryChange` 加 `transformPreference` 抵消滚动。
- `trafficLightTarget`（ContentView 约 284）只接受与推算值相差 16pt 以内的实测值，防止形成循环。
- `alignTrafficLights` 先把目标换算到每个按钮父视图的坐标系，再读回实际位置；误差超过 1pt 时最多重试 2 次并记录日志（Logger 分类 WindowControls）。
- 监听标题栏的 frame 变化，AppKit 重排后自动纠正，每秒最多 8 次。
- 没有隐藏按钮，没有禁用缩放，没有修改窗口样式。

## 10. 修改文件

| 文件 | 内容 |
|---|---|
| Deferred/StudyCenter/LumaDesignTokens.swift | 新增 |
| Deferred/StudyCenter/Package.swift | 加入新文件 |
| Deferred/StudyCenter/StudyHome.swift | 返回胶囊 2424、右上胶囊样式、进度 2685、错词 2739/2770、头部 3081、操作区 3105–3243、滚动抵消 3266 |
| Sources/LumaReader/ContentView.swift | 对齐目标、锚点、七键样式、ChromeView 目标传递 |
| Sources/LumaReader/NativeWindowControls.swift | 对齐重写、读回、frame 监听 |
| Sources/LumaReader/SurfaceMotion.swift | MotionTokens 引用 token |
| 继续上次安装.command | 标题文字；同步旧副本时一并复制子包 Package.swift |

逐行对照见 `Review/changes-icons-motion-alignment.patch`。

**Swift 6 / 系统版本说明：**
- StudyKit 使用 Swift 6 语言模式，最低 macOS 15。动画用计算属性，PreferenceKey 默认值是 Sendable 的 `CGFloat?`。
- `onScrollGeometryChange` 需要 macOS 15。
- `smooth`、`snappy`、`symbolEffect(.replace)`、`focusEffectDisabled` 需要 macOS 14。
- 主 App 最低 macOS 26，不受影响。

## 11. 保护区核对（脚本逐字节比对）

- 输入框：`dictationAnswerBox` 整体逐字节不变，包括绑定、focused、autocorrection、disabled、onSubmit 和 identifier。
- 回车与快捷键：AppKit 监听不变；StudyHome 与 ContentView 的全部 keyboardShortcut 声明不变；LumaReaderApp.swift 未改。
- 听写判断、语音、计时与菜单：提交、语音、更多菜单、错词、状态行和 HostStateModel 不变。
- 答错震动与红光：`DictationShakeEffect`、`triggerDictationErrorAnimation` 及输入框上的相关修饰符不变。
- 阅读七键：动作闭包、help、accessibilityLabel 集合与顺序不变。ReaderController.swift、NoteActions.swift 未改。
- 写作：StudyPromptView.swift 未改。

## 12. 完成情况

| 项 | 状态 |
|---|---|
| A 听写 UI 与按键整理 | 完成（静态） |
| B 阅读顶栏视觉 | 完成（静态） |
| C 图标按钮统一 | 完成（静态） |
| D 动效 | 部分完成（第 7 节所列未执行项） |
| E 红黄绿对齐 | 完成（静态），数值待实机 |
| 背景色调整 | **待确认**（方案：听写背景改用 dictCardColor #211720，主文字对比度 15.1，次文字 6.5） |
| 编译 / 运行 | **未完成**（无 Mac 环境） |

## 13. 待 Mac 实机验证清单
- 听写：六个动作、计时、倍速、更多菜单均可达，行为与原来一致。宽度不足 420 时操作区变为两行。
- 阅读：七键可见可用，面板与快捷键正常，选中态正确。
- 全部快捷键正常；回车提交与 Tab 顺序正常；**焦点环可见**（若看不到，把 `customFocusRing` 改为 false）。
- 输入框不与其他控件重叠，字号自适应正常；答错震动与红光不变。
- 红黄绿与返回胶囊、阅读胶囊的误差 ≤1pt；AI 面板开关、全屏、缩放窗口、滚动听写页后仍对齐；红黄绿下方的胶囊可以正常点击。
- 浅色 / 深色、提高对比度、降低透明度、减少动态效果下均正常。
- 用 Instruments 检查阅读滚动不掉帧；连续使用 60 分钟以上，主观疲劳感可接受。
- 写作的高亮与笔记正常。
