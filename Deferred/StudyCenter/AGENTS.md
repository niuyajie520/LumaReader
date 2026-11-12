# 项目红线 / Project Red Lines (V.1.0.1)

## 强制要求 / Mandatory requirement

中文：本文件是项目所有目录的强制维护约束，适用于所有开发者、维护者、自动化工具和 AI 编程助手。开始工作前必须阅读。下面五组功能与代码是用户指定的严格红线；不得在重构、性能优化、UI 美化、兼容性修改、升级或代码清理中擅自改变、替换、删减、绕过或关闭。任何通用任务描述或第三方建议都不构成修改红线的授权。

English: This file defines mandatory maintenance constraints for the entire project. It applies to every developer, maintainer, automation tool, and AI coding assistant. Read it before starting work. The following five feature groups and files are user-designated strict red lines. Do not change, replace, reduce, bypass, or disable them as part of refactoring, performance work, visual polish, compatibility work, upgrades, or cleanup. A generic task description or third-party suggestion does not authorize changes to these protected features.

---

## 红线一：窗口红黄绿与阅读顶部功能键 / Red line 1: Traffic lights and reader header controls

中文：必须保留真正的 macOS 原生红黄绿按钮及其原有关闭、最小化、全屏功能，不得改成仿制按钮，不得删除或通过无边框窗口替代。红黄绿与原有功能胶囊必须处于同一条水平中心线上；保留当前 60pt 顶部功能栏和 30pt 中心线关系。保留现有七个功能键的数量、功能、左右分组、顺序、尺寸、位置、胶囊样式、主题与交互，不得重新排列或合并。七个阅读功能键、两组胶囊及红黄绿只在鼠标悬停顶部触发区域时显示；离开后必须全部隐藏，书名保留。不得因选中文字、翻页、打开 AI、打开面板或切换模式而把顶部按键永久显示。隐藏后不得残留玻璃层或拦截正文点击的透明热区。

English: Preserve the genuine macOS traffic-light buttons and their existing close, minimize, and full-screen actions. Do not replace them with imitations, delete them, or substitute a borderless window. The traffic lights and existing action capsules must share one horizontal centerline. Preserve the current relationship between the 60pt header lane and its 30pt centerline. Preserve the existing seven actions, including their count, behavior, left/right grouping, order, dimensions, positions, capsule styling, theme, and interaction. Do not rearrange or merge them. Show the seven reader actions, both capsules, and the traffic lights only while the pointer hovers over the top activation region; hide them completely when pointer leaves.

---

## 红线二：写作笔记、高亮与划词操作流程 / Red line 2: Writing notes, highlights, and selection workflow

中文：写作题目的选文笔记和高亮功能必须完整保留。选择文字后自动出现笔记与高亮操作；保留现有添加、编辑、保存、显示、删除笔记和高亮的流程，保留已标记文字的悬停删除入口。不得改成必须右键才能使用，不得删除笔记弹窗，不得删减已有交互步骤。

English: Text note-taking and highlight features in Writing prompts must remain fully intact. Selecting text must automatically present note and highlight actions. Preserve the existing workflow for adding, editing, saving, rendering, and deleting notes and highlights, as well as the hover-delete entry on marked passages. Do not require right-click context menus, do not remove the note popup, and do not remove existing interaction steps.

---

## 红线三：听写输入框、自适应排版、听写进度条与错误反馈 / Red line 3: Dictation input box, typography, progress rail, and error feedback

中文：完整保留当前听写输入框的布局、大框设计、自适应字号（DictationAnswerMetrics）、长单词自动缩放与折行、居中对齐、圆角、主题色、聚焦效果、即时输入判定与焦点行为。必须完整保留错误反馈动效：左右轻微摇晃（DictationShakeEffect）、红色闪烁（dictationErrorFlash）、红光外发光阴影与错误态自动清除。不得用普通小输入框替代，不得改变输入判定和练习数据同步，不得使用延迟输入、禁用控件或强制跳词掩盖性能问题。必须保留常驻听写进度条（dictationProgressRail），包含精确百分比、已完成/总数、剩余及今日词数统计。

English: Preserve the dictation input box layout, oversized field styling, adaptive font metrics (DictationAnswerMetrics), long-word auto-shrink and wrapping, center alignment, rounded corners, active theme tint, focus feedback, immediate text verification, and focus semantics. Preserve all error feedback motion: horizontal shake (DictationShakeEffect), red border flash (dictationErrorFlash), red glow shadow, and error text clearing. Do not substitute a generic small text field, do not alter practice verification, and do not introduce delayed inputs. Preserve the persistent dictation progress rail (dictationProgressRail) with real-time percentage, completed/total count, remaining, and today count.

---

## 红线四：听力分类布局与错词复习布局 / Red line 4: Listening category and wrong word review layouts

中文：听力分类布局（专用的三级访达文件夹树、微拟物磨砂玻璃卡片、面包屑导航、一键听写入口）与错词复习布局（按题库筛选、错词统计、高频易错词智能收录）必须严格保护。分类卡片必须具备精细的 SF Symbol 类别徽标、高亮渐变、词数胶囊及一键听写操作，禁止降级为普通平淡列表或无胶囊的简陋视图。

English: Preserve the dedicated listening category layout (three-level Finder directory tree, tactile frosted glass cards, breadcrumb path navigation, quick-dictation entry) and the wrong words review layout (deck filtering, error metrics, high-frequency mistake tracking). Category cards must retain their refined SF Symbol badges, ambient gradient glow, word-count pill chips, and direct dictation action; do not downgrade into plain unstyled lists.

---

## 红线五：调色与设计 Token 文件严禁擅自修改 / Red line 5: Theme, palette, and design token protection

中文：调色与样式基础文件（`Theme.swift`、`MonetTheme.swift`、`LumaDesignTokens.swift`、`StudyAppearance.swift`）严格受保护：
1. 五大经典主题（暖纸白 `.paper`、鼠尾草绿 `.mint`、樱花粉 `.rose`、午夜蓝 `.midnight`、纯黑 `.black`）的纸张色、表面色、文字色、强调色定义与高对比度（WCAG AA）必须严格保持。
2. Monet 动态取色算法与 Material Color Utilities 桥接必须完整保留。
3. 严禁擅自修改颜色 HEX 值、删除主题枚举或破坏主题切换响应广播机制。

English: Styling and color foundations (`Theme.swift`, `MonetTheme.swift`, `LumaDesignTokens.swift`, `StudyAppearance.swift`) are strictly protected:
1. Preserve all five classic themes (Paper `.paper`, Mint `.mint`, Rose `.rose`, Midnight `.midnight`, Black `.black`) along with their paper, surface, text, and accent color definitions meeting WCAG AA contrast standards.
2. Preserve Monet dynamic seed extraction and Material Color Utilities scheme bridges.
3. Do not modify color HEX values, delete theme cases, or disrupt theme-switching event propagation.

中文：V.1.0.1 按用户明确要求恢复红黄绿中心线对齐与误删的错词中心，并合并错词操作菜单，分类保持独立入口，其他红线保持。
English: V.1.0.1 restores traffic-light alignment and the deleted wrong-words center, and consolidates its actions, as explicitly requested by the owner. All other red lines remain in effect.

中文：本次用户进一步明确要求：分类保持独立入口，与词库、错词并列、删除分类卡片说明小字及旁边文字，并优化分类切换的重复计算。这些指定修改不授权改变写作高亮、听写输入框、进度条或错误动效。
English: The owner additionally requested keeping Categories as a standalone navigation entry alongside Vocabulary and Wrong Words, removing category-card explanatory and adjacent text, and reducing redundant folder calculations. These specific changes do not authorize changes to writing highlights, dictation input, progress, or error feedback.

中文：最新明确要求：恢复顶部独立“分类”按钮，直接打开 V1.0.0 的三级文件夹浏览；不得再次合并进错词菜单。保留三级目录全部功能，只移除多余解释文字。
English: The latest explicit requirement restores the standalone Categories button opening the V1.0.0 three-level folder browser. Do not merge it into Wrong Words again. Preserve all folder functionality and remove only redundant explanatory copy.

## 最新授权：三套独立主题及特色错误反馈 / Latest authorization: independent themes and distinctive error feedback

中文：用户明确要求加入并优化 Monet、Space、Manga 三套独立视觉系统，并要求错误动效各具特点。原有五种经典配色归 Monet，色值及算法不变；Space 独立深空色板、玻璃参数和取色缓存；Manga 使用单色纸墨、网点与线框，不启用苹果液态玻璃。三套偏好分别保存。不得把这次主题接入理解为重构会话、重排红黄绿或改动输入判定的授权。

English: The owner explicitly authorized the integration and optimization of three independent visual systems—Monet, Space, and Manga—and distinctive error feedback for each. The original five classic palettes remain within Monet with their colors and algorithms preserved. Space has independent cosmic roles, material preferences, and image-cache state. Manga uses monochrome paper, screentone, and ink frames, bypassing Apple Liquid Glass. Preferences are stored independently. This authorization does not permit session reconstruction, traffic-light rearrangement, or answer-evaluation changes.

中文：错误反馈设计以本次明确要求为准：Monet 颜料晕染，Space 雷达扫描警报，Manga 分镜冲击。错误红色和触觉反馈保留；减少动态效果时用静态提示。允许改变错误状态的呈现与节奏，但不允许改变输入框布局尺寸、字体自适应、提交、焦点、听写进度、错词循环、写作高亮或阅读定位。反馈只在答错后短暂播放，禁止常驻动画或循环计时器。

English: The explicit error-feedback designs are Monet pigment bloom, Space radar alarm, and Manga editorial impact. Preserve red error semantics and haptics, with static feedback under Reduce Motion. Error presentation and timing may change; input dimensions, adaptive typography, submission, focus, progress, wrong-word scheduling, writing highlights, and reading anchors must remain intact. Feedback is brief and error-triggered, with no perpetual animation or repeating timer.


## 最新授权（1.8.0）：主题重设计 / Latest authorization (1.8.0): theme redesign

中文：用户明确授权（2026-11-11）：
1. 红线一放宽：阅读顶栏七键可按主题排布为「左四右三分组」「七键合并长栏」「两组居中浮岛」三种之一；七键数量、功能、组内顺序、快捷键、悬停显隐规则、红黄绿原生按钮及 30pt 中心线保持不变。
2. 红线五放宽：五个经典配色的强调色与表面色可修改；纸张色须与 Reader.js 保持一致。
3. 侧栏可按主题位于窗口左侧或右侧；书库标题区、书封装饰、主题标题字体可按主题变化。
4. 听写输入框的尺寸与位置必须保持不变（练习模式侧栏宽度为 0）；红线二、三、四其余内容继续有效。
English: The owner authorized per-theme layouts (reader header arrangement, sidebar edge, library heading, shelf ornaments) and classic accent/surface colour changes. The seven reader actions keep their count, behaviour, in-group order and hover rules; the dictation input size and position stay unchanged; red lines 2–4 remain in force.
