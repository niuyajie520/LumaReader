import Foundation
import Testing
@testable import LumaReaderStudyKit

/// 学新词 ·「循环复习」：5 / 55 / 155 / 255 阶梯；高档答错先隔 5 词确认，再跳回上一档。
struct NewWordLadderTests {
    private func words(_ count: Int) -> [VocabularyWord] {
        (0..<count).map {
            VocabularyWord(id: "w\($0)", word: "word\($0)", definitionZH: "释义", deckID: "unit", deckTitle: "unit")
        }
    }

    private func session(_ count: Int = 900) -> DictationSessionStateMachine {
        DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-15", initialWords: words(count), originDeck: "unit")
    }

    @discardableResult
    private func answer(_ s: inout DictationSessionStateMachine, _ text: String) -> DictationSubmitOutcome? {
        s.submitAnswer(text, newWordStrategy: .repeating)
    }

    /// 其他词全部答对，直到 w0 回到队首。
    private func advanceToW0(_ s: inout DictationSessionStateMachine) {
        while let current = s.currentWord, current.id != "w0" {
            answer(&s, current.word)
        }
    }

    @Test func ladderUsesFiveFiftyFiveOneFiftyFiveTwoFiftyFive() {
        var s = session()
        let o1 = answer(&s, "wrong")
        #expect(o1 == .needsCorrection(errorCountForWordToday: 1))
        let o2 = answer(&s, "word0")
        #expect(o2 == .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 5))
        advanceToW0(&s)
        let o3 = answer(&s, "word0")
        #expect(o3 == .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 55))
        advanceToW0(&s)
        let o4 = answer(&s, "word0")
        #expect(o4 == .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 155))
        advanceToW0(&s)
        let o5 = answer(&s, "word0")
        #expect(o5 == .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 255))
        advanceToW0(&s)
        let o6 = answer(&s, "word0")
        #expect(o6 == .correct(exitedWrongQueue: true))
    }

    /// 在 255 档答错：订正 → 隔 5 词 → 直接回到 155 档 → 255 档 → 毕业，不从第 1 档重爬。
    @Test func missAtTopTierDropsOnlyOneTierAfterFiveWordCheck() {
        var s = session()
        answer(&s, "wrong"); answer(&s, "word0")
        for _ in 0..<3 { advanceToW0(&s); answer(&s, "word0") }
        #expect(s.wrongRetryCycleByWordID["w0"] == 4)

        advanceToW0(&s)
        let o7 = answer(&s, "wrong")
        #expect(o7 == .needsCorrection(errorCountForWordToday: 2))
        let o8 = answer(&s, "word0")
        #expect(o8 == .requeuedForRetry(errorCountForWordToday: 2, insertedAtOffset: 5))
        #expect(s.relearnTargetCycleByWordID["w0"] == 3)

        advanceToW0(&s)
        let o9 = answer(&s, "word0")
        #expect(o9 == .requeuedForRetry(errorCountForWordToday: 2, insertedAtOffset: 155))
        #expect(s.wrongRetryCycleByWordID["w0"] == 3)
        #expect(s.relearnTargetCycleByWordID["w0"] == nil)

        advanceToW0(&s)
        let o10 = answer(&s, "word0")
        #expect(o10 == .requeuedForRetry(errorCountForWordToday: 2, insertedAtOffset: 255))
        advanceToW0(&s)
        let o11 = answer(&s, "word0")
        #expect(o11 == .correct(exitedWrongQueue: true))
    }

    /// 在 155 档答错：隔 5 词确认后回到 55 档。
    @Test func missAtThirdTierReturnsToSecondTier() {
        var s = session()
        answer(&s, "wrong"); answer(&s, "word0")
        for _ in 0..<2 { advanceToW0(&s); answer(&s, "word0") }
        #expect(s.wrongRetryCycleByWordID["w0"] == 3)
        advanceToW0(&s)
        answer(&s, "wrong")
        let o12 = answer(&s, "word0")
        #expect(o12 == .requeuedForRetry(errorCountForWordToday: 2, insertedAtOffset: 5))
        advanceToW0(&s)
        let o13 = answer(&s, "word0")
        #expect(o13 == .requeuedForRetry(errorCountForWordToday: 2, insertedAtOffset: 55))
    }

    /// 订正时手抖打错不算新的一次听错。
    @Test func typosDuringCorrectionAreNotNewMisses() {
        var s = session()
        answer(&s, "wrong")
        answer(&s, "wrnog")
        answer(&s, "wrogn")
        #expect(s.roundMissCountByWordID["w0"] == 1)
        let o14 = answer(&s, "word0")
        #expect(o14 == .requeuedForRetry(errorCountForWordToday: 3, insertedAtOffset: 5))
        #expect(!s.deferredToEndWordIDs.contains("w0"))
    }

    /// 本轮第 3 次真正听错：挪到本轮最后单独练。
    @Test func thirdMissMovesWordToEndOfRound() {
        var s = session(60)
        for _ in 0..<2 {
            advanceToW0(&s)
            answer(&s, "wrong"); answer(&s, "word0")
        }
        advanceToW0(&s)
        answer(&s, "wrong")
        let outcome = answer(&s, "word0")
        #expect(s.roundMissCountByWordID["w0"] == 3)
        #expect(s.deferredToEndWordIDs.contains("w0"))
        #expect(s.pendingQueue.last?.id == "w0")
        #expect(outcome == .requeuedForRetry(errorCountForWordToday: 3, insertedAtOffset: s.pendingQueue.count - 1))
    }

    /// 错词复习模式不受新阶梯影响。
    @Test func wrongWordReviewKeepsOriginalLadder() {
        var s = DictationSessionStateMachine(mode: .wrongWordReview, dateString: "2026-11-15", initialWords: words(100))
        s.submitAnswer("wrong")
        let o15 = s.submitAnswer("word0")
        #expect(o15 == .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 10))
    }
}

/// 队列只剩最后一个词时，学新词阶梯也不许因为一次答对就「毕业消失」。
struct NewWordLadderTailTests {
    private func single() -> DictationSessionStateMachine {
        DictationSessionStateMachine(mode: .newTask, dateString: "2026-11-15",
                                     initialWords: [VocabularyWord(id: "w0", word: "word0",
                                                                   definitionZH: "释义",
                                                                   deckID: "unit", deckTitle: "unit")],
                                     originDeck: "unit")
    }

    @Test func lastWordWalksAllFourTiersBeforeGraduating() {
        var s = single()
        #expect(s.submitAnswer("wrong", newWordStrategy: .repeating) == .needsCorrection(errorCountForWordToday: 1))
        #expect(s.submitAnswer("word0", newWordStrategy: .repeating) == .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 0))
        // 队列已空，但还没走够四档：继续下一轮，而不是直接毕业。
        for cycle in 2...4 {
            let outcome = s.submitAnswer("word0", newWordStrategy: .repeating)
            #expect(outcome == .requeuedForRetry(errorCountForWordToday: 1, insertedAtOffset: 0))
            #expect(s.wrongRetryCycleByWordID["w0"] == cycle)
        }
        #expect(s.submitAnswer("word0", newWordStrategy: .repeating) == .correct(exitedWrongQueue: true))
        #expect(s.isSessionFinished)
    }

    @Test func missOnTopTierNeverDisappearsWhenQueueIsEmpty() {
        var s = single()
        s.submitAnswer("wrong", newWordStrategy: .repeating)
        s.submitAnswer("word0", newWordStrategy: .repeating)
        for _ in 0..<3 { s.submitAnswer("word0", newWordStrategy: .repeating) }
        #expect(s.wrongRetryCycleByWordID["w0"] == 4)
        // 第 4 档手滑写错：当场订正后不是毕业，而是退到第 3 档继续。
        #expect(s.submitAnswer("wrong", newWordStrategy: .repeating) == .needsCorrection(errorCountForWordToday: 2))
        #expect(s.relearnTargetCycleByWordID["w0"] == 3)
        #expect(s.submitAnswer("word0", newWordStrategy: .repeating) == .requeuedForRetry(errorCountForWordToday: 2, insertedAtOffset: 0))
        #expect(!s.isSessionFinished)
        #expect(s.currentWord?.id == "w0")
        // 订正后先走一次确认步，确认通过才落到第 3 档（不是毕业）。
        #expect(s.wrongRetryCycleByWordID["w0"] == 1)
        #expect(s.submitAnswer("word0", newWordStrategy: .repeating) == .requeuedForRetry(errorCountForWordToday: 2, insertedAtOffset: 0))
        #expect(s.wrongRetryCycleByWordID["w0"] == 3)
        #expect(!s.isSessionFinished)
    }
}
