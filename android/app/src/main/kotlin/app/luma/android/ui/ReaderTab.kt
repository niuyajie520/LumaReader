package app.luma.android.ui

import android.annotation.SuppressLint
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import app.luma.android.Book
import app.luma.android.BookLibrary
import app.luma.android.StudyStore

private fun readerHtml(chapterHtml: String, dark: Boolean, fontSize: Int): String = """
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  :root { --paper: ${if (dark) "#141210" else "#FBF7F0"}; --ink: ${if (dark) "#EDE6DC" else "#1A1714"}; }
  html, body { margin: 0; padding: 0; background: var(--paper); color: var(--ink);
    font-family: "New York", "Songti SC", Georgia, serif;
    font-size: ${fontSize}px; line-height: 1.62; -webkit-text-size-adjust: 100%; }
  #luma-content { padding: 8px 20px 32px; }
  p { margin: 0 0 1.05em; }
  img { max-width: 100%; height: auto; }
  h1, h2, h3 { line-height: 1.25; }
</style></head>
<body><main id="luma-content">$chapterHtml</main>
<script>
(function(){
  function wordAt(x, y) {
    var el = document.elementFromPoint(x, y);
    if (!el) return null;
    var range = document.caretRangeFromPoint ? document.caretRangeFromPoint(x, y) : null;
    if (!range) return null;
    var node = range.startContainer;
    if (!node || node.nodeType !== 3) return null;
    var text = node.textContent || "";
    var offset = range.startOffset;
    var start = offset, end = offset;
    while (start > 0 && /[A-Za-z'-]/.test(text[start - 1])) start--;
    while (end < text.length && /[A-Za-z'-]/.test(text[end])) end++;
    var word = text.slice(start, end).replace(/^['-]+|['-]+$$/g, "");
    return word.length > 1 ? word : null;
  }
  var startX = 0, startY = 0, moved = false;
  document.addEventListener('touchstart', function(e){
    if (e.touches.length !== 1) return;
    startX = e.touches[0].clientX; startY = e.touches[0].clientY; moved = false;
  }, {passive: true});
  document.addEventListener('touchmove', function(e){
    if (e.touches.length !== 1) return;
    if (Math.abs(e.touches[0].clientX - startX) > 10 || Math.abs(e.touches[0].clientY - startY) > 10) moved = true;
  }, {passive: true});
  document.addEventListener('touchend', function(e){
    if (moved || e.changedTouches.length !== 1) return;
    var word = wordAt(e.changedTouches[0].clientX, e.changedTouches[0].clientY);
    if (word && window.LumaAndroid) window.LumaAndroid.onWordTap(word);
  }, {passive: true});
})();
</script>
</body></html>
""".trimIndent()

@Composable
fun ReaderTab(store: StudyStore, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var shelf by remember { mutableStateOf(BookLibrary.shelf(context)) }
    var openBook by remember { mutableStateOf<Book?>(null) }
    var chapterIndex by remember { mutableStateOf(0) }
    var lookupWord by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val name = queryDisplayName(context, uri)
            BookLibrary.importBook(context, uri, name)
            shelf = BookLibrary.shelf(context)
        }
    }

    val book = openBook
    if (book == null) {
        Column(modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text("阅读", style = MaterialTheme.typography.displaySmall)
            }
            if (shelf.isEmpty()) {
                Column(
                    Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("书架还是空的", style = MaterialTheme.typography.titleLarge)
                    Text(
                        "导入 EPUB 或 TXT 开始阅读。",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 8.dp, bottom = 20.dp),
                    )
                    Button(onClick = { picker.launch(arrayOf("application/epub+zip", "text/plain", "*/*")) }) {
                        Text("导入书籍")
                    }
                }
            } else {
                LazyColumn(Modifier.fillMaxSize()) {
                    items(shelf, key = { it.id }) { item ->
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    openBook = item
                                    chapterIndex = 0
                                }
                                .padding(vertical = 12.dp)
                        ) {
                            Text(item.title, style = MaterialTheme.typography.titleMedium)
                            Text(
                                listOf(item.author, "${item.chapters.size} 章").filter { it.isNotBlank() }.joinToString(" · "),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        HorizontalDivider()
                    }
                }
                OutlinedButton(
                    onClick = { picker.launch(arrayOf("application/epub+zip", "text/plain", "*/*")) },
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                ) {
                    Icon(Icons.Filled.Add, contentDescription = null)
                    Text(" 导入书籍")
                }
            }
        }
        return
    }

    val chapter = book.chapters.getOrNull(chapterIndex)
    Column(modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { openBook = null }) { Icon(Icons.Filled.ArrowBack, contentDescription = "返回书架") }
            Text(book.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
        }
        Box(Modifier.weight(1f)) {
            if (chapter != null) {
                ChapterWebView(
                    chapter = chapter,
                    fontSize = 19,
                    modifier = Modifier.fillMaxSize(),
                    onWordTap = { word -> lookupWord = word },
                )
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(
                onClick = { if (chapterIndex > 0) chapterIndex -= 1 },
                enabled = chapterIndex > 0,
            ) {
                Icon(Icons.Filled.ChevronLeft, contentDescription = null)
                Text("上一章")
            }
            Text(
                "第 ${chapterIndex + 1} / ${book.chapters.size} 章",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TextButton(
                onClick = { if (chapterIndex < book.chapters.lastIndex) chapterIndex += 1 },
                enabled = chapterIndex < book.chapters.lastIndex,
            ) {
                Text("下一章")
                Icon(Icons.Filled.ChevronRight, contentDescription = null)
            }
        }
    }

    val word = lookupWord
    if (word != null) {
        WordLookupDialog(
            word = word,
            store = store,
            onDismiss = { lookupWord = null },
        )
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun ChapterWebView(
    chapter: app.luma.android.Chapter,
    fontSize: Int,
    modifier: Modifier = Modifier,
    onWordTap: (String) -> Unit,
) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.allowFileAccess = true
                settings.textZoom = 100
                webViewClient = WebViewClient()
                addJavascriptInterface(object {
                    @JavascriptInterface
                    fun onWordTap(word: String) = onWordTap(word)
                }, "LumaAndroid")
                loadDataWithBaseURL("file:///", readerHtml(chapter.html, dark, fontSize), "text/html", "utf-8", null)
            }
        },
        update = { webView ->
            if (webView.tag != chapter.href) {
                webView.tag = chapter.href
                webView.loadDataWithBaseURL("file:///", readerHtml(chapter.html, dark, fontSize), "text/html", "utf-8", null)
            }
        },
    )
}

@Composable
private fun WordLookupDialog(word: String, store: StudyStore, onDismiss: () -> Unit) {
    val entry = remember(word) {
        store.words.firstOrNull { it.word.equals(word, ignoreCase = true) }
    }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(word, style = MaterialTheme.typography.titleLarge) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (entry != null) {
                    Text(entry.definitionZH.ifBlank { "这个词还没有释义" })
                    if (entry.phonetic.isNotBlank()) {
                        Text(entry.phonetic, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                } else {
                    Text("内置词表没有收录。")
                    Text(
                        "可以把它加进阅读生词本，之后就能在听写里复习。",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        },
        confirmButton = {
            if (entry == null) {
                TextButton(onClick = {
                    store.addWord(word.lowercase(), "")
                    onDismiss()
                }) { Text("加入生词本") }
            } else {
                TextButton(onClick = onDismiss) { Text("关闭") }
            }
        },
        dismissButton = {
            if (entry == null) TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

private fun queryDisplayName(context: android.content.Context, uri: android.net.Uri): String? {
    val cursor = context.contentResolver.query(uri, null, null, null, null) ?: return null
    cursor.use {
        val index = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
        if (index >= 0 && it.moveToFirst()) return it.getString(index)
    }
    return null
}
