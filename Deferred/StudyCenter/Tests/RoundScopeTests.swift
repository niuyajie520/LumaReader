import Foundation
import Testing
@testable import LumaReaderStudyKit

/// v4 硬约束 2.4D 的四个验收场景：本轮 = deckID + roundID，任何统计都不能跨轮、跨词本。
struct RoundScopeTests {
    private func log(_ wordID: String, deck: String, round: UUID,
                     correct: Bool = false, first: Bool = true, day: String = "2026-11-15") -> DictationAttemptLog {
        DictationAttemptLog(
            id: UUID(), sessionID: round, mode: .newTask, wordID: wordID,
            word: wordID, deckID: deck, userTyped: correct ? wordID : "x",
            isCorrect: correct, isFirstAttemptInSession: first,
            sessionErrorCountForWord: correct ? 0 : 1,
            timestamp: Date(), dateString: day, durationSeconds: 2
        )
    }

    private func word(_ id: String, deck: String) -> VocabularyWord {
        VocabularyWord(id: id, word: id, definitionZH: "释义", deckID: deck, deckTitle: deck)
    }

    /// D1：同一词本第二轮从头开始，第一轮错词数为 0（同一天、同一词本）。
    @Test func secondRoundOfSameDeckStartsWithNoMistakes() {
        let first = UUID(), second = UUID()
        let logs = [
            log("a", deck: "deck-3", round: first),
            log("b", deck: "deck-3", round: first),
            log("c", deck: "deck-3", round: first),
        ]
        let scope = RoundScope(deckIDs: ["deck-3"], roundID: second)
        #expect(scope.logs(logs).isEmpty)
        #expect(scope.firstAttemptCount(in: logs) == 0)
        #expect(scope.wordIDs(in: logs).isEmpty)
    }

    /// D2：从第 3 个词本切到第 8 个词本，同一轮 ID 也不能带出第 3 个词本的错题。
    @Test func switchingDeckDropsOtherDeckMistakes() {
        let round = UUID()
        let logs = [
            log("a", deck: "deck-3", round: round),
            log("z", deck: "deck-8", round: round),
        ]
        let scope = RoundScope(deckIDs: ["deck-8"], roundID: round)
        #expect(scope.logs(logs).map(\.wordID) == ["z"])
    }

    /// D3：续练沿用同一 roundID；退出期间其他轮次写入的错题不并进来。
    @Test func resumedRoundKeepsIDAndIgnoresOtherRounds() throws {
        let session = DictationSessionStateMachine(
            dateString: "2026-11-15",
            initialWords: [word("a", deck: "deck-3"), word("b", deck: "deck-3")],
            originDeck: "deck-3"
        )
        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(DictationSessionStateMachine.self, from: data)
        #expect(restored.roundID == session.roundID)

        let other = UUID()
        let logs = [
            log("a", deck: "deck-3", round: session.roundID),
            log("b", deck: "deck-3", round: other),
        ]
        let scope = RoundScope(deckIDs: ["deck-3"], roundID: restored.roundID)
        #expect(scope.logs(logs).map(\.wordID) == ["a"])
    }

    /// D4：错词复习一个没有错词的词本，队列就是空的，不拿别的词补。
    @Test func emptyReviewStaysEmpty() {
        let session = DictationSessionStateMachine(
            mode: .wrongWordReview,
            dateString: "2026-11-15",
            initialWords: [],
            originDeck: "deck-8"
        )
        #expect(session.pendingQueue.isEmpty)
        #expect(session.currentWord == nil)
    }

    /// 本轮已听只算首次尝试，订正不算。
    @Test func heardCountUsesFirstAttemptsOnly() {
        let round = UUID()
        let logs = [
            log("a", deck: "deck-3", round: round, correct: false, first: true),
            log("a", deck: "deck-3", round: round, correct: true, first: false),
            log("b", deck: "deck-3", round: round, correct: true, first: true),
        ]
        #expect(RoundScope(deckIDs: ["deck-3"], roundID: round).firstAttemptCount(in: logs) == 2)
    }
}
