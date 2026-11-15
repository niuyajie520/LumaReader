import Foundation
import XCTest
@testable import LumaReaderStudyKit

final class DictationRollingQueueTests: XCTestCase {
    private func word(_ index: Int, deck: String = "unit-A") -> VocabularyWord {
        VocabularyWord(id: "\(deck)-\(index)", word: "word\(index)", definitionZH: "", deckID: deck, deckTitle: deck)
    }

    func testNewWordCorrectionRollsOnlyWithinSelectedUnitAndKeepsQueuesSeparate() {
        let words = (0..<15).map { word($0) }
        var session = DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-14", initialWords: words, originDeck: "unit-A")
        XCTAssertEqual(session.submitAnswer("wrong"), .needsCorrection(errorCountForWordToday: 1))
        XCTAssertEqual(session.submitAnswer("word0"), .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 10))
        XCTAssertEqual(session.pendingWrongRetryWords.map(\.id), ["unit-A-0"])
        XCTAssertEqual(session.pendingLearningWords.count, 14)
        XCTAssertTrue(session.pendingQueue.allSatisfy { $0.deckID == "unit-A" })
        XCTAssertEqual(session.originDeck, "unit-A")
    }

    func testThirdCycleMistakeKeepsStageAcrossCorrectionAndRestore() throws {
        let words = (0..<80).map { word($0) }
        var session = DictationSessionStateMachine(mode: .wrongWordReview, dateString: "2026-11-14", initialWords: words)
        _ = session.submitAnswer("wrong")
        _ = session.submitAnswer("word0")
        for cycle in 1...2 {
            while session.currentWord?.id != "unit-A-0" { _ = session.submitAnswer(session.currentWord!.word) }
            XCTAssertEqual(session.wrongRetryCycleByWordID["unit-A-0"], cycle)
            _ = session.submitAnswer("word0")
        }
        while session.currentWord?.id != "unit-A-0" { _ = session.submitAnswer(session.currentWord!.word) }
        XCTAssertEqual(session.wrongRetryCycleByWordID["unit-A-0"], 3)
        _ = session.submitAnswer("wrong")
        let restored = try JSONDecoder().decode(DictationSessionStateMachine.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.roundID, session.roundID)
        XCTAssertEqual(restored.wrongRetryCycleByWordID["unit-A-0"], 3)
        session = restored
        _ = session.submitAnswer("word0")
        XCTAssertEqual(session.wrongRetryCycleByWordID["unit-A-0"], 3)
    }

    func testNewRoundDoesNotImportSameDayErrorsAndStartsAtHead() {
        let words = (0..<15).map { word($0) }
        var old = DictationSessionStateMachine(dateString: "2026-11-14", initialWords: words)
        _ = old.submitAnswer("wrong")
        var fresh = DictationSessionStateMachine(dateString: "2026-11-14", initialWords: words, previousLogs: old.attemptLogs)
        XCTAssertNotEqual(fresh.roundID, old.roundID)
        XCTAssertEqual(fresh.currentWord?.id, "unit-A-0")
        XCTAssertTrue(fresh.sessionErrorCounts.isEmpty)
        XCTAssertEqual(fresh.submitAnswer("wrong"), .needsCorrection(errorCountForWordToday: 1))
    }

    func testQuickModeSkipsImmediatelyButRecallsWrongWordBeforeCompletion() throws {
        let words = (0..<15).map { word($0) }
        var session = DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-14", initialWords: words, originDeck: "unit-A")
        XCTAssertEqual(session.submitAnswer("wrong", newWordStrategy: .quick), .skippedIncorrect)
        XCTAssertEqual(session.currentWord?.id, "unit-A-1")
        XCTAssertFalse(session.requiresCorrection)
        XCTAssertFalse(session.completedWordIDs.contains("unit-A-0"))
        XCTAssertEqual(session.pendingWrongRetryWords.map(\.id), ["unit-A-0"])
        XCTAssertEqual(session.pendingLearningWords.count, 14)
        XCTAssertEqual(session.pendingQueue.firstIndex { $0.id == "unit-A-0" }, 10)
        session = try JSONDecoder().decode(DictationSessionStateMachine.self, from: JSONEncoder().encode(session))
        while session.currentWord?.id != "unit-A-0" { _ = session.submitAnswer(session.currentWord!.word, newWordStrategy: .quick) }
        XCTAssertEqual(session.submitAnswer("word0", newWordStrategy: .quick), .correct(exitedWrongQueue: true))
        XCTAssertTrue(session.completedWordIDs.contains("unit-A-0"))
        XCTAssertFalse(session.activeWrongRetrySet.contains("unit-A-0"))
        XCTAssertFalse(session.pendingQueue.contains { $0.id == "unit-A-0" })
    }

    func testQuickModeRepeatedMissKeepsWordPendingForLaterRecall() {
        let words = (0..<15).map { word($0) }
        var session = DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-14", initialWords: words)
        _ = session.submitAnswer("wrong", newWordStrategy: .quick)
        while session.currentWord?.id != "unit-A-0" { _ = session.submitAnswer(session.currentWord!.word, newWordStrategy: .quick) }
        XCTAssertEqual(session.submitAnswer("wrong again", newWordStrategy: .quick), .skippedIncorrect)
        XCTAssertEqual(session.sessionErrorCounts["unit-A-0"], 2)
        XCTAssertFalse(session.completedWordIDs.contains("unit-A-0"))
        XCTAssertEqual(session.pendingWrongRetryWords.map(\.id), ["unit-A-0"])
    }

    func testHistoricalStubbornWordsDoNotLeakIntoOtherUnit() {
        let own = word(0)
        let foreign = word(0, deck: "unit-B")
        let history = [own, foreign].map { entry in
            StubbornWordRecord(wordID: entry.id, word: entry.word, sourceDeckID: entry.deckID, sourceDeckTitle: entry.deckTitle, dateString: "2026-11-14", errorCount: 6, triggeringSessionID: UUID())
        }
        let fresh = DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-14", initialWords: [own], existingStubbornWordsForToday: history, originDeck: "unit-A")
        XCTAssertTrue(fresh.stubbornWordsMap.isEmpty)
        XCTAssertTrue(fresh.sessionErrorCounts.isEmpty)
        let session = DictationSessionStateMachine(mode: .stubbornWordReview, dateString: "2026-11-14", initialWords: [own], existingStubbornWordsForToday: history, originDeck: "unit-A")
        XCTAssertEqual(Set(session.stubbornWordsMap.keys), [own.id])
        XCTAssertEqual(Set(session.sessionErrorCounts.keys), [own.id])
        XCTAssertEqual(session.roundWordIDs, [own.id])
        XCTAssertEqual(DictationSessionReport(session: session).totalWords, 1)
    }

    func testAdaptiveSchedulerBoundsSmallDecks() {
        XCTAssertEqual(DictationSessionStateMachine.adaptiveRetryOffset(cycle: 1, availableWords: 2), 2)
        XCTAssertEqual(DictationSessionStateMachine.adaptiveRetryOffset(cycle: 4, availableWords: 0), 0)
        XCTAssertEqual(DictationSessionStateMachine.adaptiveRetryOffset(cycle: 4, availableWords: 100), 50)
    }
}
