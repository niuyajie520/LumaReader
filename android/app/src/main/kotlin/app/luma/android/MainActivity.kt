package app.luma.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import app.luma.android.ui.DictationTab
import app.luma.android.ui.ReaderTab
import app.luma.android.ui.SettingsTab
import app.luma.android.ui.VocabularyTab
import app.luma.android.ui.LumaTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LumaTheme {
                LumaRoot()
            }
        }
    }
}

private enum class Tab(val title: String) {
    DICTATION("听写"),
    READER("阅读"),
    VOCABULARY("词库"),
    SETTINGS("设置"),
}

@Composable
private fun LumaRoot() {
    val context = LocalContext.current
    val store = remember { StudyStore(context).also { it.load() } }
    val speaker = remember { Speaker(context).also { it.start() } }
    val sync = remember { SyncManager(context) }
    var tab by rememberSaveable { mutableStateOf(Tab.DICTATION.name) }
    var dictationActive by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        onDispose { speaker.shutdown() }
    }

    LaunchedEffect(Unit) {
        runCatching { sync.sync(store) }
    }

    val current = Tab.valueOf(tab)
    Scaffold(
        modifier = Modifier.fillMaxSize(),
        contentWindowInsets = WindowInsets.safeDrawing,
        bottomBar = {
            if (dictationActive) return@Scaffold
            NavigationBar {
                Tab.entries.forEach { item ->
                    val icon = when (item) {
                        Tab.DICTATION -> Icons.Filled.VolumeUp
                        Tab.READER -> Icons.Filled.MenuBook
                        Tab.VOCABULARY -> Icons.Filled.Layers
                        Tab.SETTINGS -> Icons.Filled.Settings
                    }
                    NavigationBarItem(
                        selected = current == item,
                        onClick = { tab = item.name },
                        icon = { Icon(icon, contentDescription = item.title) },
                        label = { Text(item.title) },
                    )
                }
            }
        },
    ) { padding ->
        val modifier = Modifier.padding(padding)
        when (current) {
            Tab.DICTATION -> DictationTab(
                store = store,
                speaker = speaker,
                sync = sync,
                onActiveChange = { dictationActive = it },
                modifier = modifier,
            )
            Tab.READER -> ReaderTab(store, modifier)
            Tab.VOCABULARY -> VocabularyTab(store, modifier)
            Tab.SETTINGS -> SettingsTab(store, speaker, sync, modifier)
        }
    }
}
