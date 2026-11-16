import Foundation
import Testing
@testable import LumaReaderStudyKit

/// 跨天复习门槛：当场练对不等于掌握，只有隔天（到期后）的无提示答对才推进长期间隔。
struct NextDayRecallGateTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: minute))!
    }
    private func word(_ id: String, _ text: String) -> VocabularyWord {
        VocabularyWord(
            id: id, word: text, phoneticUK: "", phoneticUS: "", partOfSpeech: "",
            definitionZH: "释义", exampleSentence: "", deckID: "fixture", deckTitle: "Fixture"
        )
    }

    @Test func sameDayRecallKeepsStageAndSchedulesTomorrow() {
        let cal = calendar
        let first = day(2026, 11, 15, 9)
        var progress = WordReviewProgress(dueAt: first)
        progress.record(cleanRecall: true, at: first, calendar: cal)
        #expect(progress.stage == 1)
        #expect(progress.dueAt == day(2026, 11, 16, 9))

        // 同一轮里第四档又听对一次（1 小时后）：档位和到期日都不变。
        progress.record(cleanRecall: true, at: day(2026, 11, 15, 10), calendar: cal)
        #expect(progress.stage == 1)
        #expect(progress.dueAt == day(2026, 11, 16, 9))

        // 隔天第一次无提示答对，才按阶梯拉到 3 天。
        let nextDay = day(2026, 11, 16, 9)
        progress.record(cleanRecall: true, at: nextDay, calendar: cal)
        #expect(progress.stage == 2)
        #expect(cal.dateComponents([.day], from: nextDay, to: progress.dueAt).day == 3)
    }

    @Test func correctedAfterSeeingAnswerIsNotCountedAsMastery() {
        let cal = calendar
        let missed = day(2026, 11, 15, 9)
        var progress = WordReviewProgress(dueAt: missed)
        progress.record(cleanRecall: false, reactionSeconds: 6.4, at: missed, calendar: cal)
        #expect(progress.stage == 0)
        #expect(progress.lapses == 1)

        // 看答案后当场改对：不升档，明天再考一次无提示回忆。
        progress.record(cleanRecall: true, reactionSeconds: 2.1, at: day(2026, 11, 15, 9, 10), calendar: cal)
        #expect(progress.stage == 0)
        #expect(progress.dueAt == day(2026, 11, 16, 0))

        // 隔天答对：先回到 1 天，不直接跳到 3 天。
        let nextDay = day(2026, 11, 16, 9)
        progress.record(cleanRecall: true, at: nextDay, calendar: cal)
        #expect(progress.stage == 1)
        #expect(cal.dateComponents([.day], from: nextDay, to: progress.dueAt).day == 1)
    }

    @Test func dueFirstPutsYesterdayWordsAheadOfNewOnes() {
        let cal = calendar
        let now = day(2026, 11, 15, 9)
        let words = (0..<4).map { word("w\($0)", "word\($0)") }
        var schedule: [String: WordReviewProgress] = [:]
        // w1：昨天学过、今天到期 → 提到最前。
        schedule["w1"] = WordReviewProgress(stage: 1, dueAt: day(2026, 11, 15, 0), lastReviewedAt: day(2026, 11, 14, 9), stability: 1.0)
        // w2：今天已经练过，明天才到期 → 不动。
        schedule["w2"] = WordReviewProgress(stage: 1, dueAt: day(2026, 11, 16, 0), lastReviewedAt: day(2026, 11, 15, 8), stability: 1.0)
        // w3：今天答错过，虽然到期但仍算当天的词，不抢隔天回忆的位置。
        schedule["w3"] = WordReviewProgress(stage: 0, dueAt: now, lastReviewedAt: day(2026, 11, 15, 8, 30), stability: 1.0)

        let ordered = WordReviewOrdering.dueFirst(words, schedule: schedule, now: now, calendar: cal)
        #expect(ordered.map(\.id) == ["w1", "w0", "w2", "w3"])
    }

    @Test func dueFirstKeepsOrderForNeverReviewedDecks() {
        let now = day(2026, 11, 15, 9)
        let words = (0..<3).map { word("n\($0)", "new\($0)") }
        #expect(WordReviewOrdering.dueFirst(words, schedule: nil, now: now, calendar: calendar).map(\.id) == ["n0", "n1", "n2"])
        #expect(WordReviewOrdering.dueFirst(words, schedule: [:], now: now, calendar: calendar).map(\.id) == ["n0", "n1", "n2"])
        #expect(!WordReviewOrdering.isDueForNextDayRecall(nil, now: now, calendar: calendar))
    }
}
