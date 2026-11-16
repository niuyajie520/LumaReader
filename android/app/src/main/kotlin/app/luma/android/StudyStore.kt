package app.luma.android

import android.content.Context
import android.util.Log
import app.luma.core.DictationAttemptLog
import app.luma.core.DictationSessionMode
import app.luma.core.SlowReactionWordRecord
import app.luma.core.StubbornWordRecord
import app.luma.core.SyncMerge
import app.luma.core.VocabularyDeck
import app.luma.core.VocabularyWord
import app.luma.core.WordReviewOrdering
import app.luma.core.WordReviewProgress
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * 学习数据的读写层。
 *
 * 存储格式刻意与 macOS 版 `luma_study_store.json` 完全一致：
 * 顶层保留原始字段（`raw`），只覆盖自己管理的几个键，所以
 * 「Mac 导出 → 安卓导入 → 再导回 Mac」不会丢字段。
 */
class StudyStore(private val context: Context) {

    companion object {
        private const val TAG = "LumaStore"
        private const val FILE_NAME = "luma_study_store.json"
        const val STARTER_DECK_ID = "android.reading.core"
        const val STARTER_DECK_TITLE = "阅读词表"
        private val ISO = DateTimeFormatter.ISO_INSTANT
    }

    private val dir: File = File(context.filesDir, "StudyCenter").apply { mkdirs() }
    private val file: File = File(dir, FILE_NAME)
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private var saveJob: Job? = null

    private var raw: JSONObject = JSONObject()

    var words: MutableList<VocabularyWord> = mutableListOf()
        private set
    var schedule: MutableMap<String, WordReviewProgress> = mutableMapOf()
        private set
    var logs: MutableList<DictationAttemptLog> = mutableListOf()
        private set
    var stubborn: MutableList<StubbornWordRecord> = mutableListOf()
        private set
    var slowReaction: MutableList<SlowReactionWordRecord> = mutableListOf()
        private set
    var dailyReading: MutableMap<String, Int> = mutableMapOf()
        private set
    var selectedDeckID: String? = null

    val decks: List<VocabularyDeck>
        get() = words.groupBy { it.deckID }
            .map { (deckID, list) -> VocabularyDeck(deckID, list.first().deckTitle.ifBlank { deckID }, list) }

    val activeDeck: VocabularyDeck?
        get() = selectedDeckID?.let { id -> decks.firstOrNull { it.id == id } } ?: decks.firstOrNull()

    val isStarterOnly: Boolean
        get() = words.isNotEmpty() && decks.all { it.id == STARTER_DECK_ID }

    fun load() {
        if (file.exists()) {
            raw = runCatching { JSONObject(file.readText()) }.getOrElse {
                Log.w(TAG, "store 解析失败，按空数据启动", it)
                JSONObject()
            }
        }
        words = decodeWords(raw.optJSONArray("importedWords")).toMutableList()
        schedule = decodeSchedule(raw.optJSONObject("reviewSchedule")).toMutableMap()
        logs = decodeLogs(raw.optJSONArray("dictationLogs")).toMutableList()
        stubborn = decodeStubborn(raw.optJSONArray("stubbornWords")).toMutableList()
        slowReaction = decodeSlow(raw.optJSONArray("slowReactionWords")).toMutableList()
        dailyReading = decodeDailyReading(raw.optJSONObject("dailyReadingSeconds")).toMutableMap()
        selectedDeckID = raw.optJSONObject("workspace")?.optString("selectedDeckID")?.takeIf { it.isNotBlank() }
        if (words.isEmpty()) seedStarterDeck()
        if (selectedDeckID == null) selectedDeckID = decks.firstOrNull()?.id
    }

    /** 首次打开时用内置的 6063 条阅读词表播种，避免空壳。 */
    private fun seedStarterDeck() {
        val seeded = runCatching { readBundledReadingWords(context) }.getOrElse {
            Log.w(TAG, "内置词表读取失败", it)
            emptyList()
        }
        if (seeded.isNotEmpty()) {
            words = seeded.toMutableList()
            selectedDeckID = STARTER_DECK_ID
            scheduleSave()
        }
    }

    // MARK: - 查询

    fun deck(id: String): VocabularyDeck? = decks.firstOrNull { it.id == id }

    fun progress(wordID: String): WordReviewProgress? = schedule[wordID]

    fun recordReview(wordID: String, cleanRecall: Boolean, reactionSeconds: Double?, at: Instant = Instant.now()) {
        val progress = schedule[wordID] ?: WordReviewProgress()
        progress.record(cleanRecall = cleanRecall, reactionSeconds = reactionSeconds, now = at)
        schedule[wordID] = progress
        scheduleSave()
    }

    fun dueReviews(): List<VocabularyWord> =
        words.filter { WordReviewOrdering.isDueForNextDayRecall(schedule[it.id]) }

    fun reviewQueue(deckID: String?, limit: Int): List<VocabularyWord> {
        val pool = deckID?.let { deck(it)?.words } ?: words
        return WordReviewOrdering.dueFirst(pool, schedule).take(limit)
    }

    fun appendLog(log: DictationAttemptLog) {
        logs.add(log)
        scheduleSave()
    }

    fun appendLogs(newLogs: List<DictationAttemptLog>) {
        logs.addAll(newLogs)
        scheduleSave()
    }

    fun wrongWords(sessionID: UUID?, deckID: String?): List<DictationAttemptLog> {
        var result = logs.filter { !it.isCorrect }
        if (sessionID != null) result = result.filter { it.sessionID == sessionID }
        if (deckID != null) result = result.filter { it.deckID == deckID }
        return result.sortedByDescending { it.timestamp }
    }

    fun markStubborn(word: VocabularyWord, sessionID: UUID, dateString: String = DictationSessionStateMachineDate.today()) {
        val existing = stubborn.firstOrNull { it.wordID == word.id && it.dateString == dateString }
        if (existing != null) {
            existing.errorCount += 1
        } else {
            stubborn.add(
                StubbornWordRecord(
                    wordID = word.id,
                    word = word.word,
                    sourceDeckID = word.deckID,
                    sourceDeckTitle = word.deckTitle,
                    dateString = dateString,
                    errorCount = 1,
                    triggeringSessionID = sessionID,
                )
            )
        }
        scheduleSave()
    }

    fun addWord(word: String, meaning: String, deckID: String = "android.reading.custom", deckTitle: String = "阅读生词本"): VocabularyWord {
        val id = "${deckID}_${UUID.randomUUID().toString().take(8)}"
        val vocab = VocabularyWord(
            id = id,
            word = word,
            definitionZH = meaning,
            deckID = deckID,
            deckTitle = deckTitle,
        )
        words.add(vocab)
        scheduleSave()
        return vocab
    }

    // MARK: - 读写

    fun scheduleSave() {
        saveJob?.cancel()
        saveJob = scope.launch {
            delay(400)
            saveNow()
        }
    }

    fun saveNow() {
        runCatching {
            raw.put("schemaVersion", 2)
            raw.put("importedWords", encodeWords(words))
            raw.put("reviewSchedule", encodeSchedule(schedule))
            raw.put("dictationLogs", encodeLogs(logs))
            raw.put("stubbornWords", encodeStubborn(stubborn))
            raw.put("slowReactionWords", encodeSlow(slowReaction))
            raw.put("dailyReadingSeconds", JSONObject(dailyReading as Map<*, *>))
            raw.put("workspace", JSONObject().put("selectedDeckID", selectedDeckID ?: ""))
            file.writeText(raw.toString(2))
        }.onFailure { Log.e(TAG, "保存失败", it) }
    }

    /** 导入 macOS / iPhone 的整份 store（`替换` 时不保留内置词表）。 */
    fun importStore(text: String, replace: Boolean = false): Boolean {
        val incoming = runCatching { JSONObject(text) }.getOrNull() ?: return false
        val incomingWords = decodeWords(incoming.optJSONArray("importedWords"))
        if (incomingWords.isEmpty()) return false
        val base = if (replace) emptyList() else words
        words = SyncMerge.mergeWords(base, incomingWords).toMutableList()
        schedule = SyncMerge.mergeSchedule(schedule, decodeSchedule(incoming.optJSONObject("reviewSchedule"))).toMutableMap()
        logs = SyncMerge.mergeLogs(logs, decodeLogs(incoming.optJSONArray("dictationLogs"))).toMutableList()
        stubborn = SyncMerge.mergeStubborn(stubborn, decodeStubborn(incoming.optJSONArray("stubbornWords"))).toMutableList()
        slowReaction = SyncMerge.mergeSlowReaction(slowReaction, decodeSlow(incoming.optJSONArray("slowReactionWords"))).toMutableList()
        dailyReading = SyncMerge.mergeDailyReading(dailyReading, decodeDailyReading(incoming.optJSONObject("dailyReadingSeconds"))).toMutableMap()
        selectedDeckID = decks.firstOrNull()?.id
        saveNow()
        return true
    }

    fun exportText(): String {
        saveNow()
        return file.readText()
    }

    // MARK: - 编解码（字段与 macOS 版一致）

    private fun decodeWords(array: JSONArray?): List<VocabularyWord> {
        if (array == null) return emptyList()
        val result = ArrayList<VocabularyWord>(array.length())
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val word = item.optString("word").trim()
            if (word.isEmpty()) continue
            result.add(
                VocabularyWord(
                    id = item.optString("id").ifBlank { "word_$i" },
                    word = word,
                    phoneticUK = item.optString("phoneticUK"),
                    phoneticUS = item.optString("phoneticUS"),
                    partOfSpeech = item.optString("partOfSpeech"),
                    definitionZH = item.optString("definitionZH"),
                    exampleSentence = item.optString("exampleSentence"),
                    deckID = item.optString("deckID").ifBlank { "unknown" },
                    deckTitle = item.optString("deckTitle"),
                    folderPath = item.optJSONArray("folderPath")?.let { path ->
                        (0 until path.length()).map { path.optString(it) }
                    },
                )
            )
        }
        return result
    }

    private fun encodeWords(words: List<VocabularyWord>): JSONArray {
        val array = JSONArray()
        for (word in words) {
            val item = JSONObject()
                .put("id", word.id)
                .put("word", word.word)
                .put("phoneticUK", word.phoneticUK)
                .put("phoneticUS", word.phoneticUS)
                .put("partOfSpeech", word.partOfSpeech)
                .put("definitionZH", word.definitionZH)
                .put("exampleSentence", word.exampleSentence)
                .put("deckID", word.deckID)
                .put("deckTitle", word.deckTitle)
            word.folderPath?.let { item.put("folderPath", JSONArray(it)) }
            array.put(item)
        }
        return array
    }

    private fun decodeSchedule(json: JSONObject?): Map<String, WordReviewProgress> {
        if (json == null) return emptyMap()
        val result = HashMap<String, WordReviewProgress>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val item = json.optJSONObject(key) ?: continue
            result[key] = WordReviewProgress(
                stage = item.optInt("stage", 0),
                dueAt = parseInstant(item.optString("dueAt")),
                lastReviewedAt = item.optString("lastReviewedAt").takeIf { it.isNotBlank() }?.let { parseInstant(it) },
                stability = item.optDouble("stability", 0.0),
                difficulty = item.optDouble("difficulty", 5.0),
                lapses = item.optInt("lapses", 0),
            )
        }
        return result
    }

    private fun encodeSchedule(schedule: Map<String, WordReviewProgress>): JSONObject {
        val json = JSONObject()
        for ((wordID, progress) in schedule) {
            val item = JSONObject()
                .put("stage", progress.stage)
                .put("dueAt", ISO.format(progress.dueAt))
                .put("stability", progress.stability)
                .put("difficulty", progress.difficulty)
                .put("lapses", progress.lapses)
            progress.lastReviewedAt?.let { item.put("lastReviewedAt", ISO.format(it)) }
            json.put(wordID, item)
        }
        return json
    }

    private fun decodeLogs(array: JSONArray?): List<DictationAttemptLog> {
        if (array == null) return emptyList()
        val result = ArrayList<DictationAttemptLog>(array.length())
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val id = item.optString("id").takeIf { it.isNotBlank() }?.let { runCatching { UUID.fromString(it) }.getOrNull() } ?: UUID.randomUUID()
            val sessionID = item.optString("sessionID").takeIf { it.isNotBlank() }?.let { runCatching { UUID.fromString(it) }.getOrNull() } ?: id
            result.add(
                DictationAttemptLog(
                    id = id,
                    sessionID = sessionID,
                    mode = DictationSessionMode.fromRaw(item.optString("mode", "new_task")),
                    wordID = item.optString("wordID"),
                    word = item.optString("word"),
                    deckID = item.optString("deckID"),
                    userTyped = item.optString("userTyped"),
                    isCorrect = item.optBoolean("isCorrect"),
                    isFirstAttemptInSession = item.optBoolean("isFirstAttemptInSession"),
                    sessionErrorCountForWord = item.optInt("sessionErrorCountForWord"),
                    timestamp = parseInstant(item.optString("timestamp")),
                    dateString = item.optString("dateString"),
                    durationSeconds = item.optDouble("durationSeconds", 0.0),
                )
            )
        }
        return result
    }

    private fun encodeLogs(logs: List<DictationAttemptLog>): JSONArray {
        val array = JSONArray()
        for (log in logs) {
            array.put(
                JSONObject()
                    .put("id", log.id.toString())
                    .put("sessionID", log.sessionID.toString())
                    .put("mode", log.mode.rawValue)
                    .put("wordID", log.wordID)
                    .put("word", log.word)
                    .put("deckID", log.deckID)
                    .put("userTyped", log.userTyped)
                    .put("isCorrect", log.isCorrect)
                    .put("isFirstAttemptInSession", log.isFirstAttemptInSession)
                    .put("sessionErrorCountForWord", log.sessionErrorCountForWord)
                    .put("timestamp", ISO.format(log.timestamp))
                    .put("dateString", log.dateString)
                    .put("durationSeconds", log.durationSeconds)
            )
        }
        return array
    }

    private fun decodeStubborn(array: JSONArray?): List<StubbornWordRecord> {
        if (array == null) return emptyList()
        val result = ArrayList<StubbornWordRecord>(array.length())
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            result.add(
                StubbornWordRecord(
                    wordID = item.optString("wordID"),
                    word = item.optString("word"),
                    sourceDeckID = item.optString("sourceDeckID"),
                    sourceDeckTitle = item.optString("sourceDeckTitle"),
                    dateString = item.optString("dateString"),
                    errorCount = item.optInt("errorCount", item.optInt("missCount", 0)),
                    triggeringSessionID = runCatching {
                        UUID.fromString(item.optString("triggeringSessionID"))
                    }.getOrElse { UUID.randomUUID() },
                )
            )
        }
        return result
    }

    private fun encodeStubborn(records: List<StubbornWordRecord>): JSONArray {
        val array = JSONArray()
        for (record in records) {
            array.put(
                JSONObject()
                    .put("wordID", record.wordID)
                    .put("word", record.word)
                    .put("sourceDeckID", record.sourceDeckID)
                    .put("sourceDeckTitle", record.sourceDeckTitle)
                    .put("dateString", record.dateString)
                    .put("errorCount", record.errorCount)
                    .put("triggeringSessionID", record.triggeringSessionID.toString())
            )
        }
        return array
    }

    private fun decodeSlow(array: JSONArray?): List<SlowReactionWordRecord> {
        if (array == null) return emptyList()
        val result = ArrayList<SlowReactionWordRecord>(array.length())
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            result.add(
                SlowReactionWordRecord(
                    wordID = item.optString("wordID"),
                    word = item.optString("word"),
                    definitionZH = item.optString("definitionZH"),
                    sourceDeckID = item.optString("sourceDeckID"),
                    sourceDeckTitle = item.optString("sourceDeckTitle"),
                    lastReactionSeconds = item.optDouble("lastReactionSeconds", 0.0),
                    maxReactionSeconds = item.optDouble("maxReactionSeconds", item.optDouble("lastReactionSeconds", 0.0)),
                    bestReactionSeconds = if (item.has("bestReactionSeconds")) item.optDouble("bestReactionSeconds") else null,
                    slowCount = item.optInt("slowCount", 1),
                    dateString = item.optString("dateString"),
                    updatedAt = parseInstant(item.optString("updatedAt")),
                )
            )
        }
        return result
    }

    private fun encodeSlow(records: List<SlowReactionWordRecord>): JSONArray {
        val array = JSONArray()
        for (record in records) {
            val item = JSONObject()
                .put("wordID", record.wordID)
                .put("word", record.word)
                .put("definitionZH", record.definitionZH)
                .put("sourceDeckID", record.sourceDeckID)
                .put("sourceDeckTitle", record.sourceDeckTitle)
                .put("lastReactionSeconds", record.lastReactionSeconds)
                .put("maxReactionSeconds", record.maxReactionSeconds)
                .put("slowCount", record.slowCount)
                .put("dateString", record.dateString)
                .put("updatedAt", ISO.format(record.updatedAt))
            record.bestReactionSeconds?.let { item.put("bestReactionSeconds", it) }
            array.put(item)
        }
        return array
    }

    private fun decodeDailyReading(json: JSONObject?): Map<String, Int> {
        if (json == null) return emptyMap()
        val result = HashMap<String, Int>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = json.optInt(key)
        }
        return result
    }

    private fun parseInstant(text: String): Instant =
        if (text.isBlank()) Instant.EPOCH else runCatching { Instant.parse(text) }.getOrElse { Instant.EPOCH }
}

/** 日期字符串（YYYY-MM-DD，本地时区），与 macOS 的 `dateString` 同格式。 */
object DictationSessionStateMachineDate {
    fun today(zone: ZoneId = ZoneId.systemDefault()): String = LocalDate.now(zone).toString()
}
