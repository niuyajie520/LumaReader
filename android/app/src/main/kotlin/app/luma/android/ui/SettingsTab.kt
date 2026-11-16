package app.luma.android.ui

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import app.luma.android.Speaker
import app.luma.android.StudyStore
import app.luma.android.SyncManager
import kotlin.math.roundToInt

@Composable
fun SettingsTab(store: StudyStore, speaker: Speaker, sync: SyncManager, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var rate by remember { mutableFloatStateOf(speaker.rate) }
    var repeat by remember { mutableIntStateOf(speaker.repeatCount) }
    var accent by remember { mutableStateOf(speaker.accent) }
    var status by remember { mutableStateOf(sync.statusLine()) }
    var message by remember { mutableStateOf<String?>(null) }

    val folderPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) {
            sync.attachFolder(uri)
            status = sync.statusLine()
            val merged = runCatching { sync.sync(store) }.getOrDefault(0)
            message = "已选择同步文件夹，合并了 $merged 份设备数据"
            status = sync.statusLine()
        }
    }
    val storePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val text = runCatching {
                context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
            }.getOrNull()
            val ok = text != null && store.importStore(text, replace = store.isStarterOnly)
            message = if (ok) "已导入，词条 ${store.words.size} 个" else "导入失败：不是有效的数据文件"
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("设置", style = MaterialTheme.typography.displaySmall)

        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("朗读", style = MaterialTheme.typography.titleMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Speaker.Accent.entries.forEach { item ->
                        LumaChip(
                            label = item.label,
                            selected = accent == item,
                            onClick = {
                                accent = item
                                speaker.accent = item
                                speaker.speak("atmosphere")
                            },
                        )
                    }
                }
                Text("语速 ${"%.2f".format(rate)}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Slider(
                    value = rate,
                    onValueChange = {
                        rate = it
                        speaker.rate = it
                    },
                    valueRange = 0.2f..0.8f,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("每词朗读 $repeat 遍", modifier = Modifier.weight(1f))
                    OutlinedButton(onClick = { if (repeat > 1) { repeat -= 1; speaker.repeatCount = repeat } }) { Text("－") }
                    OutlinedButton(onClick = { if (repeat < 3) { repeat += 1; speaker.repeatCount = repeat } }) { Text("＋") }
                }
                Text(
                    "使用系统自带英语语音，离线可用。",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("云同步", style = MaterialTheme.typography.titleMedium)
                Text(status, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(onClick = { folderPicker.launch(null) }, modifier = Modifier.fillMaxWidth()) {
                    Text("选择同步文件夹")
                }
                OutlinedButton(
                    onClick = {
                        val merged = runCatching { sync.sync(store) }.getOrDefault(0)
                        message = if (sync.folderUri == null) "还没选择同步文件夹" else "已同步，合并了 $merged 份"
                        status = sync.statusLine()
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("立即同步") }
                Text(
                    "在系统文件选择器里选一个云盘目录（iCloud Drive、Google Drive 都可以）。" +
                        "每台设备写一份 device-*.json，同步时合并词库与复习进度。",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (sync.folderUri != null) {
                    OutlinedButton(onClick = {
                        sync.disconnect()
                        status = sync.statusLine()
                        message = "已断开同步文件夹"
                    }) { Text("断开同步") }
                }
            }
        }

        Card {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("学习数据", style = MaterialTheme.typography.titleMedium)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("词条"); Text("${store.words.size} 个")
                }
                HorizontalDivider()
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("复习记录"); Text("${store.schedule.size} 个")
                }
                HorizontalDivider()
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("听写日志"); Text("${store.logs.size} 条")
                }
                HorizontalDivider()
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("顽固词"); Text("${store.stubborn.size} 个")
                }
                OutlinedButton(
                    onClick = { storePicker.launch(arrayOf("application/json", "*/*")) },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("导入 Mac / iPhone 的数据文件") }
                OutlinedButton(
                    onClick = {
                        store.saveNow()
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = "application/json"
                            putExtra(Intent.EXTRA_TEXT, store.exportText())
                        }
                        context.startActivity(Intent.createChooser(share, "导出学习数据"))
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("导出数据") }
            }
        }

        message?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary)
        }

        Text(
            "Luma Reader Android 1.0.0 · 与 macOS 1.33 / iPhone 1.0 共用同一套判题与复习规则",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}
