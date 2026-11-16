import Foundation
import Testing
@testable import LumaCore

/// 听写会话状态机的行为契约：这里是 macOS 与 iPhone 共用的那一份实现，
/// 判对判错、错词插回位置、长措辞只差虚词，全都在这一层决定。
@Suite("听写会话状态机")
struct DictationSessionTests {
    private func word(_ text: String, deck: String = "test.deck") -> VocabularyWord {
        VocabularyWord(id: "\(deck).\(text)", word: text, definitionZH: "", deckID: deck, deckTitle: deck)
    }

    private func words(_ texts: [String]) -> [VocabularyWord] {
        texts.map { word($0) }
    }

    private func machine(_ texts: [String], mode: DictationSessionMode = .newTask) -> DictationSessionStateMachine {
        DictationSessionStateMachine(mode: mode, dateString: "2026-11-16", initialWords: words(texts))
    }

    @Test("第一次就拼对：记一条首错为 false 的日志，词毕业")
    func correctOnFirstAttemptCompletes() {
        var session = machine(["atmosphere", "hydrosphere", "lithosphere"])
        let first = session.pendingQueue[0]

        let outcome = session.submitAnswer("atmosphere", durationSeconds: 2.0)
        #expect(outcome == .correct(exitedWrongQueue: false))
        #expect(session.completedWordIDs.contains(first.id))
        #expect(session.attemptLogs.count == 1)
        #expect(session.attemptLogs[0].isCorrect)
        #expect(session.attemptLogs[0].isFirstAttemptInSession)
        #expect(session.currentWord?.word == "hydrosphere")
    }

    @Test("同一个词第二次拼对：日志标明不是首次尝试")
    func secondAttemptIsNotFirst() {
        var session = machine(["atmosphere", "hydrosphere"])
        _ = session.submitAnswer("zzq", durationSeconds: 2.0, newWordStrategy: .repeating)
        _ = session.submitAnswer("atmosphere", durationSeconds: 2.0, newWordStrategy: .repeating)

        let logs = session.attemptLogs.filter { $0.word == "atmosphere" }
        #expect(logs.count == 2)
        #expect(logs[0].isFirstAttemptInSession)
        #expect(!logs[1].isFirstAttemptInSession)
    }

    @Test("快速过词答错：立刻跳过、队列长度不变，词按经济间隔插回后面")
    func quickStrategySkipsAndRequeuesLater() {
        var session = machine(["atmosphere", "hydrosphere", "lithosphere", "mesosphere"])
        let before = session.pendingQueue.count
        let firstID = session.pendingQueue[0].id

        let outcome = session.submitAnswer("zzq", durationSeconds: 2.0, newWordStrategy: .quick)
        #expect(outcome == .skippedIncorrect)
        #expect(session.pendingQueue.count == before, "插回后面，不该变短")
        #expect(session.pendingQueue.first?.id != firstID, "不该还停在原来这个词上")
        #expect(session.pendingQueue.contains { $0.id == firstID }, "错词要留在队列里等复习")
        #expect(session.completedWordIDs.isEmpty)
        #expect(session.sessionErrorCounts[firstID] == 1)
    }

    @Test("循环复习答错：停在原地等订正，拼对后按 5 个词的间隔插回")
    func repeatingStrategyRequiresCorrection() {
        var session = machine((0..<8).map { "word\($0)" })
        let firstID = session.pendingQueue[0].id

        let miss = session.submitAnswer("zzq", durationSeconds: 2.0, newWordStrategy: .repeating)
        #expect(miss == .needsCorrection(errorCountForWordToday: 1))
        #expect(session.requiresCorrection, "订正阶段要停在同一个词上")

        let fixed = session.submitAnswer("word0", durationSeconds: 2.0, newWordStrategy: .repeating)
        if case .requeuedForRetry(_, let offset) = fixed {
            #expect(offset == 5, "订正确认步是 5 个词，实际 \(offset)")
        } else {
            Issue.record("订正拼对后应返回 requeuedForRetry，实际 \(String(describing: fixed))")
        }
        #expect(session.pendingQueue.count == 8)
        #expect(session.pendingQueue[5].id == firstID, "错词应按 5 词间隔插回")
    }

    @Test("同一个词连错 6 次：记成顽固词，且不算完成")
    func repeatedErrorsBecomeStubborn() {
        var session = machine(["alpha", "beta", "gamma"])
        let firstID = session.pendingQueue[0].id

        var lastOutcome: DictationSubmitOutcome?
        for _ in 0..<6 {
            lastOutcome = session.submitAnswer("zzq", durationSeconds: 2.0, newWordStrategy: .repeating)
        }

        if case .promotedToStubbornWords(let count)? = lastOutcome {
            #expect(count >= 6)
        } else {
            Issue.record("连错 6 次应记为顽固词，实际 \(String(describing: lastOutcome))")
        }
        #expect(session.stubbornWordsMap[firstID]?.errorCount == 6)
        #expect(!session.completedWordIDs.contains(firstID), "顽固词不该被当成已掌握")
    }

    @Test("长措辞只差虚词：只提示重拼一次，不计错")
    func longPhraseMinorSlipIsNotAnError() {
        var session = machine(["keep an eye on the ball", "atmosphere"])

        let outcome = session.submitAnswer("keep an eye in the ball", durationSeconds: 2.0, newWordStrategy: .quick)
        #expect(outcome == .needsPhraseFix(fragment: "on"))
        #expect(session.sessionErrorCounts.isEmpty, "虚词小错不该计错")
        #expect(session.requiresCorrection)

        let fixed = session.submitAnswer("keep an eye on the ball", durationSeconds: 2.0, newWordStrategy: .quick)
        #expect(fixed == .correct(exitedWrongQueue: false))
    }

    @Test("短搭配错实词：照常算错")
    func shortCollocationMissCounts() {
        var session = machine(["in charge of", "atmosphere"])
        let outcome = session.submitAnswer("in charge off", durationSeconds: 2.0, newWordStrategy: .quick)
        #expect(outcome == .skippedIncorrect)
        #expect(session.sessionErrorCounts.values.reduce(0, +) == 1)
    }

    @Test("提前结束：队列清空，已完成的词保留")
    func skipRemainingFinishesRound() {
        var session = machine(["a", "b", "c"])
        _ = session.submitAnswer("a", durationSeconds: 2.0)
        session.skipRemaining()

        #expect(session.pendingQueue.isEmpty)
        #expect(session.currentWord == nil)
        #expect(session.completedWordIDs.count == 1)
        #expect(session.pendingQueue.isEmpty)
    }

    @Test("编码解码：续练同一轮时进度不丢")
    func codingRoundTripKeepsProgress() throws {
        var session = machine(["atmosphere", "hydrosphere", "lithosphere"])
        _ = session.submitAnswer("atmosphere", durationSeconds: 2.0)
        _ = session.submitAnswer("zzq", durationSeconds: 2.0, newWordStrategy: .quick)

        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(DictationSessionStateMachine.self, from: data)

        #expect(restored.sessionID == session.sessionID)
        #expect(restored.completedWordIDs == session.completedWordIDs)
        #expect(restored.pendingQueue.map(\.id) == session.pendingQueue.map(\.id))
        #expect(restored.attemptLogs.count == session.attemptLogs.count)
    }
}
