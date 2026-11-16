import XCTest
import Foundation
@testable import LumaCore

/// 行为快照测试：用例来自仓库根目录的 `spec/behaviour.json`。
/// 这份 JSON 是跨平台合同——将来 Android（Kotlin）拿同一份文件做参数化测试，
/// 只要两边都通过，就说明规则没有漂移。改规则请同时改 JSON 和 `LumaCoreVersion.specification`。
final class RuleFixtureTests: XCTestCase {

    private struct Spec: Decodable {
        struct Judgement: Decodable { let input: String; let target: String; let match: Bool }
        struct Normalization: Decodable { let input: String; let normalized: String }
        struct EntryKind: Decodable { let input: String; let kind: String }
        struct MinorSlip: Decodable { let input: String; let target: String; let fragment: String? }
        struct Review: Decodable {
            let cleanRecallIntervals: [Int]
            let sameDaySecondCorrectKeepsStage: Bool
            struct Wrong: Decodable { let stage: Int; let lapsesIncrement: Int }
            let wrongAnswer: Wrong
        }
        let judgement: [Judgement]
        let normalization: [Normalization]
        let entryKind: [EntryKind]
        let minorSlip: [MinorSlip]
        let reviewSchedule: Review
    }

    private func loadSpec() throws -> Spec {
        let here = URL(fileURLWithPath: #filePath)
        let specURL = here
            .deletingLastPathComponent()   // LumaCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // LumaCore
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("spec/behaviour.json")
        return try JSONDecoder().decode(Spec.self, from: Data(contentsOf: specURL))
    }

    func testJudgementFixtures() throws {
        for item in try loadSpec().judgement {
            XCTAssertEqual(DictationAnswerPolicy.matches(item.input, targetWord: item.target), item.match,
                           "matches(\(item.input), \(item.target))")
        }
    }

    func testNormalizationFixtures() throws {
        for item in try loadSpec().normalization {
            XCTAssertEqual(DictationAnswerPolicy.normalized(item.input), item.normalized,
                           "normalized(\(item.input))")
        }
    }

    func testEntryKindFixtures() throws {
        for item in try loadSpec().entryKind {
            let expected: DictationEntryKind = item.kind == "longPhrase" ? .longPhrase : .word
            XCTAssertEqual(DictationEntryKind.classify(item.input), expected, "classify(\(item.input))")
        }
    }

    func testMinorSlipFixtures() throws {
        for item in try loadSpec().minorSlip {
            XCTAssertEqual(DictationPhraseDiff.minorSlip(input: item.input, target: item.target),
                           item.fragment, "minorSlip(\(item.input), \(item.target))")
        }
    }

    func testReviewScheduleFixtures() throws {
        let review = try loadSpec().reviewSchedule
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var progress = WordReviewProgress(dueAt: Date(timeIntervalSince1970: 0))
        var day = DateComponents(calendar: calendar, year: 2026, month: 3, day: 1, hour: 9).date!
        var intervals: [Int] = []
        for _ in review.cleanRecallIntervals {
            progress.record(cleanRecall: true, reactionSeconds: 2.0, at: day, calendar: calendar)
            intervals.append(calendar.dateComponents([.day], from: day, to: progress.dueAt).day ?? -1)
            day = progress.dueAt.addingTimeInterval(3600)
        }
        XCTAssertEqual(intervals, review.cleanRecallIntervals)

        if review.sameDaySecondCorrectKeepsStage {
            var sameDay = WordReviewProgress(dueAt: Date(timeIntervalSince1970: 0))
            let morning = DateComponents(calendar: calendar, year: 2026, month: 3, day: 1, hour: 9).date!
            sameDay.record(cleanRecall: true, reactionSeconds: 2.0, at: morning, calendar: calendar)
            let due = sameDay.dueAt, stage = sameDay.stage
            sameDay.record(cleanRecall: true, reactionSeconds: 1.1,
                           at: morning.addingTimeInterval(3 * 3600), calendar: calendar)
            XCTAssertEqual(sameDay.stage, stage)
            XCTAssertEqual(sameDay.dueAt, due)
        }

        var wrong = WordReviewProgress(stage: 3, dueAt: Date(timeIntervalSince1970: 0), stability: 7)
        let now = DateComponents(calendar: calendar, year: 2026, month: 3, day: 10, hour: 9).date!
        wrong.record(cleanRecall: false, reactionSeconds: 3.0, at: now, calendar: calendar)
        XCTAssertEqual(wrong.stage, review.wrongAnswer.stage)
        XCTAssertEqual(wrong.lapses, review.wrongAnswer.lapsesIncrement)
        XCTAssertEqual(wrong.dueAt, now)
    }

    func testDueFirstOrdering() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = DateComponents(calendar: calendar, year: 2026, month: 3, day: 10, hour: 9).date!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        func word(_ id: String) -> VocabularyWord {
            VocabularyWord(id: id, word: id, definitionZH: "", deckID: "d", deckTitle: "D")
        }
        let words = [word("w0"), word("w1"), word("w2"), word("w3")]
        let schedule: [String: WordReviewProgress] = [
            "w1": WordReviewProgress(stage: 1, dueAt: yesterday, lastReviewedAt: yesterday),
            "w2": WordReviewProgress(stage: 1, dueAt: now.addingTimeInterval(86_400), lastReviewedAt: yesterday),
        ]
        let ordered = WordReviewOrdering.dueFirst(words, schedule: schedule, now: now, calendar: calendar)
        XCTAssertEqual(ordered.map(\.id), ["w1", "w0", "w2", "w3"])
    }
}
