// 让既有代码不用逐个文件改 import：StudyKit 对外重新导出共享内核。
@_exported import LumaCore

// 听写状态机与配套模型已经从 LumaCore 提供，这里用别名让既有调用点保持不变。
public typealias DictationSessionStateMachine = LumaCore.DictationSessionStateMachine
public typealias DictationSessionMode = LumaCore.DictationSessionMode
public typealias DictationAttemptLog = LumaCore.DictationAttemptLog
public typealias DictationSubmitOutcome = LumaCore.DictationSubmitOutcome
public typealias DictationTuning = LumaCore.DictationTuning
public typealias StubbornWordRecord = LumaCore.StubbornWordRecord
public typealias SlowReactionWordRecord = LumaCore.SlowReactionWordRecord
public typealias NewWordDictationStrategy = LumaCore.NewWordDictationStrategy
