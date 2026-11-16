package app.luma.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * 直接读仓库根的 `spec/behaviour.json` 逐条断言——不在这边另写一份期望值。
 * 这样「规范改了、Kotlin 没跟上」会在 `./gradlew :core:test` 里立刻炸出来。
 */
class SpecFixtureTest {

    private val spec: Map<String, Any?> by lazy {
        val file = File(repoRoot(), "spec/behaviour.json")
        assertTrue(file.exists(), "找不到 ${file.absolutePath}")
        @Suppress("UNCHECKED_CAST")
        MiniJson.parse(file.readText()) as Map<String, Any?>
    }

    private fun repoRoot(): File {
        var dir = File(System.getProperty("user.dir")).absoluteFile
        while (dir.parentFile != null) {
            if (File(dir, "spec/behaviour.json").exists()) return dir
            dir = dir.parentFile
        }
        return File(System.getProperty("user.dir"))
    }

    @Suppress("UNCHECKED_CAST")
    private fun list(key: String): List<Map<String, Any?>> = spec[key] as List<Map<String, Any?>>

    @Test
    fun judgementMatchesSpec() {
        for (case in list("judgement")) {
            val input = case["input"] as String
            val target = case["target"] as String
            val expected = case["match"] as Boolean
            assertEquals(expected, DictationAnswerPolicy.matches(input, target), "case: $input / $target")
        }
    }

    @Test
    fun normalizationMatchesSpec() {
        for (case in list("normalization")) {
            val input = case["input"] as String
            val expected = case["normalized"] as String
            assertEquals(expected, DictationAnswerPolicy.normalized(input), "case: $input")
        }
    }

    @Test
    fun entryKindMatchesSpec() {
        for (case in list("entryKind")) {
            val input = case["input"] as String
            val expected = if (case["kind"] as String == "longPhrase") {
                DictationEntryKind.LONG_PHRASE
            } else {
                DictationEntryKind.WORD
            }
            assertEquals(expected, DictationEntryKind.classify(input), "case: $input")
        }
    }

    @Test
    fun minorSlipMatchesSpec() {
        for (case in list("minorSlip")) {
            val input = case["input"] as String
            val target = case["target"] as String
            val expected = case["fragment"] as String?
            assertEquals(expected, DictationPhraseDiff.minorSlip(input, target), "case: $input / $target")
        }
    }

    @Test
    fun reviewIntervalsMatchSpec() {
        @Suppress("UNCHECKED_CAST")
        val review = spec["reviewSchedule"] as Map<String, Any?>
        val intervals = (review["cleanRecallIntervals"] as List<Any>).map { (it as Number).toInt() }
        assertEquals(intervals, WordReviewProgress.baseIntervals)

        val zone = ZoneId.of("UTC")
        val start = LocalDate.of(2026, 11, 16).atTime(9, 0).atZone(zone).toInstant()
        var progress = WordReviewProgress()
        for ((index, days) in intervals.withIndex()) {
            progress = WordReviewProgress()
            progress.stage = index
            progress.record(cleanRecall = true, reactionSeconds = 3.0, now = start, zone = zone)
            assertEquals(index + 1, progress.stage)
            assertEquals(start.plus(days.toLong(), java.time.temporal.ChronoUnit.DAYS), progress.dueAt)
        }

        // 同一天再答对：档位不动。
        val sameDay = WordReviewProgress()
        sameDay.record(true, 3.0, start, zone)
        val stageAfterFirst = sameDay.stage
        sameDay.record(true, 3.0, start.plusSeconds(3600), zone)
        assertEquals(stageAfterFirst, sameDay.stage, "sameDaySecondCorrectKeepsStage")

        // 答错：归零、lapses+1、dueAt=now。
        val wrong = WordReviewProgress(stage = 3, lapses = 1)
        wrong.record(false, 3.0, start, zone)
        assertEquals(0, wrong.stage)
        assertEquals(2, wrong.lapses)
        assertEquals(start, wrong.dueAt)
    }

    @Test
    fun sessionConstantsMatchSpec() {
        @Suppress("UNCHECKED_CAST")
        val session = spec["session"] as Map<String, Any?>
        assertEquals(3, (session["moveToEndAfterErrors"] as Number).toInt())
        assertEquals(6, (session["promoteToStubbornAfterErrors"] as Number).toInt())
        assertEquals(listOf(5, 55, 155, 255), DictationTuning.newWordLadder)
        assertEquals(5, DictationTuning.RELEARN_STEP)
    }

    @Test
    fun quickStrategySkipsButRequeues() {
        val words = (1..20).map { word("w$it", "word$it") }
        val zone = ZoneId.of("UTC")
        val now = LocalDate.of(2026, 11, 16).atTime(9, 0).atZone(zone).toInstant()
        val machine = DictationSessionStateMachine(
            dateString = "2026-11-16",
            initialWords = words,
            nowProvider = { now },
        )

        val outcome = machine.submitAnswer("nope", 3.0, newWordStrategy = NewWordDictationStrategy.QUICK)
        assertEquals(DictationSubmitOutcome.SkippedIncorrect, outcome)
        assertEquals(20, machine.pendingQueue.size, "答错只是插回，队列长度不变")
        assertTrue(machine.currentWord?.id != "w1", "答错后当前词已经不是刚才那个")
        assertFalse("w1" in machine.completedWordIDs)

        // 稍后答对同一批词里的那个词，才算完成并退出错词队列。
        val index = machine.pendingQueue.indexOfFirst { it.id == "w1" }
        assertTrue(index > 0)
        machine.pendingQueue.removeAt(index)
        machine.pendingQueue.add(0, words[0])
        val second = machine.submitAnswer("word1", 3.0, newWordStrategy = NewWordDictationStrategy.QUICK)
        assertEquals(DictationSubmitOutcome.Correct(exitedWrongQueue = true), second)
        assertTrue("w1" in machine.completedWordIDs)
    }

    @Test
    fun firstAttemptFlagIsOnlyTrueOnce() {
        val machine = DictationSessionStateMachine(
            dateString = "2026-11-16",
            initialWords = listOf(word("w1", "however")),
            nowProvider = { Instant.parse("2026-11-16T09:00:00Z") },
        )
        machine.submitAnswer("howver", 3.0, newWordStrategy = NewWordDictationStrategy.REPEATING)
        machine.submitAnswer("however", 3.0, newWordStrategy = NewWordDictationStrategy.REPEATING)
        val flags = machine.attemptLogs.map { it.isFirstAttemptInSession }
        assertEquals(listOf(true, false), flags)
    }

    @Test
    fun repeatingStrategyUsesLadder() {
        val words = (1..30).map { word("w$it", "word$it") }
        val machine = DictationSessionStateMachine(
            dateString = "2026-11-16",
            initialWords = words,
            nowProvider = { Instant.parse("2026-11-16T09:00:00Z") },
        )
        val miss = machine.submitAnswer("wrong", 3.0, newWordStrategy = NewWordDictationStrategy.REPEATING)
        assertTrue(miss is DictationSubmitOutcome.NeedsCorrection, "循环复习答错要停在原地订正")
        val corrected = machine.submitAnswer("word1", 3.0, newWordStrategy = NewWordDictationStrategy.REPEATING)
        assertTrue(corrected is DictationSubmitOutcome.RequeuedForRetry)
        val offset = (corrected as DictationSubmitOutcome.RequeuedForRetry).insertedAtOffset
        assertEquals(5, offset, "订正后按 relearnStep=5 插回")
    }

    @Test
    fun syncMergeRulesHold() {
        val a = word("a", "apple", deck = "d1")
        val aDuplicate = word("a2", "Apple", deck = "d1")
        val b = word("b", "banana", deck = "d1")
        assertEquals(listOf(a, b), SyncMerge.mergeWords(listOf(a), listOf(aDuplicate, b)))

        val early = WordReviewProgress(stage = 2, dueAt = Instant.parse("2026-11-18T00:00:00Z"))
        val late = WordReviewProgress(stage = 2, dueAt = Instant.parse("2026-11-20T00:00:00Z"))
        val higher = WordReviewProgress(stage = 3, dueAt = Instant.parse("2026-11-17T00:00:00Z"))
        assertEquals(late, SyncMerge.mergeSchedule(mapOf("x" to early), mapOf("x" to late))["x"])
        assertEquals(higher, SyncMerge.mergeSchedule(mapOf("x" to late), mapOf("x" to higher))["x"])

        assertEquals(mapOf("2026-11-16" to 120), SyncMerge.mergeDailyReading(mapOf("2026-11-16" to 60), mapOf("2026-11-16" to 120)))
        assertEquals(listOf("a", "b", "c"), SyncMerge.mergeMarks(listOf("b", "a"), listOf("c", "a")))
    }

    private fun word(id: String, text: String, deck: String = "deck") =
        VocabularyWord(
            id = id,
            word = text,
            definitionZH = "释义",
            deckID = deck,
            deckTitle = "词本",
        )
}

/**
 * 只为读测试夹具用的极简 JSON 解析器（core 模块不引第三方依赖，避免给 app 增加体积）。
 * 支持对象、数组、字符串、数字、真假、null——够读 spec/behaviour.json。
 */
internal object MiniJson {

    fun parse(text: String): Any? {
        val parser = Parser(text)
        val value = parser.readValue()
        parser.skipWhitespace()
        return value
    }

    private class Parser(private val text: String) {
        private var index = 0

        fun skipWhitespace() {
            while (index < text.length && text[index].isWhitespace()) index++
        }

        fun readValue(): Any? {
            skipWhitespace()
            return when (val ch = text[index]) {
                '{' -> readObject()
                '[' -> readArray()
                '"' -> readString()
                't' -> { expect("true"); true }
                'f' -> { expect("false"); false }
                'n' -> { expect("null"); null }
                else -> if (ch == '-' || ch.isDigit()) readNumber() else error("意外的字符 $ch @ $index")
            }
        }

        private fun readObject(): Map<String, Any?> {
            val map = LinkedHashMap<String, Any?>()
            index++ // {
            skipWhitespace()
            if (text.getOrNull(index) == '}') { index++; return map }
            while (true) {
                skipWhitespace()
                val key = readString()
                skipWhitespace()
                require(text[index] == ':')
                index++
                map[key] = readValue()
                skipWhitespace()
                when (text.getOrNull(index)) {
                    ',' -> index++
                    '}' -> { index++; return map }
                    else -> error("对象里缺少逗号 @ $index")
                }
            }
        }

        private fun readArray(): List<Any?> {
            val list = ArrayList<Any?>()
            index++ // [
            skipWhitespace()
            if (text.getOrNull(index) == ']') { index++; return list }
            while (true) {
                list.add(readValue())
                skipWhitespace()
                when (text.getOrNull(index)) {
                    ',' -> index++
                    ']' -> { index++; return list }
                    else -> error("数组里缺少逗号 @ $index")
                }
            }
        }

        private fun readString(): String {
            require(text[index] == '"')
            index++
            val sb = StringBuilder()
            while (text[index] != '"') {
                if (text[index] == '\\') {
                    index++
                    when (val esc = text[index]) {
                        '"' -> sb.append('"')
                        '\\' -> sb.append('\\')
                        '/' -> sb.append('/')
                        'b' -> sb.append('\b')
                        'f' -> sb.append('\u000C')
                        'n' -> sb.append('\n')
                        'r' -> sb.append('\r')
                        't' -> sb.append('\t')
                        'u' -> {
                            val hex = text.substring(index + 1, index + 5)
                            sb.append(hex.toInt(16).toChar())
                            index += 4
                        }
                        else -> error("未知转义 \\$esc")
                    }
                    index++
                } else {
                    sb.append(text[index])
                    index++
                }
            }
            index++
            return sb.toString()
        }

        private fun readNumber(): Any {
            val start = index
            if (text[index] == '-') index++
            while (index < text.length && (text[index].isDigit() || text[index] == '.' || text[index] == 'e' || text[index] == 'E' || text[index] == '+' || text[index] == '-')) index++
            val raw = text.substring(start, index)
            return if (raw.contains('.')) raw.toDouble() else raw.toLong()
        }

        private fun expect(word: String) {
            require(text.startsWith(word, index))
            index += word.length
        }
    }
}
