import XCTest
@testable import LumaReaderStudyKit

/// Regression: a visibly correct answer must count and advance, and IME-invisible
/// characters must not turn a correct spelling into an error.
final class DictationAnswerRegressionTests: XCTestCase {
    private func word(_ id: String, _ text: String) -> VocabularyWord {
        VocabularyWord(id: id, word: text, definitionZH: "", deckID: "test", deckTitle: "Test")
    }

    func testFullWidthInputIsAccepted() {
        XCTAssertEqual(DictationAnswerPolicy.normalized("ｍｅｍｂｅｒｓｈｉｐ　ｓｃｈｅｍｅ"), "membership scheme")
    }

    func testZeroWidthCharactersAreIgnored() {
        XCTAssertEqual(DictationAnswerPolicy.normalized("member\u{200B}ship sche\u{200D}me"), "membership scheme")
    }

    func testCorrectAnswerAdvancesInNormalDictation() {
        let first = word("w1", "membership scheme")
        let second = word("w2", "trial session")
        var machine = DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-10", initialWords: [first, second])
        XCTAssertEqual(machine.currentWord?.id, "w1")
        let outcome = machine.submitAnswer("membership scheme")
        XCTAssertEqual(outcome, .correct(exitedWrongQueue: false))
        XCTAssertEqual(machine.currentWord?.id, "w2")
        XCTAssertEqual(machine.pendingQueue.count, 1)
        XCTAssertTrue(machine.completedWordIDs.contains("w1"))
    }

    func testWrongThenCorrectRequeuesTenWordsLater() {
        let words = (0..<14).map { word("w\($0)", "word\($0)") }
        var machine = DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-10", initialWords: words)
        _ = machine.submitAnswer("wrong")
        XCTAssertEqual(machine.currentWord?.id, "w0")
        let outcome = machine.submitAnswer("word0")
        XCTAssertEqual(outcome, .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 10))
        XCTAssertFalse(machine.requiresCorrection)
        XCTAssertEqual(machine.pendingQueue.count, 14)
        XCTAssertEqual(machine.pendingQueue[10].id, "w0")
    }


    func testPhraseSeparatorsAreLenient() {
        let target = "membership scheme"
        XCTAssertTrue(DictationAnswerPolicy.matches("membership  scheme", targetWord: target))
        XCTAssertTrue(DictationAnswerPolicy.matches("membership-scheme", targetWord: target))
        XCTAssertTrue(DictationAnswerPolicy.matches("membership_scheme", targetWord: target))
        XCTAssertTrue(DictationAnswerPolicy.matches("membershipscheme", targetWord: target))
        XCTAssertFalse(DictationAnswerPolicy.matches("membership skeme", targetWord: target))
    }

    func testSingleWordRejectsInternalSpace() {
        XCTAssertFalse(DictationAnswerPolicy.matches("member ship", targetWord: "membership"))
        XCTAssertTrue(DictationAnswerPolicy.matches("member-ship", targetWord: "membership"))
    }

    func testRetryIntervalsAreTenFiftyHundredTwoHundred() {
        XCTAssertEqual(DictationSessionStateMachine.expandingRetryOffsets, [10, 50, 100, 200])
    }
}
