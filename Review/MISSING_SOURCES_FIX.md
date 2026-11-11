# 缺失诊断源码修正

用户 Mac 的第二次构建记录中已无 DictationAnswerFont 隔离错误，编译推进到主 App 后提示 DiagnosticManager、DiagnosticField、DiagnosticsSettingsView 等符号缺失。

已确认上传基线 ZIP 及上一版源码包都缺少 Sources/LumaReader/Diagnostics 与 ThirdParty/Diagnostics。此前只对现有文件比对，未检测到这些缺失。本版从 BASE_COMMIT.txt 指定的 fbc23dc07e2a2c89698554c255dd462fce4359ba 原样恢复 9 个 Swift 源码文件、5 份许可证、1 份来源清单。恢复源码逐个校验 Git blob SHA；没有用空实现替代诊断，也没有删除业务调用。源码和许可证不是用户运行日志。

日志另在 ContentView.swift 的云同步统计长插值处报类型检查超时。本版将相同的书籍、批注、书签计数拆成有明确返回 String 的 cloudSyncScopeText 计算属性，保留原文案与统计数据源。

新增 Scripts/check-source-completeness.py，离线核对基准提交的全部 Sources/ 和 ThirdParty/ 文件是否存在。本版 84 项存在性核对、现有 check-diagnostics.py 和原听写保护区核对已执行。未进行 Mac 编译、启动或视觉验收，不能宣称安装成功。

完整恢复清单见 Review/RESTORED_FILES.json；新增源码均来自该固定提交，不导入远端其他 UI 改动。
