package app.luma.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.luma.android.DictationScope
import app.luma.android.DictationSession
import app.luma.android.Speaker
import app.luma.android.StudyStore
import app.luma.android.SyncManager
import app.luma.core.DictationSubmitOutcome
import app.luma.core.NewWordDictationStrategy
import app.luma.core.VocabularyDeck
import java.time.Instant

private sealed interface Feedback {
    data object None : Feedback
    data object Correct : Feedback
    data class Wrong(val count: Int) : Feedback
    data class PhraseFix(val fragment: String) : Feedback
    data object Moved : Feedback
}

@Composable
fun DictationTab(
    store: StudyStore,
    speaker: Speaker,
    sync: SyncManager,
    onActiveChange: (Boolean) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    var session by remember { mutableStateOf<DictationSession?>(null) }
    val deck = store.activeDeck

    LaunchedEffect(session != null) { onActiveChange(session != null) }

    if (session == null) {
        DictationHome(store, speaker, deck, modifier) { newSession -> session = newSession }
    } else {
        DictationRunner(
            modifier = modifier,
            session = session!!,
            speaker = speaker,
            store = store,
            onFinish = {
                session = null
                runCatching { sync.sync(store) }
            },
        )
    }
}

@Composable
private fun DictationHome(
    store: StudyStore,
    speaker: Speaker,
    deck: VocabularyDeck?,
    modifier: Modifier = Modifier,
    onStart: (DictationSession) -> Unit,
) {
    var scope by rememberSaveable { mutableStateOf(DictationScope.DUE_FIRST.name) }
    var strategy by rememberSaveable { mutableStateOf(NewWordDictationStrategy.QUICK.name) }
    var limit by rememberSaveable { mutableStateOf(20) }
    val dueCount = store.dueReviews().size

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Text("听写", style = MaterialTheme.typography.displaySmall)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(deck?.title ?: "还没有词表", style = MaterialTheme.typography.titleLarge)
            Text(
                "${deck?.count ?: 0} 个条目",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "$dueCount 个到期",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Button(
            onClick = {
                val queue = DictationSession.buildQueue(store, deck?.id, DictationScope.valueOf(scope), limit)
                if (queue.isNotEmpty()) {
                    onStart(
                        DictationSession(
                            deckID = deck?.id ?: "",
                            deckTitle = deck?.title ?: "",
                            words = queue,
                            strategy = NewWordDictationStrategy.fromRaw(strategy) ?: NewWordDictationStrategy.QUICK,
                        )
                    )
                }
            },
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) {
            Icon(Icons.Filled.VolumeUp, contentDescription = null)
            Spacer(Modifier.fillMaxWidth(0.03f))
            Text("开始听写", style = MaterialTheme.typography.titleMedium)
        }

        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("范围", style = MaterialTheme.typography.titleMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    DictationScope.entries.take(2).forEach { item ->
                        LumaChip(
                            label = item.label,
                            selected = scope == item.name,
                            onClick = { scope = item.name },
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    DictationScope.entries.drop(2).forEach { item ->
                        LumaChip(
                            label = item.label,
                            selected = scope == item.name,
                            onClick = { scope = item.name },
                        )
                    }
                }
                Text("策略", style = MaterialTheme.typography.titleMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    LumaChip(
                        label = "快速过词",
                        selected = strategy == NewWordDictationStrategy.QUICK.name,
                        onClick = { strategy = NewWordDictationStrategy.QUICK.name },
                    )
                    LumaChip(
                        label = "循环复习",
                        selected = strategy == NewWordDictationStrategy.REPEATING.name,
                        onClick = { strategy = NewWordDictationStrategy.REPEATING.name },
                    )
                }
                Text("本轮词数", style = MaterialTheme.typography.titleMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(10, 20, 30, 50).forEach { count ->
                        LumaChip(
                            label = "$count",
                            selected = limit == count,
                            onClick = { limit = count },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DictationRunner(
    session: DictationSession,
    speaker: Speaker,
    store: StudyStore,
    modifier: Modifier = Modifier,
    onFinish: () -> Unit,
) {
    var input by remember { mutableStateOf("") }
    var feedback by remember { mutableStateOf<Feedback>(Feedback.None) }
    var revealed by remember { mutableStateOf(false) }
    var missedAnswer by remember { mutableStateOf<String?>(null) }
    var submittedAt by remember { mutableStateOf(Instant.now()) }
    var showSummary by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }

    val word = session.current
    if (word == null || showSummary) {
        SummaryCard(session, onFinish)
        return
    }

    Column(
        // 窗口本身是 adjustResize，键盘弹出时已经被压缩，再加 imePadding 会重复占位。
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = {
                session.finish()
                showSummary = true
            }) { Text("结束") }
            Spacer(Modifier.fillMaxWidth(0.5f))
            Text(
                "剩 ${session.remainingCount} · 已过 ${session.correctCount}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        LinearProgressIndicator(
            progress = {
                if (session.totalWords == 0) 0f
                else (session.totalWords - session.remainingCount).toFloat() / session.totalWords
            },
            modifier = Modifier.fillMaxWidth().height(6.dp),
            gapSize = 0.dp,
            drawStopIndicator = {},
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
        Column(
            modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        ) {
            Column(
                Modifier.fillMaxWidth().padding(vertical = 28.dp, horizontal = 18.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                IconButton(onClick = {
                    speaker.speak(word.word)
                    submittedAt = Instant.now()
                }) {
                    Icon(Icons.Filled.VolumeUp, contentDescription = "再听一次", modifier = Modifier.height(48.dp))
                }
                if (revealed) {
                    Text(word.word, style = MaterialTheme.typography.displaySmall, textAlign = TextAlign.Center)
                    if (word.phonetic.isNotBlank()) {
                        Text(word.phonetic, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                } else {
                    Text(
                        word.shortDefinition.ifBlank { "暂无释义" },
                        style = MaterialTheme.typography.titleLarge,
                        textAlign = TextAlign.Center,
                    )
                }
                feedbackLine(feedback)
                missedAnswer?.let {
                    Text(
                        "刚才那个词：$it",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(onClick = {
                revealed = true
                speaker.speak(word.word)
            }, modifier = Modifier.weight(1f)) {
                Icon(Icons.Filled.Visibility, contentDescription = null)
                Spacer(Modifier.fillMaxWidth(0.06f))
                Text("看答案")
            }
            OutlinedButton(onClick = { speaker.speak(word.word) }, modifier = Modifier.weight(1f)) {
                Icon(Icons.Filled.Refresh, contentDescription = null)
                Spacer(Modifier.fillMaxWidth(0.06f))
                Text("再听")
            }
        }
        }

        OutlinedTextField(
            value = input,
            onValueChange = { input = it },
            modifier = Modifier.fillMaxWidth().focusRequester(focus),
            placeholder = { Text("照着听到的拼写") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.None,
                autoCorrectEnabled = false,
                imeAction = ImeAction.Done,
            ),
        )

        Button(
            onClick = {
                val seconds = (Instant.now().toEpochMilli() - submittedAt.toEpochMilli()) / 1000.0
                val outcome = session.submit(input, maxOf(0.5, seconds))
                session.drainLogs().forEach { log ->
                    store.appendLog(log)
                    store.recordReview(
                        wordID = log.wordID,
                        cleanRecall = log.isCorrect,
                        reactionSeconds = log.durationSeconds,
                        at = log.timestamp,
                    )
                }
                feedback = when (outcome) {
                    is DictationSubmitOutcome.Correct -> Feedback.Correct
                    is DictationSubmitOutcome.NeedsCorrection -> Feedback.Wrong(outcome.errorCountForWordToday)
                    is DictationSubmitOutcome.NeedsPhraseFix -> {
                        revealed = false
                        Feedback.PhraseFix(outcome.fragment)
                    }
                    is DictationSubmitOutcome.RequeuedForRetry -> Feedback.Moved
                    is DictationSubmitOutcome.PromotedToStubbornWords -> {
                        store.markStubborn(word, session.sessionID)
                        Feedback.Moved
                    }
                    DictationSubmitOutcome.SkippedIncorrect -> Feedback.Moved
                    null -> Feedback.None
                }
                missedAnswer = when (outcome) {
                    DictationSubmitOutcome.SkippedIncorrect, is DictationSubmitOutcome.RequeuedForRetry -> word.word
                    else -> null
                }
                input = ""
                revealed = false
                submittedAt = Instant.now()
                if (session.isFinished) showSummary = true
            },
            enabled = input.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text(if (session.requiresCorrection) "继续" else "提交") }
    }
}

@Composable
private fun feedbackLine(feedback: Feedback) {
    when (feedback) {
        Feedback.None -> Unit
        Feedback.Correct -> Text("对了", color = LumaTokens.Positive, fontWeight = FontWeight.Medium)
        is Feedback.Wrong -> Text(
            "再拼一次，本轮第 ${feedback.count} 次",
            color = LumaTokens.Warning,
            fontWeight = FontWeight.Medium,
        )
        is Feedback.PhraseFix -> Text(
            "只差「${feedback.fragment}」，按整条措辞重拼一次",
            color = LumaTokens.Warning,
            fontWeight = FontWeight.Medium,
        )
        Feedback.Moved -> Text("挪到本轮最后", color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun SummaryCard(session: DictationSession, onFinish: () -> Unit) {
    Surface(Modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("本轮结束", style = MaterialTheme.typography.displaySmall)
            Text("完成 ${session.totalWords - session.remainingCount} 个词", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Box(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp)).padding(16.dp)) {
                Column {
                    Text("答对 ${session.correctCount}")
                    Text("有错 ${session.wrongCount}")
                }
            }
            Button(onClick = onFinish, modifier = Modifier.fillMaxWidth().height(52.dp)) { Text("回到听写") }
        }
    }
}
