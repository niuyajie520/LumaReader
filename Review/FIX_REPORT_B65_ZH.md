# LumaReader 1.5.0 · B65 修复说明

## 结论与证据边界

已按上传的 1.4.3 B64 完整源码修改。尚未获取用户 Mac 的事件记录或系统诊断，不能认定“鼠标点击失效但键盘有效”与“强退后再次出现”的唯一根因。源码未发现 CGEventTap、禁止切换应用的 kiosk 模式、注册 App 登录项或 App 自重启循环。语音后台进程与主 App 是不同进程，残留语音服务本身不能证明主 App 自动重启。

## 🟡 修改

- LumaReaderApp.swift：移除失活/退出时主线程 malloc_zone_pressure_relief；增加独立的系统睡眠、显示器睡眠和会话锁定状态；增加重复实例检查及禁止会话恢复重启请求。
- ContentView.swift / LibraryStore.swift：失活保存合并为一个入口，暂停待执行云同步/取色；云盘统计目录扫描改到 utility 任务。正在执行的文件传输不会被强杀，可能运行到本次操作结束。
- ReaderChromeMonitor.swift：后台、最小化、不可见、睡眠时注销 10Hz 轮询定时器，不在后台反复调整原生窗口控件。
- StudyHome.swift：失活/睡眠时停播、暂停听写；重新激活后由原有播放按钮继续，避免自动播报与重新抢输入焦点。
- LumaStudyCenterAllInOne.swift：直接启动并持有自己的 Python 语音子进程，不再 nohup；睡眠/退出终止自己启动的进程；强退后子进程检查 owner PID 并退出。已存在且不属于本次启动的外部服务不随意终止。
- audio_priority_queue.py / kokoro_neural_daemon.py：单推理队列最多 32 个待处理项，等待最多 60 秒；HTTP 并发最多 8，读超时 65 秒，JSON 请求上限 256 KiB；取消未开始任务；外部语音转换加超时。已开始的单次 ONNX 推理在普通切后台时可能运行到完成，睡眠时自有进程会终止。
- DiagnosticManager.swift / DiagnosticsSettingsView.swift：崩溃开关独立于详细日志，开启后当次安装；安装失败显示原因，重复开启不会重复安装。已经安装的处理器仍需重启才能彻底关闭；MetricKit 是延迟诊断，不是系统鼠标拦截检测器。
- 只移除 Kokoro 82M：删除旧嵌入推理、安装器、权重检测和模型目录入口；服务拒绝旧模型 ID。安装脚本仅清理 LumaReader/KokoroEngine 与 KokoroTTS 下已知 82M 权重及选中模型配置，保留 Kitten Micro 40M、Nano 15M、共享 Python 环境、学习数据。
- Install.command / Install-LumaReader.command：停止改写用户目录下其他历史源码副本；用普通 open 替代 open -n。安装仍会按现有流程关闭旧 App 并替换应用程序。

## 🟢 新增

- CloudFileManager.swift：在已有云盘页加入类似文件管理器的浏览器，管理已授权云盘文件夹里的所有常见文件类型；进入/返回目录、搜索当前目录、上传、建文件夹、打开编辑、重命名、在 Finder 显示、确认后移到废纸篓。不是直接调用远程云 API，依靠本地云盘客户端同步。
- 文件操作不覆盖同名文件，拒绝路径越界及通过符号链接操作其他目录。文件修改时阻止启动新的 App 云同步；删除同步文件可能由其他设备快照重新生成，本机书库图书删除仍用原有书库操作。
- Diagnose-Mac.command：只读采集相关 PID/父进程、启动配置、登录后台项匹配和窗口层级（不采集窗口标题），输出到下载目录。用于确认哪个进程重新启动、是否多个实例或窗口遮挡。

## 🛡️ 已检查的保护范围

Theme.swift、MonetTheme.swift、LumaDesignTokens.swift、StudyAppearance.swift、NativeWindowControls.swift、Reader.js、Reader.css 与上传基线逐字节一致。既有顶栏排列、七键、听写输入框、进度条、错误动效、三级分类、写作高亮实现不重排。Swift 修改文件通过 tree-sitter 语法检查；这不等于 SDK 类型检查。

## 测试

- 8 项 Python 后端回归：前台优先与去重、取消后台预加载、队列容量、请求超时、暂停时取消待执行请求、只保留两种 Kitten 模型、旧选择迁移、定向删除与符号链接文件保护：通过。
- check-source-completeness.py、check-diagnostics.py、check-ui-resources.py、shell 语法、git diff --check：通过。
- 新增 CloudFileOperationsTests.swift，覆盖越界/同名保护、符号链接与多类型文件列表；未运行原生测试。

## 🔴 未验证

此环境没有 Apple macOS SDK/Xcode，未成功编译、签名、安装本次原生 App；未执行 Mac 实机交互、主题截图比较、强退/睡眠/唤醒复现。没有 Instruments 前后实测，不能提供性能提升百分比或声称已根治鼠标失效。若安装报错，提供安装日志；若鼠标失效再发生，用键盘运行 Diagnose-Mac.command 后提供输出。

建议提交信息：fix: harden lifecycle and speech runtime; retire Kokoro 82M; add cloud file management
