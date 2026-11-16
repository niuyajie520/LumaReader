import Foundation

/// 云同步的合并规则。macOS 与 iPhone 都从这里取，避免「两边各写一份、字段越合越歪」。
///
/// 原则：**任何一侧的记录都不删**——词条并集、进度取更新的一次、日志按 id 去重、顽固词取较大错误数。
public enum SyncMerge {
    /// 词条合并：同一本词本里同一个词只留一条（忽略大小写），保留先出现的那条。
    public static func mergeWords(_ local: [VocabularyWord], _ remote: [VocabularyWord]) -> [VocabularyWord] {
        var seen = Set<String>()
        var merged: [VocabularyWord] = []
        for word in local + remote {
            let key = "\(word.deckID)|\(word.word.lowercased())"
            if seen.insert(key).inserted {
                merged.append(word)
            }
        }
        return merged
    }

    /// 复习进度合并：同一单词取「档位更高」或「档位相同但下次复习更晚」的一侧。
    public static func mergeSchedule(
        _ local: [String: WordReviewProgress],
        _ remote: [String: WordReviewProgress]
    ) -> [String: WordReviewProgress] {
        var merged = local
        for (wordID, remoteProgress) in remote {
            guard let localProgress = merged[wordID] else {
                merged[wordID] = remoteProgress
                continue
            }
            if remoteProgress.stage > localProgress.stage
                || (remoteProgress.stage == localProgress.stage && remoteProgress.dueAt > localProgress.dueAt) {
                merged[wordID] = remoteProgress
            }
        }
        return merged
    }

    /// 听写日志合并：按 id 去重，按时间正序。
    public static func mergeLogs(_ local: [DictationAttemptLog], _ remote: [DictationAttemptLog]) -> [DictationAttemptLog] {
        var seen = Set<UUID>()
        var merged: [DictationAttemptLog] = []
        for log in local + remote where seen.insert(log.id).inserted {
            merged.append(log)
        }
        return merged.sorted { $0.timestamp < $1.timestamp }
    }

    /// 顽固词合并：同一词同一天取较大的错误次数；排序稳定（错得多、词靠前的在前）。
    public static func mergeStubborn(
        _ local: [StubbornWordRecord],
        _ remote: [StubbornWordRecord]
    ) -> [StubbornWordRecord] {
        var merged: [String: StubbornWordRecord] = [:]
        for record in local + remote {
            let key = "\(record.wordID)|\(record.dateString)"
            if let existing = merged[key] {
                if record.errorCount > existing.errorCount { merged[key] = record }
            } else {
                merged[key] = record
            }
        }
        return merged.values.sorted {
            $0.errorCount != $1.errorCount ? $0.errorCount > $1.errorCount : $0.word < $1.word
        }
    }

    /// 慢反应记录合并：次数取大、最慢取大、最快取小、最近一次取更新的那条。
    public static func mergeSlowReaction(
        _ local: [SlowReactionWordRecord],
        _ remote: [SlowReactionWordRecord]
    ) -> [SlowReactionWordRecord] {
        var merged: [String: SlowReactionWordRecord] = [:]
        for record in local + remote {
            guard var existing = merged[record.wordID] else {
                merged[record.wordID] = record
                continue
            }
            existing.slowCount = max(existing.slowCount, record.slowCount)
            existing.maxReactionSeconds = max(existing.maxReactionSeconds, record.maxReactionSeconds)
            if record.updatedAt > existing.updatedAt {
                existing.lastReactionSeconds = record.lastReactionSeconds
                existing.updatedAt = record.updatedAt
                existing.dateString = record.dateString
            }
            if let best = record.bestReactionSeconds {
                existing.bestReactionSeconds = min(existing.bestReactionSeconds ?? best, best)
            }
            merged[record.wordID] = existing
        }
        return merged.values.sorted { $0.lastReactionSeconds > $1.lastReactionSeconds }
    }

    /// 每日阅读秒数合并：同一天取较大的那个（两台设备都在读时不会互相盖掉）。
    public static func mergeDailyReading(
        _ local: [String: Int],
        _ remote: [String: Int]
    ) -> [String: Int] {
        var merged = local
        for (day, seconds) in remote {
            merged[day] = max(merged[day, default: 0], seconds)
        }
        return merged
    }

    /// 字符串集合的并集，排序后返回（用于「已排除的错题」「意思不清」这类标记）。
    public static func mergeMarks(_ local: [String], _ remote: [String]) -> [String] {
        Array(Set(local).union(remote)).sorted()
    }
}
