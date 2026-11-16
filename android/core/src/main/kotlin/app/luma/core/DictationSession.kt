package app.luma.core

import java.time.Instant
import java.time.LocalDate
import java.util.UUID

/**
 * 听写会话状态机。与 `Packages/LumaCore/Sources/LumaCore/DictationSession.swift` 逐条对应。
 *
 * 这里不碰 UI、不碰存储：判题、错词插回、四档循环、长措辞小错全在状态机里，
 * Android 的 Compose 层只负责把 `submit` 的返回值翻译成界面。
 */
enum class DictationSessionMode(val rawValue: String) {
    NEW_TASK("new_task"),
    WRONG_WORD_REVIEW("wrong_word_review"),
    STUBBORN_WORD_REVIEW("stubborn_word_review"),
    SLOW_REACTION_REVIEW("slow_reaction_review");

    companion object {
        fun fromRaw(raw: String): DictationSessionMode =
            entries.firstOrNull { it.rawValue == raw } ?: NEW_TASK
    }
}

enum class NewWordDictationStrategy(val rawValue: String) {
    QUICK("quick"),
    REPEATING("repeating");

    companion object {
        fun fromRaw(raw: String?): NewWordDictationStrategy? =
            entries.firstOrNull { it.rawValue == raw }
    }
}

/** 听写反应时长追踪：拼写对了但从语音播完到确认犹豫超过 5 秒的「慢反应词」。 */
data class SlowReactionWordRecord(
    val wordID: String,
    val word: String,
    var definitionZH: String,
    val sourceDeckID: String,
    val sourceDeckTitle: String,
    var lastReactionSeconds: Double,
    var maxReactionSeconds: Double = lastReactionSeconds,
    var bestReactionSeconds: Double? = null,
    var slowCount: Int = 1,
    var dateString: String,
    var updatedAt: Instant = Instant.now(),
) {
    val id: String get() = wordID

    companion object {
        const val SLOW_THRESHOLD_SECONDS = 5.0
    }
}

data class StubbornWordRecord(
    val wordID: String,
    val word: String,
    val sourceDeckID: String,
    val sourceDeckTitle: String,
    val dateString: String,
    var errorCount: Int,
    val triggeringSessionID: UUID,
) {
    val id: String get() = "${wordID}_$dateString"
}

data class DictationAttemptLog(
    val id: UUID,
    val sessionID: UUID,
    val mode: DictationSessionMode,
    val wordID: String,
    val word: String,
    val deckID: String,
    val userTyped: String,
    val isCorrect: Boolean,
    val isFirstAttemptInSession: Boolean,
    val sessionErrorCountForWord: Int,
    val timestamp: Instant,
    val dateString: String,
    val durationSeconds: Double,
) {
    val isSlowReaction: Boolean
        get() = isCorrect && durationSeconds > SlowReactionWordRecord.SLOW_THRESHOLD_SECONDS
}

sealed class DictationSubmitOutcome {
    data class Correct(val exitedWrongQueue: Boolean) : DictationSubmitOutcome()
    data class NeedsCorrection(val errorCountForWordToday: Int) : DictationSubmitOutcome()
    data class NeedsPhraseFix(val fragment: String) : DictationSubmitOutcome()
    data object SkippedIncorrect : DictationSubmitOutcome()
    data class RequeuedForRetry(val errorCountForWordToday: Int, val insertedAtOffset: Int) : DictationSubmitOutcome()
    data class PromotedToStubbornWords(val errorCountForWordToday: Int) : DictationSubmitOutcome()
}

/** 听写调度参数；改数值不用改逻辑。 */
object DictationTuning {
    /** 学新词「循环复习」的四档词距：隔 5 / 55 / 155 / 255 个词再听，第四档拼对即毕业。 */
    val newWordLadder: List<Int> = listOf(5, 55, 155, 255)
    /** 答错订正后的确认步：先隔 5 个词再听一次。 */
    const val RELEARN_STEP = 5
    /** 本轮同一个词错到第几次就挪到本轮最后单独练。 */
    const val MOVE_TO_END_AFTER_ERRORS = 3
}

class DictationSessionStateMachine(
    val sessionID: UUID = UUID.randomUUID(),
    val mode: DictationSessionMode = DictationSessionMode.NEW_TASK,
    val dateString: String,
    initialWords: List<VocabularyWord>,
    existingStubbornWordsForToday: List<StubbornWordRecord> = emptyList(),
    val originDeck: String? = null,
    private val nowProvider: () -> Instant = { Instant.now() },
) {
    val pendingQueue: MutableList<VocabularyWord> = initialWords.distinctBy { it.id }.toMutableList()
    /** 本轮开始时的词数（队列会增减，展示进度要用这个）。 */
    val initialWordCount: Int = pendingQueue.size
    val completedWordIDs: MutableSet<String> = mutableSetOf()
    val sessionErrorCounts: MutableMap<String, Int> = mutableMapOf()
    val activeWrongRetrySet: MutableSet<String> = mutableSetOf()
    /** 记录每个错词当前处于第几轮艾宾浩斯循环（1...4）。 */
    val wrongRetryCycleByWordID: MutableMap<String, Int> = mutableMapOf()
    val correctionPendingIDs: MutableSet<String> = mutableSetOf()
    /** 学新词阶梯：高档答错后，确认步通过要跳回的档位。 */
    val relearnTargetCycleByWordID: MutableMap<String, Int> = mutableMapOf()
    /** 本轮错满 3 次、已挪到本轮最后单独练的词。 */
    val deferredToEndWordIDs: MutableSet<String> = mutableSetOf()
    /** 长措辞只差虚词、给过一次重试机会的词。 */
    val minorSlipWordIDs: MutableSet<String> = mutableSetOf()
    /** 本轮真正听错的次数（订正时打错不算新的一次）。 */
    val roundMissCountByWordID: MutableMap<String, Int> = mutableMapOf()
    val stubbornWordsMap: MutableMap<String, StubbornWordRecord> = mutableMapOf()
    val slowReactionWordIDs: MutableSet<String> = mutableSetOf()
    val attemptLogs: MutableList<DictationAttemptLog> = mutableListOf()
    private val wordsWithInitialAttemptLogged: MutableSet<String> = mutableSetOf()

    init {
        if (mode == DictationSessionMode.STUBBORN_WORD_REVIEW) {
            val ids = pendingQueue.map { it.id }.toSet()
            for (item in existingStubbornWordsForToday) {
                if (item.dateString != dateString || item.wordID !in ids) continue
                stubbornWordsMap[item.wordID] = item
                sessionErrorCounts[item.wordID] =
                    maxOf(sessionErrorCounts[item.wordID] ?: 0, item.errorCount)
            }
        }
    }

    /** sessionID 既是精确轮次标识：重新开始生成新轮，继续练习沿用同一轮。 */
    val roundID: UUID get() = sessionID

    val currentWord: VocabularyWord? get() = pendingQueue.firstOrNull()
    val isSessionFinished: Boolean get() = pendingQueue.isEmpty()
    val requiresCorrection: Boolean get() = currentWord?.let { it.id in correctionPendingIDs } ?: false

    /** 当前单词所处的错词循环轮次（1...4）；不是错词时返回 null。 */
    val currentWordRetryCycle: Int?
        get() {
            val word = currentWord ?: return null
            if (word.id !in activeWrongRetrySet) return null
            return (wrongRetryCycleByWordID[word.id] ?: 1).coerceIn(1, EXPANDING_RETRY_OFFSETS.size)
        }

    val sortedStubbornWords: List<StubbornWordRecord>
        get() = stubbornWordsMap.values.sortedWith(
            compareByDescending<StubbornWordRecord> { it.errorCount }.thenBy { it.word.lowercase() }
        )

    val wordDeckIDs: Set<String>
        get() = pendingQueue.map { it.deckID }.toSet() + attemptLogs.map { it.deckID }

    val roundWordIDs: Set<String>
        get() = pendingQueue.map { it.id }.toSet() + completedWordIDs + attemptLogs.map { it.wordID }

    fun revisitCompletedWord(word: VocabularyWord) {
        if (requiresCorrection || word.id !in completedWordIDs) return
        completedWordIDs.remove(word.id)
        pendingQueue.removeAll { it.id == word.id }
        pendingQueue.add(0, word)
    }

    /** 提前结束本轮：清空剩余词，已完成的进度保留。 */
    fun skipRemaining() {
        pendingQueue.clear()
        correctionPendingIDs.clear()
    }

    fun submitAnswer(
        rawInput: String,
        durationSeconds: Double = 2.5,
        retryOffset: Int? = null,
        newWordStrategy: NewWordDictationStrategy? = null,
    ): DictationSubmitOutcome? {
        val strategy = if (mode == DictationSessionMode.NEW_TASK) newWordStrategy else null
        val usesNewWordLadder = mode == DictationSessionMode.NEW_TASK && strategy == NewWordDictationStrategy.REPEATING
        fun ladderOffset(cycle: Int, available: Int): Int =
            if (usesNewWordLadder) newWordLadderOffset(cycle, available)
            else adaptiveRetryOffset(cycle, available)

        val targetWord = pendingQueue.firstOrNull() ?: return null
        val isMatch = DictationAnswerPolicy.matches(rawInput, targetWord.word)
        val isFirstAttempt = targetWord.id !in wordsWithInitialAttemptLogged
        wordsWithInitialAttemptLogged.add(targetWord.id)
        val now = nowProvider()

        // 长措辞只差虚词：标片段、当场重试一次；不计错、不进四轮、不进错词本。
        if (!isMatch &&
            (sessionErrorCounts[targetWord.id] ?: 0) == 0 &&
            (roundMissCountByWordID[targetWord.id] ?: 0) == 0 &&
            targetWord.id !in activeWrongRetrySet &&
            targetWord.id !in minorSlipWordIDs &&
            DictationEntryKind.classify(targetWord.word) == DictationEntryKind.LONG_PHRASE
        ) {
            val fragment = DictationPhraseDiff.minorSlip(rawInput, targetWord.word)
            if (fragment != null) {
                minorSlipWordIDs.add(targetWord.id)
                correctionPendingIDs.add(targetWord.id)
                return DictationSubmitOutcome.NeedsPhraseFix(fragment)
            }
        }

        if (isMatch) {
            if (durationSeconds > SlowReactionWordRecord.SLOW_THRESHOLD_SECONDS) {
                slowReactionWordIDs.add(targetWord.id)
            }
            pendingQueue.removeAt(0)
            val currentErrors = sessionErrorCounts[targetWord.id] ?: 0

            // 1. 当场订正后短距重现；若此前已在循环中则保留原轮次。
            if (correctionPendingIDs.remove(targetWord.id)) {
                log(targetWord, rawInput, true, false, currentErrors, durationSeconds, now)
                if (minorSlipWordIDs.remove(targetWord.id)) {
                    // 长措辞只差虚词、改对即过：不再插回队列滚动，明天做一次无提示整条回忆。
                    if (stubbornWordsMap[targetWord.id] == null) completedWordIDs.add(targetWord.id)
                    return DictationSubmitOutcome.Correct(exitedWrongQueue = false)
                }
                if (currentErrors > 5 || stubbornWordsMap[targetWord.id] != null) {
                    activeWrongRetrySet.remove(targetWord.id)
                    wrongRetryCycleByWordID.remove(targetWord.id)
                    return DictationSubmitOutcome.PromotedToStubbornWords(
                        errorCountForWordToday = maxOf(currentErrors, stubbornWordsMap[targetWord.id]?.errorCount ?: 6)
                    )
                }
                pendingQueue.removeAll { it.id == targetWord.id }
                val resumedCycle = maxOf(1, wrongRetryCycleByWordID[targetWord.id] ?: 0)
                wrongRetryCycleByWordID[targetWord.id] = resumedCycle
                if (usesNewWordLadder && (roundMissCountByWordID[targetWord.id] ?: 0) >= DictationTuning.MOVE_TO_END_AFTER_ERRORS) {
                    deferredToEndWordIDs.add(targetWord.id)
                    pendingQueue.add(targetWord)
                    return DictationSubmitOutcome.RequeuedForRetry(
                        errorCountForWordToday = currentErrors,
                        insertedAtOffset = pendingQueue.size - 1,
                    )
                }
                val chosenOffset = retryOffset ?: if (usesNewWordLadder) {
                    minOf(DictationTuning.RELEARN_STEP, pendingQueue.size)
                } else {
                    ladderOffset(resumedCycle, pendingQueue.size)
                }
                val insertionIndex = minOf(maxOf(1, chosenOffset), pendingQueue.size)
                pendingQueue.add(insertionIndex, targetWord)
                return DictationSubmitOutcome.RequeuedForRetry(
                    errorCountForWordToday = currentErrors,
                    insertedAtOffset = insertionIndex,
                )
            }

            // 2. 快速模式只要求稍后一次无提示正确召回。
            if (strategy == NewWordDictationStrategy.QUICK && targetWord.id in activeWrongRetrySet) {
                activeWrongRetrySet.remove(targetWord.id)
                wrongRetryCycleByWordID.remove(targetWord.id)
                if (stubbornWordsMap[targetWord.id] == null) completedWordIDs.add(targetWord.id)
                log(targetWord, rawInput, true, isFirstAttempt, currentErrors, durationSeconds, now)
                return DictationSubmitOutcome.Correct(exitedWrongQueue = true)
            }

            // 重复模式 / 错词复习模式：拼对后推进四轮递进循环。
            if (targetWord.id in activeWrongRetrySet) {
                val completedCycle = wrongRetryCycleByWordID[targetWord.id] ?: 1
                log(targetWord, rawInput, true, isFirstAttempt, currentErrors, durationSeconds, now)
                val totalCycles = EXPANDING_RETRY_OFFSETS.size
                val relearnTarget = if (usesNewWordLadder) relearnTargetCycleByWordID.remove(targetWord.id) else null
                if (completedCycle < totalCycles && (pendingQueue.isNotEmpty() || usesNewWordLadder)) {
                    val nextCycle = relearnTarget ?: (completedCycle + 1)
                    wrongRetryCycleByWordID[targetWord.id] = nextCycle
                    pendingQueue.removeAll { it.id == targetWord.id }
                    val targetOffset = retryOffset ?: ladderOffset(nextCycle, pendingQueue.size)
                    val insertionIndex = minOf(maxOf(1, targetOffset), pendingQueue.size)
                    pendingQueue.add(insertionIndex, targetWord)
                    return DictationSubmitOutcome.RequeuedForRetry(
                        errorCountForWordToday = currentErrors,
                        insertedAtOffset = insertionIndex,
                    )
                }
                activeWrongRetrySet.remove(targetWord.id)
                wrongRetryCycleByWordID.remove(targetWord.id)
                relearnTargetCycleByWordID.remove(targetWord.id)
                deferredToEndWordIDs.remove(targetWord.id)
                if (stubbornWordsMap[targetWord.id] == null) completedWordIDs.add(targetWord.id)
                return DictationSubmitOutcome.Correct(exitedWrongQueue = true)
            }

            // 3. 首次直接拼对
            if (stubbornWordsMap[targetWord.id] == null) completedWordIDs.add(targetWord.id)
            log(targetWord, rawInput, true, isFirstAttempt, currentErrors, durationSeconds, now)
            return DictationSubmitOutcome.Correct(exitedWrongQueue = false)
        }

        // 拼写错误：先当场订正；后几轮的词保留轮次，不因一次失误重跑全部间隔。
        val newErrorCount = maxOf(sessionErrorCounts[targetWord.id] ?: 0, stubbornWordsMap[targetWord.id]?.errorCount ?: 0) + 1
        sessionErrorCounts[targetWord.id] = newErrorCount
        val isFreshMiss = targetWord.id !in correctionPendingIDs
        correctionPendingIDs.add(targetWord.id)
        minorSlipWordIDs.remove(targetWord.id)
        activeWrongRetrySet.add(targetWord.id)
        if (usesNewWordLadder && isFreshMiss) {
            roundMissCountByWordID[targetWord.id] = (roundMissCountByWordID[targetWord.id] ?: 0) + 1
            val effectiveCycle = relearnTargetCycleByWordID[targetWord.id] ?: (wrongRetryCycleByWordID[targetWord.id] ?: 0)
            if (effectiveCycle >= 3) {
                relearnTargetCycleByWordID[targetWord.id] = effectiveCycle - 1
            } else {
                relearnTargetCycleByWordID.remove(targetWord.id)
            }
            wrongRetryCycleByWordID[targetWord.id] = 1
        } else if (wrongRetryCycleByWordID[targetWord.id] == null) {
            wrongRetryCycleByWordID[targetWord.id] = 0
        }
        log(targetWord, rawInput, false, isFirstAttempt, newErrorCount, durationSeconds, now)

        if (strategy == NewWordDictationStrategy.QUICK) {
            // 立即跳题并保留反馈卡，但不把答错的词当成完成：短距插回同一轮，稍后无提示召回。
            pendingQueue.removeAt(0)
            correctionPendingIDs.remove(targetWord.id)
            wrongRetryCycleByWordID[targetWord.id] = 1
            val targetOffset = retryOffset ?: adaptiveRetryOffset(1, pendingQueue.size)
            pendingQueue.add(minOf(maxOf(1, targetOffset), pendingQueue.size), targetWord)
        }
        if (newErrorCount > 5 || stubbornWordsMap[targetWord.id] != null) {
            stubbornWordsMap[targetWord.id] = StubbornWordRecord(
                wordID = targetWord.id,
                word = targetWord.word,
                sourceDeckID = targetWord.deckID,
                sourceDeckTitle = targetWord.deckTitle,
                dateString = dateString,
                errorCount = newErrorCount,
                triggeringSessionID = sessionID,
            )
            if (strategy != NewWordDictationStrategy.QUICK) {
                return DictationSubmitOutcome.PromotedToStubbornWords(newErrorCount)
            }
        }
        return if (strategy == NewWordDictationStrategy.QUICK) {
            DictationSubmitOutcome.SkippedIncorrect
        } else {
            DictationSubmitOutcome.NeedsCorrection(newErrorCount)
        }
    }

    private fun log(
        word: VocabularyWord,
        typed: String,
        correct: Boolean,
        firstAttempt: Boolean,
        errorCount: Int,
        durationSeconds: Double,
        now: Instant,
    ) {
        attemptLogs.add(
            DictationAttemptLog(
                id = UUID.randomUUID(),
                sessionID = sessionID,
                mode = mode,
                wordID = word.id,
                word = word.word,
                deckID = word.deckID,
                userTyped = typed,
                isCorrect = correct,
                isFirstAttemptInSession = firstAttempt,
                sessionErrorCountForWord = errorCount,
                timestamp = now,
                dateString = dateString,
                durationSeconds = durationSeconds,
            )
        )
    }

    companion object {
        /** 四次正确召回后毕业；间隔随队列长度调整。 */
        val EXPANDING_RETRY_OFFSETS: List<Int> = listOf(10, 50, 100, 200)

        /** 学习和错词复习共用间隔策略；候选词不足时在实际可穿插的词内复现。 */
        fun adaptiveRetryOffset(cycle: Int, availableWords: Int): Int {
            val available = maxOf(0, availableWords)
            if (available == 0) return 0
            val stage = maxOf(0, minOf(cycle - 1, EXPANDING_RETRY_OFFSETS.size - 1))
            val economical = listOf(10, 20, 35, 50)[stage]
            return minOf(available, economical)
        }

        /** 学新词「循环复习」的词距：严格按 5 / 55 / 155 / 255，剩余词不够时排到队尾。 */
        fun newWordLadderOffset(cycle: Int, availableWords: Int): Int {
            val available = maxOf(0, availableWords)
            if (available == 0) return 0
            val ladder = DictationTuning.newWordLadder
            val stage = maxOf(0, minOf(cycle - 1, ladder.size - 1))
            return minOf(available, ladder[stage])
        }

        /** 今天已经听对过的不同单词数（用于「今日已听」这类统计）。 */
        fun todayDictatedWordCount(logs: List<DictationAttemptLog>, dateString: String): Int =
            logs.asSequence()
                .filter { it.dateString == dateString && it.isCorrect }
                .map { it.wordID }
                .toSet()
                .size

        fun dateString(instant: Instant, zone: java.time.ZoneId = java.time.ZoneId.systemDefault()): String =
            LocalDate.ofInstant(instant, zone).toString()
    }
}
