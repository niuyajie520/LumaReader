package app.luma.android

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * 云同步：用户用系统文件选择器授权一个目录（iCloud Drive / Google Drive / 本地同步盘都行），
 * 每台设备往目录里写一份 `device-<id>.json`，同步时读别人那几份合进来。
 *
 * 和 iOS 版是同一套约定，所以 iPhone 与 Android 可以互相同步。
 */
class SyncManager(private val context: Context) {

    companion object {
        private const val TAG = "LumaSync"
        private const val PREFS = "luma.sync"
        private const val KEY_FOLDER = "folderUri"
        private const val KEY_LAST = "lastSync"
        private const val KEY_DEVICE = "deviceID"
        private val ISO = DateTimeFormatter.ISO_INSTANT
    }

    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    val folderUri: Uri? get() = prefs.getString(KEY_FOLDER, null)?.let(Uri::parse)

    val lastSyncAt: Instant? get() = prefs.getLong(KEY_LAST, 0L).takeIf { it > 0 }?.let(Instant::ofEpochMilli)

    val deviceID: String
        get() = prefs.getString(KEY_DEVICE, null) ?: run {
            val id = "android-" + UUID.randomUUID().toString().take(8)
            prefs.edit().putString(KEY_DEVICE, id).apply()
            id
        }

    fun attachFolder(uri: Uri) {
        runCatching {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        }.onFailure { Log.w(TAG, "拿到持久授权失败（重启后可能要重新选目录）", it) }
        prefs.edit().putString(KEY_FOLDER, uri.toString()).apply()
    }

    fun disconnect() {
        prefs.edit().remove(KEY_FOLDER).remove(KEY_LAST).apply()
    }

    /** 读共享目录里所有设备文件合并进本地，再把本地写回自己的那份。返回合并了几个文件。 */
    fun sync(store: StudyStore): Int {
        val folder = folderUri?.let { DocumentFile.fromTreeUri(context, it) } ?: return 0
        if (!folder.exists() || !folder.canRead()) return 0
        var merged = 0
        folder.listFiles()
            .filter { it.isFile && (it.name?.startsWith("device-") == true) && it.name?.endsWith(".json") == true }
            .filter { it.name != "device-${deviceID}.json" }
            .forEach { file ->
                val text = runCatching {
                    context.contentResolver.openInputStream(file.uri)?.bufferedReader()?.use { it.readText() }
                }.getOrNull() ?: return@forEach
                if (store.importStore(text)) merged += 1
            }
        writeOwn(folder, store)
        prefs.edit().putLong(KEY_LAST, System.currentTimeMillis()).apply()
        return merged
    }

    private fun writeOwn(folder: DocumentFile, store: StudyStore) {
        val name = "device-${deviceID}.json"
        val existing = folder.findFile(name)
        val file = existing ?: folder.createFile("application/json", name) ?: return
        val payload = store.exportText()
        runCatching {
            context.contentResolver.openOutputStream(file.uri, "wt")?.use { out ->
                out.write(payload.toByteArray(Charsets.UTF_8))
            }
        }.onFailure { Log.e(TAG, "写同步文件失败", it) }
    }

    fun statusLine(): String {
        val folder = folderUri?.lastPathSegment ?: return "未选择同步文件夹"
        val last = lastSyncAt?.let { "上次同步 " + ISO.format(it) } ?: "还没同步过"
        return "$folder · $last"
    }
}
