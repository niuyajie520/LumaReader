import Foundation

// 本文件只保留手机端的 UI 层封装：真正的判题、词距、错词调度都在 LumaCore。

// MARK: - 判题

enum DictationStrategy: String, CaseIterable, Identifiable {
    case quick, repeating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "快速过词"
        case .repeating: return "循环复习"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "每个词先过一遍，错的隔 10 个词回来重听。适合先扫一遍新单元。"
        case .repeating: return "同一轮里按 5 / 55 / 155 / 255 个词的间距重复四遍，拼对第四遍才毕业。"
        }
    }
}

// MARK: - 本轮状态机（LumaCore 的薄封装）

/// 手机端的听写一轮：真正的队列与调度由 `LumaCore.DictationSessionStateMachine` 负责，
/// 这里只做 `@Observable` 包装，好让 SwiftUI 跟着刷新。
@Observable
final class DictationSession {

    enum Phase: Equatable {
        case idle
        case awaitingAnswer
        case correcting      // 已判错，等用户照着正确拼写重敲一次
        case finished
    }

    let deckID: String
    let deckTitle: String
    let strategy: DictationStrategy
    let startedAt = Date()

    private(set) var machine: DictationSessionStateMachine
    private var drainedLogCount = 0

    var sessionID: UUID { machine.sessionID }
    var mode: DictationSessionMode { machine.mode }

    var current: VocabularyWord? { machine.currentWord }
    var queue: [VocabularyWord] { machine.pendingQueue }
    var completedWordIDs: Set<String> { machine.completedWordIDs }
    var errorCountByWordID: [String: Int] { machine.sessionErrorCounts }
    var attemptedWordIDs: Set<String> { Set(machine.attemptLogs.map(\.wordID)) }
    var wrongWordIDs: Set<String> { Set(machine.attemptLogs.filter { !$0.isCorrect }.map(\.wordID)) }

    var totalWords: Int { machine.pendingQueue.count + machine.completedWordIDs.count }
    var remainingCount: Int { machine.pendingQueue.count }
    var isFinished: Bool { machine.isSessionFinished }
    var correctCount: Int { machine.attemptLogs.filter(\.isCorrect).count }
    var wrongCount: Int { machine.attemptLogs.filter { !$0.isCorrect }.count }

    var phase: Phase {
        if machine.isSessionFinished { return .finished }
        if machine.requiresCorrection { return .correcting }
        return machine.currentWord == nil ? .idle : .awaitingAnswer
    }

    init(deck: VocabularyDeck, words: [VocabularyWord], strategy: DictationStrategy, sessionID: UUID = UUID()) {
        self.deckID = deck.id
        self.deckTitle = deck.title
        self.strategy = strategy
        self.machine = DictationSessionStateMachine(
            sessionID: sessionID,
            mode: .newTask,
            dateString: JSONDate.dayString(Date()),
            initialWords: words,
            originDeck: deck.id
        )
    }

    /// 提交一次听写；调用方负责朗读下一词、反馈动画与进度记录。
    @discardableResult
    func submit(_ input: String, durationSeconds: Double) -> DictationSubmitOutcome? {
        machine.submitAnswer(
            input,
            durationSeconds: durationSeconds,
            retryOffset: nil,
            newWordStrategy: strategy == .repeating ? .repeating : .quick
        )
    }

    /// 取走还没落盘的日志（UI 写完进度后调用）。
    func drainLogs() -> [DictationAttemptLog] {
        let logs = machine.attemptLogs
        guard drainedLogCount < logs.count else { return [] }
        let fresh = Array(logs[drainedLogCount...])
        drainedLogCount = logs.count
        return fresh
    }

    func finish() {
        machine.skipRemaining()
    }
}
