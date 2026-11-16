package app.luma.core

/** 词条。字段与 `Packages/LumaCore/Sources/LumaCore/VocabularyWord.swift` 一致，JSON 可直接互导。 */
data class VocabularyWord(
    val id: String,
    val word: String,
    val phoneticUK: String = "",
    val phoneticUS: String = "",
    val partOfSpeech: String = "",
    val definitionZH: String,
    val exampleSentence: String = "",
    val deckID: String,
    val deckTitle: String,
    val folderPath: List<String>? = null,
) {
    val wordCount: Int get() = word.split(Regex("\\s+")).count { it.isNotBlank() }

    val isPhrase: Boolean get() = wordCount > 1

    /** 手机上卡片放不下长释义，取第一段（分号/句号切）。 */
    val shortDefinition: String
        get() = if (definitionZH.isBlank()) "" else definitionZH.split("；", ";", "。").first().trim()

    val phonetic: String get() = phoneticUS.ifBlank { phoneticUK }
}

/** 词本：同一个 deckID 的连续词条。 */
data class VocabularyDeck(
    val id: String,
    val title: String,
    val words: List<VocabularyWord>,
) {
    val count: Int get() = words.size
}
