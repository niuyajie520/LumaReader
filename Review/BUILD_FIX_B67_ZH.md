# 1.6.1 B67 编译修复

日志 build-20261110-190953.log 的阻塞错误位于 LumaStudyCenterAllInOne.swift:3822：sending note risks causing data races。上一版将带有非 Sendable userInfo 的 Notification 捕获进 MainActor.assumeIsolated 闭包。

🟡 修改：在通知回调原上下文中读取 name/userInfo，计算 Bool；主线程闭包只捕获 Bool 与受 MainActor 隔离的 self。继续使用 queue:.main，不用 unchecked Sendable 或关闭 Swift 6 检查。

🛡️ 保护：除上述通知回调和版本/报告文件外，与 B66 全部文件逐字一致。保持后台释放、休眠清理、性能优化、重播、快捷键、主题和学习数据处理不变。

🟢 交付：完整 Source ZIP，可在 Mac 本机编译；并可针对用户日志所指的 B66 源码目录应用同一处补丁以复用已有构建缓存。

🔴 验证边界：完成 Swift 语法解析与差异/打包检查；原有 18 项后端测试在 B66 已通过，本次未修改后端。未在此环境重新编译 macOS 原生 App。日志里的第三方弃用、未使用值等 warning 不是这次构建退出的原因，未为消除 warning 扩大修改范围。

建议提交信息：fix: extract sendable notification values before main actor isolation
