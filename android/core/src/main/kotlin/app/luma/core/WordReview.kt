package app.luma.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * 复习进度。融合艾宾浩斯遗忘曲线与 FSRS（Difficulty / Stability / Retrievability）。
 *
 * 关键行为（三条，改之前先看 `spec/behaviour.json`）：
 *  1. 隔天（或到期后）的无提示回忆才推进档位；
 *  2. 同一天里再答对一次只算「当堂练对」，档位不动、间隔不拉长；
 *  3. 答错立刻归零，并把这次记为 lapse。
 */
data class WordReviewProgress(
    var stage: Int = 0,
    var dueAt: Instant = Instant.EPOCH,
    var lastReviewedAt: Instant? = null,
    var stability: Double = 0.0,
    var difficulty: Double = 5.0,
    var lapses: Int = 0,
) {
    /** 实时保持率 R(t) ∈ [0, 1]。 */
    fun retrievability(now: Instant = Instant.now()): Double {
        val last = lastReviewedAt ?: return if (stage > 0) 0.90 else 0.0
        val elapsedDays = maxOf(0.0, ChronoUnit.MILLIS.between(last, now) / 86_400_000.0)
        val fallback = baseIntervals[minOf(maxOf(0, stage - 1), baseIntervals.lastIndex)].toDouble()
        val effS = maxOf(0.5, if (stability > 0) stability else fallback)
        return Math.pow(1.0 + (19.0 / 81.0) * (elapsedDays / effS), -0.5)
    }

    fun lastReviewedOnSameDay(now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): Boolean {
        val last = lastReviewedAt ?: return false
        return LocalDate.ofInstant(last, zone) == LocalDate.ofInstant(now, zone)
    }

    fun record(
        cleanRecall: Boolean,
        reactionSeconds: Double? = null,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ) {
        val r = retrievability(now)
        val sameDayRecall = lastReviewedOnSameDay(now, zone)
        lastReviewedAt = now

        if (cleanRecall) {
            if (sameDayRecall) {
                // 当天再对一次：档位原地不动，不拉长稳定性，也不把已排好的跨天复习提前或推后。
                difficulty = maxOf(1.0, difficulty - 0.15)
                stability = maxOf(stability, 1.0)
                dueAt = maxOf(dueAt, nextDayStart(now, zone))
                return
            }
            val days = baseIntervals[minOf(stage, baseIntervals.lastIndex)]
            stage = minOf(stage + 1, baseIntervals.size)
            val latency = reactionSeconds ?: 2.5
            val isSlow = latency > 5.0
            val isFast = latency <= 1.8
            val gradeDelta = if (isSlow) 0.45 else if (isFast) -0.35 else -0.10
            difficulty = minOf(10.0, maxOf(1.0, difficulty + gradeDelta))
            val prevS = maxOf(1.0, if (stability > 0) stability else days.toDouble())
            val growth = 1.0 + Math.exp(0.75) * (11.0 - difficulty) *
                Math.pow(prevS, -0.18) *
                (Math.exp((1.0 - r) * 0.25) - 1.0 + if (isFast) 0.65 else if (isSlow) 0.22 else 0.45)
            stability = maxOf(days.toDouble(), minOf(14.0, prevS * maxOf(1.15, growth)))
            dueAt = now.plus(days.toLong(), ChronoUnit.DAYS)
        } else {
            stage = 0
            lapses += 1
            difficulty = minOf(10.0, maxOf(1.0, difficulty + 0.85))
            stability = maxOf(0.5, (if (stability > 0) stability else 1.0) * 0.35)
            dueAt = now
        }
    }

    companion object {
        val baseIntervals: List<Int> = listOf(1, 3, 5, 7, 10, 14)
        const val SLOW_REACTION_SECONDS = 5.0
        const val INSTANT_REACTION_SECONDS = 1.8

        /** 次日零点：当天练过的词统一在明天第一次打开时再考一次无提示回忆。 */
        fun nextDayStart(now: Instant, zone: ZoneId = ZoneId.systemDefault()): Instant {
            val today = LocalDate.ofInstant(now, zone)
            return today.plusDays(1).atStartOfDay(zone).toInstant()
        }
    }
}

/** 学新词的取词顺序：昨天学过、今天到期的词先做一次隔天无提示回忆。 */
object WordReviewOrdering {

    fun isDueForNextDayRecall(
        progress: WordReviewProgress?,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Boolean {
        val last = progress?.lastReviewedAt ?: return false
        return !progress.dueAt.isAfter(now) && !progress.lastReviewedOnSameDay(now, zone)
    }

    /** 稳定分区：到期的词保持原顺序提到最前，其余词相对顺序不变。 */
    fun dueFirst(
        words: List<VocabularyWord>,
        schedule: Map<String, WordReviewProgress>?,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<VocabularyWord> {
        if (schedule.isNullOrEmpty() || words.isEmpty()) return words
        val due = ArrayList<VocabularyWord>(words.size)
        val rest = ArrayList<VocabularyWord>(words.size)
        for (word in words) {
            if (isDueForNextDayRecall(schedule[word.id], now, zone)) due.add(word) else rest.add(word)
        }
        return if (due.isEmpty()) words else due + rest
    }
}
