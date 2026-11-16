import Foundation
import Testing
@testable import LumaReaderStudyKit

/// 长措辞的轻量门槛：5 个词以上才特殊对待；4 个词以内（含固定搭配）仍按单词的逻辑和阶梯。
struct PhraseGateTests {
    private func word(_ text: String, id: String = "p0") -> VocabularyWord {
        VocabularyWord(
            id: id, word: text, phoneticUK: "", phoneticUS: "", partOfSpeech: "",
            definitionZH: "释义", exampleSentence: "", deckID: "fixture", deckTitle: "Fixture"
        )
    }

    @Test func shortCollocationsKeepTheWordStandard() {
        #expect(DictationEntryKind.classify("granted") == .word)
        #expect(DictationEntryKind.classify("in charge of") == .word)
        #expect(DictationEntryKind.classify("take it for granted") == .word)
        #expect(DictationEntryKind.classify("at the end of the day") == .longPhrase)
        #expect(DictationEntryKind.classify("keep an eye on the ball") == .longPhrase)
    }

    @Test func onlyFunctionWordDifferencesCountAsMinorSlip() {
        #expect(DictationPhraseDiff.minorSlip(input: "keep a eye on the ball", target: "keep an eye on the ball") == "an")
        #expect(DictationPhraseDiff.minorSlip(input: "keep an eye in the ball", target: "keep an eye on the ball") == "on")
        #expect(DictationPhraseDiff.minorSlip(input: "keep an ear on the ball", target: "keep an eye on the ball") == nil)
        #expect(DictationPhraseDiff.minorSlip(input: "keep an eye ball", target: "keep an eye on the ball") == nil)
        #expect(DictationPhraseDiff.minorSlip(input: "", target: "keep an eye on the ball") == nil)
    }

    @Test func longPhraseWithOnlyPrepositionSlipIsNotAnError() throws {
        let phrase = word("keep an eye on the ball")
        var session = DictationSessionStateMachine(dateString: "2026-11-15", initialWords: [phrase])

        let slip = session.submitAnswer("keep a eye on the ball", newWordStrategy: .repeating)
        #expect(slip == .needsPhraseFix(fragment: "an"))
        #expect(session.currentWord?.id == phrase.id)
        #expect(session.sessionErrorCounts[phrase.id] == nil)
        #expect(session.stubbornWordsMap.isEmpty)
        #expect(session.attemptLogs.isEmpty)

        let retry = session.submitAnswer("keep an eye on the ball", newWordStrategy: .repeating)
        #expect(retry == .correct(exitedWrongQueue: false))
        #expect(session.completedWordIDs.contains(phrase.id))
        #expect(session.isSessionFinished)
        #expect(session.sessionErrorCounts[phrase.id] == nil)
    }

    @Test func secondSlipFallsBackToTheNormalWrongWordPath() {
        let phrase = word("keep an eye on the ball")
        var session = DictationSessionStateMachine(dateString: "2026-11-15", initialWords: [phrase])
        #expect(session.submitAnswer("keep a eye on the ball", newWordStrategy: .repeating) == .needsPhraseFix(fragment: "an"))
        let second = session.submitAnswer("keep an eye in the ball", newWordStrategy: .repeating)
        #expect(second == .needsCorrection(errorCountForWordToday: 1))
        #expect(session.sessionErrorCounts[phrase.id] == 1)
    }

    @Test func contentWordMistakeInLongPhraseStaysAnError() {
        let phrase = word("keep an eye on the ball")
        var session = DictationSessionStateMachine(dateString: "2026-11-15", initialWords: [phrase])
        #expect(session.submitAnswer("keep an ear on the ball", newWordStrategy: .repeating) == .needsCorrection(errorCountForWordToday: 1))
        #expect(session.sessionErrorCounts[phrase.id] == 1)
    }

    @Test func shortCollocationUsesTheWordPath() {
        let collocation = word("in charge of")
        var session = DictationSessionStateMachine(dateString: "2026-11-15", initialWords: [collocation])
        #expect(session.submitAnswer("in charge for", newWordStrategy: .repeating) == .needsCorrection(errorCountForWordToday: 1))
        #expect(session.sessionErrorCounts[collocation.id] == 1)
    }
}
