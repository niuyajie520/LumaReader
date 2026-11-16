package app.luma.android

import app.luma.core.DictationAnswerPolicy
import app.luma.core.DictationAttemptLog
import app.luma.core.DictationEntryKind
import app.luma.core.DictationSessionMode
import app.luma.core.DictationSessionStateMachine
import app.luma.core.DictationSubmitOutcome
import app.luma.core.NewWordDictationStrategy
import app.luma.core.VocabularyWord
import java.time.Instant
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/** 听写范围：与 iPhone 版一致，四种取词方式。 */
enum class DictationScope(val label: String) {
    DUE_FIRST("到期优先"),
    DUE_ONLY("只做到期"),
    ALL("整本词表"),
    WRONG_ONLY("只做错词"),
}

enum class SessionPhase { IDLE, AWAITING_ANSWER, CORRECTING, FINISHED }

/**
 * 听写会话的 UI 壳：状态机在 `core` 里，这里只负责
 * 「当前词是谁、上一笔提交是什么结果、日志攒到哪儿」。
 */
class DictationSession(
    val deckID: String,
    val deckTitle: String,
    words: List<VocabularyWord>,
    val strategy: NewWordDictationStrategy = NewWordDictationStrategy.QUICK,
    val sessionID: UUID = UUID.randomUUID(),
    val mode: DictationSessionMode = DictationSessionMode.NEW_TASK,
    private val dateString: String = DictationSessionStateMachineDate.today(),
) {
    val machine = DictationSessionStateMachine(
        sessionID = sessionID,
        mode = mode,
        dateString = dateString,
        initialWords = words,
        originDeck = deckID,
    )

    private var drainedLogCount = 0
    var startedAt: Instant = Instant.now()
        private set

    val current: VocabularyWord? get() = machine.currentWord
    val totalWords: Int get() = machine.initialWordCount
    val remainingCount: Int get() = machine.pendingQueue.size
    val correctCount: Int get() = machine.completedWordIDs.size
    val wrongCount: Int get() = machine.sessionErrorCounts.count { it.value > 0 }
    val isFinished: Boolean get() = machine.isSessionFinished
    val requiresCorrection: Boolean get() = machine.requiresCorrection

    val phase: SessionPhase
        get() = when {
            machine.isSessionFinished -> SessionPhase.FINISHED
            machine.requiresCorrection -> SessionPhase.CORRECTING
            else -> SessionPhase.AWAITING_ANSWER
        }

    fun errorCount(wordID: String): Int = machine.sessionErrorCounts[wordID] ?: 0

    fun revealAnswer(): String? = current?.word

    /** 提交一次拼写；返回状态机结果，界面据此给反馈。 */
    fun submit(input: String, durationSeconds: Double): DictationSubmitOutcome? {
        val outcome = machine.submitAnswer(
            rawInput = input,
            durationSeconds = durationSeconds,
            newWordStrategy = if (strategy == NewWordDictationStrategy.REPEATING) {
                NewWordDictationStrategy.REPEATING
            } else {
                NewWordDictationStrategy.QUICK
            },
        )
        return outcome
    }

    /** 取走新产生的日志（每笔提交都会写一条）。 */
    fun drainLogs(): List<DictationAttemptLog> {
        if (drainedLogCount >= machine.attemptLogs.size) return emptyList()
        val fresh = machine.attemptLogs.subList(drainedLogCount, machine.attemptLogs.size).toList()
        drainedLogCount = machine.attemptLogs.size
        return fresh
    }

    fun finish() {
        machine.skipRemaining()
    }

    companion object {
        fun isLongPhrase(word: String): Boolean =
            DictationEntryKind.classify(word) == DictationEntryKind.LONG_PHRASE

        fun matches(input: String, target: String): Boolean = DictationAnswerPolicy.matches(input, target)

        /** 取词：到期词先做，再按词表顺序；上限由调用方给。 */
        fun buildQueue(
            store: StudyStore,
            deckID: String?,
            scope: DictationScope,
            limit: Int,
        ): List<VocabularyWord> {
            val pool = deckID?.let { store.deck(it)?.words } ?: store.words
            val due = pool.filter { app.luma.core.WordReviewOrdering.isDueForNextDayRecall(store.progress(it.id)) }
            val ordered = when (scope) {
                DictationScope.DUE_FIRST -> due + pool.filter { it !in due }
                DictationScope.DUE_ONLY -> due
                DictationScope.WRONG_ONLY -> pool.filter { word ->
                    store.wrongWords(sessionID = null, deckID = null).any { it.wordID == word.id }
                }
                DictationScope.ALL -> pool
            }
            return ordered.distinctBy { it.id }.take(max(1, min(limit, 200)))
        }
    }
}
