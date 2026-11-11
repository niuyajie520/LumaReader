# LumaReader 最终源码交接（本次对话最终快照）

这是一份完整 macOS 工程源码快照，不是 iOS 工程，也不是编译好的应用。

基于 GitHub 的 work/study-center-integration 分支，叠加本次对话提供的源码及后续补丁。包含 Package.swift、Sources、Deferred/StudyCenter、Vendor、Resources、Tests 和 Scripts。

## 已合入的后续调整

- 阅读顶栏悬停、全屏避让及面板操作保持显示。
- 多词本错词合练、随机顺序、各词本进度恢复和上一个词。
- 导入弹窗布局修复。
- 每日目标设置、练习计时、后台暂停锁定输入、回前台自动继续。
- 错词自动展开中文释义和正确拼写，仍需手动订正。
- 限制语音预载、合并高频保存、原生语速及音频边界处理、过期请求取消。
- 空白按 Enter 计错；侧栏“听力”始终先进入词库主页，选择词本再继续练习。
- 同词同声线复用1.0×硬盘音频，原生不变调变速；最多10词滚动缓冲、当前词优先及重复任务合并。
- 通过实际播放结束回调记录反应时间，避免把生成等待算成慢反应。
- 听写专注模式延后新的图书导入、封面生成和云同步；保留正常数据保存。
- 本地模型选择器接入 Kitten Nano int8、Kitten Micro 和 Kokoro。
- 模型互斥加载：旧任务版本失效，等待在途推理完成后卸载旧模型，再加载新模型；禁用第二套内嵌Kokoro进程自动启动。
- 重播准备中复用当前请求，显示准备状态；网络/生成失败显示错误。

## 实际状态

未运行 Swift 编译、Swift 测试或 macOS 界面验收。仅做过补丁应用、Python语法及调度/互斥模型模拟验证。附带的 Tests 含历史测试，部分预期可能需要随新交互调整。
词尾叹气/杂音尚未通过具体单词录音定位，不应当视为已经解决。
FSRS 和“错词三次间隔正确”的方案此前仅讨论，尚未实现；本包仍保留现有复习调度。
模型权重、Python 虚拟环境、个人学习记录、API 密钥及本机缓存不在包内。
Edge/Google 联网语音仅讨论，未接入。本包是现有代码最终快照，不代表已经发布或验收通过的正式版本。
远端基准提交请见 BASE_COMMIT.txt；本地补丁没有推送到 GitHub。

## 在 Mac 上继续开发

优先直接打开本文件夹的 Package.swift，或在工程目录运行 swift build。
应用打包入口为 Scripts/build-macos.sh。
根目录旧的“继续上次安装.command”等脚本是历史安装流程，会重新拉取/覆盖源码；开发本快照时不要运行它们。

## 小模型相关代码

- `Deferred/StudyCenter/LumaStudyCenterAllInOne.swift`：模型选择UI、客户端切换与重播。
- `Deferred/StudyCenter/EmbeddedNeuralSpeechEngine.swift`：原生音频播放、变速和播放结束回调。
- `Scripts/kokoro_neural_daemon.py`：本地HTTP语音服务及音频缓存。
- `Scripts/audio_priority_queue.py`：单任务优先队列和滚动预载。
- `Scripts/exclusive_tts.py`：模型适配、互斥加载、旧任务失效。
- `Scripts/setup_kitten.py`：下载Nano/Micro到硬盘，不加载推理。
- `Scripts/small-model-dependencies.txt`：轻量Python环境依赖说明。

语音依赖仍属于macOS/Python实现。Swift包构建不会自动安装Python依赖或下载权重。模型切换时采用同服务内卸载，不是强制杀死整个操作系统进程。

## 自己迁移 iOS

可以复用模型、导入解析、学习规则和部分 SwiftUI 界面，但需要自己建立 iOS App target。
AppKit、NSWindow、NSSavePanel/NSOpenPanel、桌面菜单和键盘监控需要替换为 iOS 对应交互。
文件路径、应用生命周期及依赖平台声明需要适配。
现有 Python 子进程/本地 Kokoro 守护进程方案不能原样搬到 iOS；可评估系统语音、兼容 iOS 的推理库或远端服务。
本次仅交接源码，没有实施 iOS 迁移。
