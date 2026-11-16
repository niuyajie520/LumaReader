import Foundation
import Testing
@testable import LumaCore

/// 云同步合并规则：两端都调这一份，任何一侧的记录都不该被另一侧无谓盖掉。
@Suite("云同步合并")
struct SyncMergeTests {
    private func word(_ text: String, deck: String = "deck", meaning: String = "释义") -> VocabularyWord {
        VocabularyWord(id: "\(deck).\(text)", word: text, definitionZH: meaning, deckID: deck, deckTitle: deck)
    }

    private func progress(stage: Int, dueAt: Date, reviewedAt: Date? = nil) -> WordReviewProgress {
        var value = WordReviewProgress(dueAt: dueAt)
        value.stage = stage
        value.dueAt = dueAt
        value.lastReviewedAt = reviewedAt
        return value
    }

    @Test("词条：并集去重，大小写不同也只算一个词")
    func wordsUnionIsCaseInsensitive() {
        let local = [word("Atmosphere"), word("hydrosphere")]
        let remote = [word("atmosphere", meaning: "另一条释义"), word("lithosphere")]

        let merged = SyncMerge.mergeWords(local, remote)
        #expect(merged.count == 3)
        #expect(merged.first?.definitionZH == "释义", "重复词保留先出现的那条")
        #expect(merged.map(\.word) == ["Atmosphere", "hydrosphere", "lithosphere"])
    }

    @Test("词条：不同词本里的同一个词都要保留")
    func sameWordInDifferentDecksSurvives() {
        let merged = SyncMerge.mergeWords([word("apple", deck: "deckA")], [word("apple", deck: "deckB")])
        #expect(merged.count == 2)
    }

    @Test("复习进度：档位高的胜出，同档位取更晚的到期时间")
    func scheduleKeepsFurtherProgress() {
        let early = Date(timeIntervalSince1970: 1_700_000_000)
        let late = early.addingTimeInterval(86_400 * 5)

        let merged = SyncMerge.mergeSchedule(
            ["a": progress(stage: 2, dueAt: early)],
            ["a": progress(stage: 3, dueAt: early), "b": progress(stage: 1, dueAt: late)]
        )
        #expect(merged["a"]?.stage == 3)
        #expect(merged["b"]?.stage == 1)

        let sameStage = SyncMerge.mergeSchedule(
            ["c": progress(stage: 2, dueAt: early)],
            ["c": progress(stage: 2, dueAt: late)]
        )
        #expect(sameStage["c"]?.dueAt == late)
    }

    @Test("日志：按 id 去重，按时间正序")
    func logsUnionDedupesByID() {
        let session = UUID()
        func log(at seconds: TimeInterval) -> DictationAttemptLog {
            DictationAttemptLog(id: UUID(), sessionID: session, mode: .newTask, wordID: "a", word: "alpha", deckID: "deck", userTyped: "alpha", isCorrect: true, isFirstAttemptInSession: true, sessionErrorCountForWord: 0, timestamp: Date(timeIntervalSince1970: seconds), dateString: "2026-11-16", durationSeconds: 2)
        }
        let older = log(at: 100)
        let shared = log(at: 150)
        let newer = log(at: 200)

        let merged = SyncMerge.mergeLogs([newer, shared], [shared, older])
        #expect(merged.count == 3, "同一个 id 只能留一条")
        #expect(merged.map(\.timestamp) == [100, 150, 200].map { Date(timeIntervalSince1970: $0) })
    }

    @Test("顽固词：同词同日取较大错误次数，不同日期都留")
    func stubbornKeepsMaxErrorCount() {
        let today = StubbornWordRecord(wordID: "a", word: "alpha", sourceDeckID: "deck", sourceDeckTitle: "deck", dateString: "2026-11-16", errorCount: 3, triggeringSessionID: UUID())
        var worse = today
        worse.errorCount = 7
        let yesterday = StubbornWordRecord(wordID: "a", word: "alpha", sourceDeckID: "deck", sourceDeckTitle: "deck", dateString: "2026-11-15", errorCount: 2, triggeringSessionID: UUID())

        let merged = SyncMerge.mergeStubborn([today], [worse, yesterday])
        #expect(merged.count == 2)
        #expect(merged.first { $0.dateString == "2026-11-16" }?.errorCount == 7)
    }

    @Test("慢反应：次数取大、最慢取大、最快取小")
    func slowReactionKeepsExtremes() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let local = SlowReactionWordRecord(wordID: "a", word: "alpha", definitionZH: "阿尔法", sourceDeckID: "deck", sourceDeckTitle: "deck", lastReactionSeconds: 8, maxReactionSeconds: 9, bestReactionSeconds: 6, slowCount: 2, dateString: "2026-11-16", updatedAt: base)
        var remote = local
        remote.slowCount = 5
        remote.maxReactionSeconds = 12
        remote.bestReactionSeconds = 3
        remote.updatedAt = base.addingTimeInterval(60)

        let merged = SyncMerge.mergeSlowReaction([local], [remote])
        #expect(merged.count == 1)
        #expect(merged[0].slowCount == 5)
        #expect(merged[0].maxReactionSeconds == 12)
        #expect(merged[0].bestReactionSeconds == 3)
        #expect(merged[0].updatedAt == remote.updatedAt)
    }

    @Test("每日阅读：同一天取较大值")
    func dailyReadingKeepsLarger() {
        let merged = SyncMerge.mergeDailyReading(["2026-11-15": 600, "2026-11-16": 60], ["2026-11-16": 300, "2026-11-17": 10])
        #expect(merged == ["2026-11-15": 600, "2026-11-16": 300, "2026-11-17": 10])
    }

    @Test("标记集合：并集且排序稳定")
    func marksUnionSorted() {
        #expect(SyncMerge.mergeMarks(["b", "a"], ["c", "a"]) == ["a", "b", "c"])
    }
}
