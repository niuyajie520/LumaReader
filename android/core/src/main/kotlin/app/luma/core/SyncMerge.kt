package app.luma.core

import java.time.Instant

/**
 * 云同步的合并规则。macOS / iPhone / Android 共用同一套语义：
 * **任何一侧的记录都不删**——词条并集、进度取更新的一次、日志按 id 去重、顽固词取较大错误数。
 */
object SyncMerge {

    /** 词条合并：同一本词本里同一个词只留一条（忽略大小写），保留先出现的那条。 */
    fun mergeWords(local: List<VocabularyWord>, remote: List<VocabularyWord>): List<VocabularyWord> {
        val seen = HashSet<String>()
        val merged = ArrayList<VocabularyWord>(local.size + remote.size)
        for (word in local + remote) {
            val key = "${word.deckID}|${word.word.lowercase()}"
            if (seen.add(key)) merged.add(word)
        }
        return merged
    }

    /** 复习进度合并：取「档位更高」或「档位相同但下次复习更晚」的一侧。 */
    fun mergeSchedule(
        local: Map<String, WordReviewProgress>,
        remote: Map<String, WordReviewProgress>,
    ): Map<String, WordReviewProgress> {
        val merged = local.toMutableMap()
        for ((wordID, remoteProgress) in remote) {
            val localProgress = merged[wordID]
            if (localProgress == null) {
                merged[wordID] = remoteProgress
                continue
            }
            if (remoteProgress.stage > localProgress.stage ||
                (remoteProgress.stage == localProgress.stage && remoteProgress.dueAt.isAfter(localProgress.dueAt))
            ) {
                merged[wordID] = remoteProgress
            }
        }
        return merged
    }

    /** 听写日志合并：按 id 去重，按时间正序。 */
    fun mergeLogs(local: List<DictationAttemptLog>, remote: List<DictationAttemptLog>): List<DictationAttemptLog> {
        val seen = HashSet<java.util.UUID>()
        val merged = ArrayList<DictationAttemptLog>(local.size + remote.size)
        for (log in local + remote) {
            if (seen.add(log.id)) merged.add(log)
        }
        return merged.sortedBy { it.timestamp }
    }

    /** 顽固词合并：同一词同一天取较大的错误次数。 */
    fun mergeStubborn(local: List<StubbornWordRecord>, remote: List<StubbornWordRecord>): List<StubbornWordRecord> {
        val merged = LinkedHashMap<String, StubbornWordRecord>()
        for (record in local + remote) {
            val key = "${record.wordID}|${record.dateString}"
            val existing = merged[key]
            if (existing == null || record.errorCount > existing.errorCount) merged[key] = record
        }
        return merged.values.sortedWith(
            compareByDescending<StubbornWordRecord> { it.errorCount }.thenBy { it.word }
        )
    }

    /** 慢反应合并：次数取大、最慢取大、最快取小、最近一次取更新的那条。 */
    fun mergeSlowReaction(
        local: List<SlowReactionWordRecord>,
        remote: List<SlowReactionWordRecord>,
    ): List<SlowReactionWordRecord> {
        val merged = LinkedHashMap<String, SlowReactionWordRecord>()
        for (record in local + remote) {
            val existing = merged[record.wordID]
            if (existing == null) {
                merged[record.wordID] = record.copy()
                continue
            }
            existing.slowCount = maxOf(existing.slowCount, record.slowCount)
            existing.maxReactionSeconds = maxOf(existing.maxReactionSeconds, record.maxReactionSeconds)
            if (record.updatedAt.isAfter(existing.updatedAt)) {
                existing.lastReactionSeconds = record.lastReactionSeconds
                existing.updatedAt = record.updatedAt
                existing.dateString = record.dateString
            }
            val best = record.bestReactionSeconds
            if (best != null) {
                existing.bestReactionSeconds = minOf(existing.bestReactionSeconds ?: best, best)
            }
            merged[record.wordID] = existing
        }
        return merged.values.sortedByDescending { it.lastReactionSeconds }
    }

    /** 每日阅读秒数合并：同一天取较大的那个。 */
    fun mergeDailyReading(local: Map<String, Int>, remote: Map<String, Int>): Map<String, Int> {
        val merged = local.toMutableMap()
        for ((day, seconds) in remote) {
            merged[day] = maxOf(merged[day] ?: 0, seconds)
        }
        return merged
    }

    /** 字符串集合的并集，排序后返回（用于「已排除的错题」这类标记）。 */
    fun mergeMarks(local: List<String>, remote: List<String>): List<String> =
        (local + remote).toSortedSet().toList()

    /** 最后同步时间的展示文案用不到时区细节，这里只取最大。 */
    fun latestInstant(values: List<Instant>): Instant? = values.maxWithOrNull(compareBy { it })
}
