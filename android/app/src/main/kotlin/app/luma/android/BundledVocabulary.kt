package app.luma.android

import android.content.Context
import app.luma.core.VocabularyWord
import org.json.JSONArray

/**
 * 首次启动时播种的内置阅读词表（6063 条，来自 `assets/ReadingVocabulary.json`）。
 * 与 iOS 版用同一份文件，标题与 deckID 各自独立。
 */
fun readBundledReadingWords(context: Context): List<VocabularyWord> {
    val text = context.assets.open("ReadingVocabulary.json").bufferedReader().use { it.readText() }
    val array = JSONArray(text)
    val result = ArrayList<VocabularyWord>(array.length())
    for (index in 0 until array.length()) {
        val item = array.optJSONObject(index) ?: continue
        val word = item.optString("word").trim()
        if (word.isEmpty()) continue
        val stableID = item.optString("id").ifBlank {
            val number = if (item.has("number")) item.opt("number").toString() else index.toString()
            number
        }
        result.add(
            VocabularyWord(
                id = "android_reading_$stableID",
                word = word,
                phoneticUS = item.optString("ipa"),
                definitionZH = item.optString("meaning"),
                deckID = StudyStore.STARTER_DECK_ID,
                deckTitle = StudyStore.STARTER_DECK_TITLE,
            )
        )
    }
    return result
}
