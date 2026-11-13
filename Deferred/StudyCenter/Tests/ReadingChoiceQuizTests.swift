import Foundation
import XCTest
@testable import LumaReaderStudyKit

final class ReadingChoiceQuizTests: XCTestCase {
    private struct SeededRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var value = state
            value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
            value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
            return value ^ (value >> 31)
        }
    }

    private func word(_ id: String, _ meaning: String) -> VocabularyWord {
        VocabularyWord(id: id, word: id, definitionZH: meaning, deckID: "reading", deckTitle: "Reading")
    }

    private var fixture: [VocabularyWord] {
        ["大气", "水圈", "地幔", "轨道", "氧气", "潮汐", "冰川", "珊瑚", "盆地", "火山", "海岸", "河流"]
            .enumerated().map { word("term-\($0.offset)", "n. \($0.element)") }
    }

    func testBalancedBlocksAndAnswerJudgment() {
        let words = fixture
        var answerSequences = Set<[Int]>()
        var questionSequences = Set<[String]>()
        var positionsByWord: [String: Set<Int>] = [:]
        for seed in 1...32 {
            var random = SeededRandom(state: UInt64(seed))
            let round = LumaChoiceQuizBuilder.makeRound(words: words, deckPool: words, globalPool: [], random: &random)
            XCTAssertEqual(round.count, words.count)
            for block in stride(from: 0, to: round.count - 3, by: 4) {
                XCTAssertEqual(Set(round[block..<block + 4].map(\.correctIndex)), Set(0..<4))
            }
            answerSequences.insert(round.map(\.correctIndex))
            questionSequences.insert(round.map(\.word.id))
            for question in round {
                positionsByWord[question.word.id, default: []].insert(question.correctIndex)
                XCTAssertEqual(Set(question.options).count, 4)
                XCTAssertEqual(question.options[question.correctIndex], LumaChoiceQuizBuilder.displayMeaning(for: question.word))
                for index in -1...4 { XCTAssertEqual(question.isCorrect(index), index == question.correctIndex) }
            }
        }
        XCTAssertGreaterThan(answerSequences.count, 1)
        XCTAssertGreaterThan(questionSequences.count, 1)
        XCTAssertTrue(positionsByWord.values.allSatisfy { $0 == Set(0..<4) })
    }

    func testDuplicateSensesAndSynonymsAreExcluded() throws {
        let answer = word("happy", "adj. 开心；满意")
        let rejected = [word("content", "adj. 满意的，满足的"), word("glad", "adj. 高兴（口语）"), word("duplicate", "adj. 满意、开心")]
        let apples = [word("apple", "n. 苹果"), word("apple-copy", "n. 苹果（水果）")]
        var random = SeededRandom(state: 42)
        let round = LumaChoiceQuizBuilder.makeRound(
            words: [answer], deckPool: [answer] + rejected + apples,
            globalPool: [word("rock", "n. 岩石"), word("sea", "n. 大海")], random: &random
        )
        let question = try XCTUnwrap(round.first)
        XCTAssertEqual(question.options.count, 4)
        XCTAssertTrue(rejected.allSatisfy { !question.options.contains(LumaChoiceQuizBuilder.displayMeaning(for: $0)) })
        XCTAssertEqual(question.options.filter { $0.contains("苹果") }.count, 1)
    }

    func testStoredQuestionOptionsAreStableOnRepeatedReads() throws {
        let words = fixture
        var random = SeededRandom(state: 125)
        let round = LumaChoiceQuizBuilder.makeRound(words: words, deckPool: words, globalPool: [], random: &random)
        let initial = try XCTUnwrap(round.first)
        for _ in 0..<30 {
            let current = try XCTUnwrap(round.first)
            XCTAssertEqual(current, initial)
        }
        XCTAssertNotEqual(round.dropFirst().first?.id, initial.id)
    }

    func testDraftRoundTripPreservesQuestionAndProgress() throws {
        let words = fixture
        var random = SeededRandom(state: 16)
        let questions = LumaChoiceQuizBuilder.makeRound(words: words, deckPool: words, globalPool: [], random: &random)
        let question = try XCTUnwrap(questions.dropFirst().first)
        let picked = (question.correctIndex + 1) % question.options.count
        let draft = ReadingQuizDraft(
            questions: questions, index: 1, picked: picked, eliminated: [],
            revealedByHelp: false, correctIDs: [questions[0].word.id], wrongWords: [question.word],
            roundStartCursor: 0, roundEndCursor: words.count
        )

        let restored = try JSONDecoder().decode(ReadingQuizDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertTrue(restored.isValid(for: words.reversed()))
        XCTAssertFalse(restored.isValid(for: Array(words.dropFirst())))
        XCTAssertEqual(restored.questions, questions)
        XCTAssertEqual(restored.index, 1)
        XCTAssertEqual(restored.picked, picked)
        XCTAssertEqual(restored.answeredCount, 2)
        XCTAssertEqual(restored.correctIDs, draft.correctIDs)
        XCTAssertEqual(restored.wrongWords, draft.wrongWords)
        XCTAssertEqual(restored.roundEndCursor, words.count)
        XCTAssertFalse(restored.questions[restored.index].isCorrect(picked))
    }

    func testInsufficientPoolDoesNotProduceAnAlwaysAQuestion() {
        let answer = word("sea", "n. 大海")
        var random = SeededRandom(state: 8)
        XCTAssertTrue(LumaChoiceQuizBuilder.makeRound(
            words: [answer], deckPool: [answer, word("rock", "n. 岩石")], globalPool: [], random: &random
        ).isEmpty)
    }
}
