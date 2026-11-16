package app.luma.core

/**
 * 判题规则。与 `Packages/LumaCore/Sources/LumaCore/DictationRules.swift` 一一对应，
 * 任何一边改了，另一端必须跟着改；`spec/behaviour.json` 是两边的验收清单。
 */
object DictationAnswerPolicy {

    /**
     * 归一化：全角转半角、去掉零宽字符、统一引号与破折号、裁掉首尾标点、
     * 压掉多余空白（连字符两侧的空格也压掉）。
     *
     * 返回值有三种语义，移植时不要省：
     *  * 空字符串 = 用户什么都没打；
     *  * `"\u0000"` = 打了，但含英文拼写之外的字符（中文、emoji 等），一律判错；
     *  * 其它 = 可用于比较的文本。
     */
    fun normalized(raw: String): String {
        val halfWidth = StringBuilder(raw.length)
        for (ch in raw) {
            halfWidth.append(
                when {
                    ch == '\u00A0' || ch == '\u3000' -> ' '
                    ch == '\u200B' || ch == '\u200C' || ch == '\u200D' || ch == '\u2060' || ch == '\uFEFF' -> continue
                    ch.code in 0xFF01..0xFF5E -> (ch.code - 0xFEE0).toChar()
                    else -> ch
                }
            )
        }
        val folded = halfWidth.toString()
            .replace('\u2019', '\'')
            .replace('\u2018', '\'')
            .replace('\u201C', '"')
            .replace('\u201D', '"')
            .replace('\u2014', '-')
            .replace('\u2013', '-')
            .trim()
            .lowercase()

        val edge = ".,;:?!\"()[]{}"
        var start = 0
        var end = folded.length
        while (start < end && folded[start] in edge) start++
        while (end > start && folded[end - 1] in edge) end--
        val trimmed = folded.substring(start, end)

        val text = trimmed
            .replace(Regex("\\s*-\\s*"), "-")
            .replace(Regex("\\s+"), " ")
            .trim()

        if (text.isEmpty() || text.none { ExamEnglishInputPolicy.isAsciiAlphanumeric(it) }) return ""
        val allowed = text.all {
            ExamEnglishInputPolicy.isAsciiAlphanumeric(it) || it == ' ' || it == '-' || it == '_' || it == '\''
        }
        return if (allowed) text else "\u0000"
    }

    /**
     * 短语与固定搭配的宽松比较：空格、连字符、下划线可以互换，但字母必须对上；
     * 目标是单个词时不允许输入中间有空格（不能把一个词拆成两个）。
     */
    fun matches(rawInput: String, targetWord: String): Boolean {
        val input = normalized(rawInput)
        val target = normalized(targetWord)
        if (input.isEmpty() || target.isEmpty() || input == "\u0000" || target == "\u0000") return false

        if (target.contains(' ')) {
            val a = input.filterNot { it == ' ' || it == '-' || it == '_' }
            val b = target.filterNot { it == ' ' || it == '-' || it == '_' }
            return a.isNotEmpty() && a == b
        }
        if (input.contains(' ')) return false
        val a = input.filterNot { it == '-' || it == '_' }
        val b = target.filterNot { it == '-' || it == '_' }
        return a.isNotEmpty() && a == b
    }
}

/** 听写条目按「单词标准」还是「长措辞轻量门槛」处理。4 个词以内一律按单词走。 */
enum class DictationEntryKind(val rawValue: String) {
    WORD("word"),
    LONG_PHRASE("longPhrase");

    companion object {
        const val LONG_PHRASE_MINIMUM_WORDS = 5

        fun classify(text: String): DictationEntryKind {
            val words = text.split(Regex("\\s+")).filter { it.isNotBlank() }
            return if (words.size >= LONG_PHRASE_MINIMUM_WORDS) LONG_PHRASE else WORD
        }

        fun fromRaw(raw: String): DictationEntryKind =
            entries.firstOrNull { it.rawValue == raw } ?: WORD
    }
}

/** 长措辞的差异分析：只差虚词时给出目标侧的差异片段，实词错返回 null。 */
object DictationPhraseDiff {

    val functionWords: Set<String> = setOf(
        "a", "an", "the",
        "in", "on", "at", "of", "to", "for", "with", "by", "from", "into", "onto", "upon",
        "about", "over", "under", "between", "among", "through", "across", "against", "around",
        "behind", "below", "beneath", "beside", "besides", "beyond", "during", "without", "within",
        "toward", "towards", "via", "per", "than", "as", "since", "until", "till", "despite",
        "except", "inside", "outside", "off", "down", "up", "along", "past", "like",
        "and", "or", "but", "so", "yet", "nor", "if", "because", "although", "though", "while",
        "whereas", "unless", "whether", "that", "when", "where", "before", "after",
        "be", "am", "is", "are", "was", "were", "been", "being",
        "do", "does", "did", "have", "has", "had", "will", "would", "shall", "should",
        "can", "could", "may", "might", "must",
        "this", "these", "those", "some", "any", "each", "every", "no", "not",
        "my", "your", "his", "her", "its", "our", "their", "there", "here",
    )

    /** 返回差在目标里的那一段（例如 `"on the"`）；不是「只差虚词」时返回 null。 */
    fun minorSlip(input: String, target: String): String? {
        val typed = tokens(input)
        val expected = tokens(target)
        if (typed.isEmpty() || expected.isEmpty() || typed.size != expected.size) return null

        var differs = false
        val missed = mutableListOf<String>()
        for (index in typed.indices) {
            if (typed[index] == expected[index]) continue
            if (typed[index] !in functionWords || expected[index] !in functionWords) return null
            differs = true
            if (expected[index] !in missed) missed.add(expected[index])
        }
        return if (differs) missed.joinToString(" ") else null
    }

    fun tokens(text: String): List<String> {
        val normalized = DictationAnswerPolicy.normalized(text)
        if (normalized.isEmpty() || normalized == "\u0000") return emptyList()
        return normalized.split(' ').filter { it.isNotEmpty() }
    }
}

/**
 * 雅思类练习的纯英文输入校验：中文字符、全角标点、emoji 一律拒绝。
 * 与 iOS 的 `ExamEnglishInputPolicy` 保持同一套判定。
 */
object ExamEnglishInputPolicy {

    fun isAsciiAlphanumeric(ch: Char): Boolean =
        (ch in 'a'..'z') || (ch in 'A'..'Z') || (ch in '0'..'9')

    fun isAsciiAlphanumeric(code: Int): Boolean =
        (code in 0x30..0x39) || (code in 0x41..0x5A) || (code in 0x61..0x7A)

    /** 屏幕上出现中文/全角/emoji 时返回第一个越界字符，全部合法时返回 null。 */
    fun firstDisallowedCharacter(text: String, allowSpaces: Boolean = true): Char? {
        for (ch in text) {
            if (isAsciiAlphanumeric(ch)) continue
            if (ch == '\'' || ch == '-') continue
            if (allowSpaces && ch == ' ') continue
            return ch
        }
        return null
    }

    fun isAllowed(text: String, allowSpaces: Boolean = true): Boolean =
        firstDisallowedCharacter(text, allowSpaces) == null
}
