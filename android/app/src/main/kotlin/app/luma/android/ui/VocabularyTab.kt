package app.luma.android.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.luma.android.StudyStore
import app.luma.core.VocabularyWord
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun VocabularyTab(store: StudyStore, modifier: Modifier = Modifier) {
    var query by remember { mutableStateOf("") }
    var openDeck by remember { mutableStateOf<String?>(null) }
    var openWord by remember { mutableStateOf<VocabularyWord?>(null) }

    val word = openWord
    if (word != null) {
        WordDetail(store, word, modifier) { openWord = null }
        return
    }

    val deckID = openDeck
    if (deckID != null) {
        val deck = store.deck(deckID)
        val words = deck?.words.orEmpty().filter {
            query.isBlank() || it.word.contains(query, ignoreCase = true) || it.definitionZH.contains(query)
        }
        Column(modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { openDeck = null }) { Icon(Icons.Filled.ArrowBack, contentDescription = "返回词库") }
                Text(deck?.title ?: "", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Text("${deck?.count ?: 0} 个", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                placeholder = { Text("搜索单词或释义") },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                singleLine = true,
            )
            LazyColumn(Modifier.fillMaxSize().padding(top = 8.dp)) {
                items(words, key = { it.id }) { item ->
                    Column(
                        Modifier.fillMaxWidth().clickable { openWord = item }.padding(horizontal = 20.dp, vertical = 10.dp)
                    ) {
                        Text(item.word, style = MaterialTheme.typography.titleMedium)
                        Text(
                            item.definitionZH.ifBlank { "暂无释义" },
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    HorizontalDivider()
                }
            }
        }
        return
    }

    Column(modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 16.dp)) {
        Text("词库", style = MaterialTheme.typography.displaySmall)
        Text(
            "共 ${store.words.size} 个条目",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
        )
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("搜索单词或释义") },
            leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
            singleLine = true,
        )
        val decks = store.decks
        val filteredDecks = if (query.isBlank()) {
            decks
        } else {
            decks.filter { deck -> deck.words.any { it.word.contains(query, ignoreCase = true) } }
        }
        LazyColumn(Modifier.fillMaxSize().padding(top = 12.dp)) {
            items(filteredDecks, key = { it.id }) { deck ->
                Column(
                    Modifier.fillMaxWidth().clickable { openDeck = deck.id }.padding(vertical = 14.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(deck.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                        if (deck.id == store.activeDeck?.id) {
                            Text("当前", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Medium)
                        }
                    }
                    Text(
                        "${deck.count} 个条目",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun WordDetail(
    store: StudyStore,
    word: VocabularyWord,
    modifier: Modifier = Modifier,
    onClose: () -> Unit,
) {
    val progress = store.progress(word.id)
    val formatter = remember { DateTimeFormatter.ofPattern("M 月 d 日").withZone(ZoneId.systemDefault()) }
    Column(modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onClose) { Icon(Icons.Filled.ArrowBack, contentDescription = "返回") }
            Text(word.deckTitle, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
        }
        Column(Modifier.fillMaxSize().padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(word.word, style = MaterialTheme.typography.displaySmall)
            if (word.phonetic.isNotBlank()) {
                Text(word.phonetic, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(word.definitionZH.ifBlank { "暂无释义" }, style = MaterialTheme.typography.bodyLarge)
            if (word.exampleSentence.isNotBlank()) {
                Text(word.exampleSentence, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            Text(
                progress?.let {
                    "复习档位 ${it.stage} · 下次 ${formatter.format(it.dueAt)}" +
                        if (it.lapses > 0) " · 漏答 ${it.lapses} 次" else ""
                } ?: "还没复习过",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (progress == null) {
                Text(
                    "在听写里出现过之后才有复习记录。",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                "最近复习：" + (progress?.lastReviewedAt?.let { formatter.format(it) } ?: "—") +
                    " · 今天 " + formatter.format(Instant.now()),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
