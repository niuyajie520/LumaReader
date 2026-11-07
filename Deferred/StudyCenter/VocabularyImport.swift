import Foundation
import CoreFoundation
import CryptoKit

public enum VocabularyRecognitionStatus: String, Codable, Equatable, Sendable {
    case paired = "已配对"
    case needsConfirmation = "待确认"
}

public struct RecognizedVocabularyCandidate: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var word: String
    public var meaning: String
    public var status: VocabularyRecognitionStatus
    public var statusReason: String?
    public var sourceLineDescription: String

    public init(
        id: UUID = UUID(),
        word: String,
        meaning: String,
        status: VocabularyRecognitionStatus = .paired,
        statusReason: String? = nil,
        sourceLineDescription: String = ""
    ) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.status = status
        self.statusReason = statusReason
        self.sourceLineDescription = sourceLineDescription
    }
}

public struct VocabularySmartAnalysisReport: Equatable, Sendable {
    public var candidates: [RecognizedVocabularyCandidate]
    public var recognizedEnglishCount: Int
    public var pairedMeaningCount: Int
    public var needsConfirmationCount: Int
    public var ignoredNonVocabularyLines: [String]
}

public nonisolated enum VocabularyImport {
    struct Item: Decodable {
        let word: String
        let meaning: String
    }

    // MARK: - 1. Multi-Encoding Smart Text Decoder (UTF-8, UTF-8 BOM, UTF-16, GB18030/GBK)

    public static func decodeText(from data: Data) throws -> String {
        guard data.count <= 2 * 1024 * 1024 else {
            throw CocoaError(.fileReadTooLarge)
        }
        guard !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Check BOMs first
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let stripped = data.dropFirst(3)
            if let str = String(data: stripped, encoding: .utf8) {
                return sanitizeDecoded(str)
            }
        }
        if data.starts(with: [0xFF, 0xFE]) {
            if let str = String(data: data, encoding: .utf16LittleEndian), !str.unicodeScalars.contains(where: { $0.value == 0 }) {
                return sanitizeDecoded(str)
            }
        }
        if data.starts(with: [0xFE, 0xFF]) {
            if let str = String(data: data, encoding: .utf16BigEndian), !str.unicodeScalars.contains(where: { $0.value == 0 }) {
                return sanitizeDecoded(str)
            }
        }

        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Reject obvious binary data containing interior null bytes (when not UTF-16)
        if let str = String(data: data, encoding: .utf8) {
            if str.unicodeScalars.contains(where: { $0.value == 0 }) {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            return sanitizeDecoded(str)
        }

        // Try GB18030 / GBK (common Chinese TXT encoding on Windows/macOS)
        let gbEncoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        if let nsStr = NSString(data: data, encoding: gbEncoding) as String? {
            if !nsStr.unicodeScalars.contains(where: { $0.value == 0 }) {
                return sanitizeDecoded(nsStr)
            }
        }

        // Try UTF-16 fallback if even-length and contains null bytes characteristic of UTF-16
        if data.count % 2 == 0, let str = String(data: data, encoding: .utf16) {
            return sanitizeDecoded(str)
        }

        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    private static func sanitizeDecoded(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{FEFF}", with: "")
           .replacingOccurrences(of: "\r\n", with: "\n")
           .replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: - 2. Intelligent Bilingual Line & Multi-Line Analyzer

    private static let posTokens: Set<String> = [
        "n.", "v.", "vt.", "vi.", "adj.", "adv.", "prep.", "conj.", "pron.", "num.", "art.", "int.", "phr.", "idiom."
    ]

    public static func analyzeSmartText(_ text: String, filename: String = "import.txt") -> VocabularySmartAnalysisReport {
        let rawLines = text.components(separatedBy: .newlines)
        var cleanedLines: [(lineNumber: Int, text: String)] = []
        var ignoredLines: [String] = []

        for (idx, rawLine) in rawLines.enumerated() {
            let trimmed = normalizeWhitespace(rawLine)
            if trimmed.isEmpty || isPureSeparatorLine(trimmed) {
                continue
            }
            if isHeaderOrSectionTitle(trimmed, isFirstNonEmpty: cleanedLines.isEmpty && ignoredLines.isEmpty) {
                ignoredLines.append(trimmed)
                continue
            }
            if isExampleSentenceOrPromptOrTranscript(trimmed) {
                ignoredLines.append(trimmed)
                continue
            }
            cleanedLines.append((idx + 1, trimmed))
        }

        var candidates: [RecognizedVocabularyCandidate] = []
        var i = 0
        while i < cleanedLines.count {
            let current = cleanedLines[i]
            let line = current.text

            // 1. Try single-line pairing (supports Tab, |, ----, :, space, forward & reverse)
            switch analyzeSingleLine(line, lineNumber: current.lineNumber) {
            case .paired(let word, let meaning):
                candidates.append(
                    RecognizedVocabularyCandidate(
                        word: word,
                        meaning: meaning,
                        status: .paired,
                        statusReason: nil,
                        sourceLineDescription: "第 \(current.lineNumber) 行"
                    )
                )
                i += 1
                continue

            case .ambiguous(let word, let meaning, let reason):
                candidates.append(
                    RecognizedVocabularyCandidate(
                        word: word,
                        meaning: meaning,
                        status: .needsConfirmation,
                        statusReason: reason,
                        sourceLineDescription: "第 \(current.lineNumber) 行"
                    )
                )
                i += 1
                continue

            case .englishOnly(let eng):
                // Check if next line is Chinese-only for adjacent 2-line pairing!
                if i + 1 < cleanedLines.count {
                    let next = cleanedLines[i + 1]
                    if case .chineseOnly(let zh) = analyzeSingleLine(next.text, lineNumber: next.lineNumber) {
                        candidates.append(
                            RecognizedVocabularyCandidate(
                                word: eng,
                                meaning: zh,
                                status: .paired,
                                statusReason: nil,
                                sourceLineDescription: "第 \(current.lineNumber)–\(next.lineNumber) 行"
                            )
                        )
                        i += 2
                        continue
                    }
                }
                // Never fabricate translations: mark as 待确认!
                candidates.append(
                    RecognizedVocabularyCandidate(
                        word: eng,
                        meaning: "",
                        status: .needsConfirmation,
                        statusReason: "待确认：未识别到对应中文释义（严禁自动捏造翻译）",
                        sourceLineDescription: "第 \(current.lineNumber) 行"
                    )
                )
                i += 1
                continue

            case .chineseOnly(let zh):
                // Check if next line is English-only for reverse adjacent 2-line pairing!
                if i + 1 < cleanedLines.count {
                    let next = cleanedLines[i + 1]
                    if case .englishOnly(let eng) = analyzeSingleLine(next.text, lineNumber: next.lineNumber) {
                        candidates.append(
                            RecognizedVocabularyCandidate(
                                word: eng,
                                meaning: zh,
                                status: .paired,
                                statusReason: nil,
                                sourceLineDescription: "第 \(current.lineNumber)–\(next.lineNumber) 行"
                            )
                        )
                        i += 2
                        continue
                    }
                }
                candidates.append(
                    RecognizedVocabularyCandidate(
                        word: "",
                        meaning: zh,
                        status: .needsConfirmation,
                        statusReason: "待确认：仅识别到中文释义，缺少对应英文词条",
                        sourceLineDescription: "第 \(current.lineNumber) 行"
                    )
                )
                i += 1
                continue

            case .ignored:
                ignoredLines.append(line)
                i += 1
            }
        }

        let engCount = candidates.filter { isValidEnglishTerm($0.word) }.count
        let pairedCount = candidates.filter { $0.status == .paired && isValidEnglishTerm($0.word) && !$0.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let confirmCount = candidates.filter { $0.status == .needsConfirmation }.count

        return VocabularySmartAnalysisReport(
            candidates: candidates,
            recognizedEnglishCount: engCount,
            pairedMeaningCount: pairedCount,
            needsConfirmationCount: confirmCount,
            ignoredNonVocabularyLines: ignoredLines
        )
    }

    private enum SingleLineClassification {
        case paired(word: String, meaning: String)
        case ambiguous(word: String, meaning: String, reason: String)
        case englishOnly(String)
        case chineseOnly(String)
        case ignored
    }

    private static func analyzeSingleLine(_ line: String, lineNumber: Int) -> SingleLineClassification {
        // 1. Check explicit structural delimiters first: Tab, Pipe `|`, Multi-dash `----` / `--`, Em-dash `—`, Arrow `->` / `=>`, Colon `:` / `：`
        if let (left, right, extraCount) = splitByExplicitDelimiter(line) {
            if extraCount > 0 {
                // E.g. 3+ segments on one line -> check if it's TSV with extra notes or ambiguous
                if let pair = orientBilingualPair(left, right) {
                    return .paired(word: pair.word, meaning: pair.meaning)
                }
                return .ambiguous(word: left, meaning: right, reason: "待确认：同行包含多个分隔字段，请确认对应关系")
            }
            if let pair = orientBilingualPair(left, right) {
                return .paired(word: pair.word, meaning: pair.meaning)
            }
            // If both sides are English or both sides are Chinese:
            if isValidEnglishTerm(left) && isValidEnglishTerm(right) && !containsCJK(left) && !containsCJK(right) {
                return .ambiguous(word: left, meaning: right, reason: "待确认：两侧均为英文，请确认哪一侧为中文释义")
            }
            if containsCJK(left) && containsCJK(right) && !containsLatinLetter(left) && !containsLatinLetter(right) {
                return .ambiguous(word: left, meaning: right, reason: "待确认：未识别到英文词条，请修正或取消勾选")
            }
        }

        let hasLatin = containsLatinLetter(line)
        let hasCJK = containsCJK(line)

        // 2. Both English and Chinese on the same line without explicit delimiter (e.g. `apple 苹果`, `苹果 apple`, `take responsibility for 承担责任`)
        if hasLatin && hasCJK {
            return splitInlineBilingualByScriptBoundary(line)
        }

        // 3. Only English on this line
        if hasLatin && !hasCJK {
            let cleaned = cleanEnglishTerm(line)
            if isValidEnglishTerm(cleaned) {
                return .englishOnly(cleaned)
            }
            return .ignored
        }

        // 4. Only Chinese on this line
        if hasCJK && !hasLatin {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty && cleaned.count <= 80 {
                return .chineseOnly(cleaned)
            }
            return .ignored
        }

        return .ignored
    }

    /// Splits a line by explicit delimiters (`\t`, `|`, `----`, `--`, `—`, `–`, `->`, `=>`, `:`, `：`)
    /// while strictly preserving single hyphens inside English words (`well-known`, `up-to-date`).
    private static func splitByExplicitDelimiter(_ line: String) -> (String, String, Int)? {
        if line.contains("\t") {
            let parts = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if parts.count >= 2 {
                return (parts[0], parts[1...].joined(separator: "；"), parts.count - 2)
            }
        }
        if line.contains("|") {
            let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if parts.count >= 2 {
                return (parts[0], parts[1...].joined(separator: "；"), parts.count - 2)
            }
        }
        // Check multi-dash (`--` or more), em-dash `—`, arrows `->`, `=>`, `::`
        let multiDelimiters = ["----", "---", "--", "—", "->", "=>", "::", " - ", " – "]
        for delim in multiDelimiters {
            if let range = line.range(of: delim) {
                let left = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let right = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !left.isEmpty && !right.isEmpty {
                    return (left, right, 0)
                }
            }
        }
        // Check colon `:` or `：` (avoid splitting time like 10:30)
        for colon in ["：", ":"] {
            if let range = line.range(of: colon) {
                let left = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let right = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !left.isEmpty && !right.isEmpty {
                    return (left, right, 0)
                }
            }
        }
        return nil
    }

    private static func orientBilingualPair(_ a: String, _ b: String) -> (word: String, meaning: String)? {
        let aHasCJK = containsCJK(a)
        let bHasCJK = containsCJK(b)
        let aHasLatin = containsLatinLetter(a)
        let bHasLatin = containsLatinLetter(b)

        // Forward: A is English, B is Chinese (or B has POS + Chinese like `n. 苹果`)
        if aHasLatin && !aHasCJK && bHasCJK {
            let eng = cleanEnglishTerm(a)
            let zh = b.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidEnglishTerm(eng) && !zh.isEmpty {
                return (eng, zh)
            }
        }
        // Reverse: A is Chinese, B is English (`苹果 | apple`, `苹果: apple`, `苹果\tapple`)
        if aHasCJK && !bHasCJK && bHasLatin {
            let eng = cleanEnglishTerm(b)
            let zh = a.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidEnglishTerm(eng) && !zh.isEmpty {
                return (eng, zh)
            }
        }
        return nil
    }

    /// Handles lines with both English and Chinese separated only by spaces or script transitions:
    /// e.g. `apple 苹果`, `苹果 apple`, `take responsibility for 承担责任`, `环境保护 environmental protection`, `apple n. 苹果`.
    private static func splitInlineBilingualByScriptBoundary(_ line: String) -> SingleLineClassification {
        let scalars = Array(line.unicodeScalars)
        guard let firstCJKIdx = scalars.firstIndex(where: { isCJKScalar($0) }),
              let lastCJKIdx = scalars.lastIndex(where: { isCJKScalar($0) }),
              let firstLatinIdx = scalars.firstIndex(where: { isASCIIAlpha($0) }),
              let lastLatinIdx = scalars.lastIndex(where: { isASCIIAlpha($0) }) else {
            return .ignored
        }

        // Case A: English comes strictly before Chinese (`apple 苹果`, `apple n. 苹果`, `take responsibility for 承担责任`)
        if lastLatinIdx < firstCJKIdx {
            let engSlice = String(String.UnicodeScalarView(scalars[..<firstCJKIdx]))
            let zhSlice = String(String.UnicodeScalarView(scalars[firstCJKIdx...]))
            let (cleanedEng, extractedPOS) = stripTrailingPOSFromEnglish(engSlice)
            let finalMeaning = (extractedPOS.isEmpty ? "" : extractedPOS + " ") + zhSlice.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidEnglishTerm(cleanedEng) && !finalMeaning.isEmpty {
                return .paired(word: cleanedEng, meaning: finalMeaning)
            }
        }

        // Case B: Chinese comes strictly before English (`苹果 apple`, `环境保护 environmental protection`)
        if lastCJKIdx < firstLatinIdx {
            // Check if there is a POS prefix right before the Chinese or English
            let beforeLatin = String(String.UnicodeScalarView(scalars[..<firstLatinIdx])).trimmingCharacters(in: .whitespacesAndNewlines)
            let fromLatin = String(String.UnicodeScalarView(scalars[firstLatinIdx...])).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedEng = cleanEnglishTerm(fromLatin)
            if isValidEnglishTerm(cleanedEng) && !beforeLatin.isEmpty {
                return .paired(word: cleanedEng, meaning: beforeLatin)
            }
        }

        // Case C: Interleaved scripts on a single line (e.g., `apple 苹果 banana 香蕉` or mixed sentence)
        let extractedEng = cleanEnglishTerm(String(String.UnicodeScalarView(scalars.filter { !isCJKScalar($0) })))
        let extractedZH = String(String.UnicodeScalarView(scalars.filter { isCJKScalar($0) || $0 == "，" || $0 == "；" }))
        return .ambiguous(
            word: extractedEng,
            meaning: extractedZH,
            reason: "待确认：同行中英文交替出现或存在多组词条，请手动核对"
        )
    }

    private static func stripTrailingPOSFromEnglish(_ rawEng: String) -> (String, String) {
        let trimmed = cleanEnglishTerm(rawEng)
        let parts = trimmed.split(separator: " ").map(String.init)
        if parts.count >= 2, let last = parts.last?.lowercased() {
            let normalizedLast = last.hasSuffix(".") ? last : last + "."
            if posTokens.contains(normalizedLast) {
                let wordPart = parts.dropLast().joined(separator: " ")
                return (cleanEnglishTerm(wordPart), last)
            }
        }
        return (trimmed, "")
    }

    // MARK: - 3. Filtering Helpers (Ignore Titles, Full Sentences, Prompts, Separators)

    private static func normalizeWhitespace(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ")
         .replacingOccurrences(of: "\u{3000}", with: " ")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isPureSeparatorLine(_ line: String) -> Bool {
        let separatorChars = CharacterSet(charactersIn: #"-=_*~#•·. /|\"#).union(CharacterSet(charactersIn: "\t"))
        return line.unicodeScalars.allSatisfy { separatorChars.contains($0) }
    }

    private static func isHeaderOrSectionTitle(_ line: String, isFirstNonEmpty: Bool) -> Bool {
        let lower = line.lowercased()
        let exactHeaders: Set<String> = [
            "word\tmeaning", "word | meaning", "word meaning", "word: meaning",
            "vocabulary", "vocabulary list", "word list", "words",
            "单词\t释义", "单词 释义", "英文\t中文", "英文 中文", "词汇表", "单词表", "核心词汇", "高频词汇"
        ]
        if exactHeaders.contains(lower) { return true }
        if isFirstNonEmpty {
            let columns = lower.components(separatedBy: CharacterSet(charactersIn: "\t|: "))
                .filter { !$0.isEmpty }
            if columns.count == 2 && ["word", "english", "term", "单词", "英文"].contains(columns[0]) &&
               ["meaning", "definition", "chinese", "中文", "释义", "翻译"].contains(columns[1]) {
                return true
            }
        }
        // Unit / Chapter / List / Day / Section titles
        let headingPatterns = [
            #"^(unit|chapter|section|part|list|day|lesson|group|module|passage)\s*\d+([:\s\-—].*)?$"#,
            #"^第[一二三四五六七八九十百0-9]+[单元章节课天部分组篇]([：\s\-—].*)?$"#,
            #"^#+\s+.*$"#
        ]
        for pattern in headingPatterns {
            if lower.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    private static func isExampleSentenceOrPromptOrTranscript(_ line: String) -> Bool {
        let lower = line.lowercased()
        // Dialogue / Transcript / Question markers
        let transcriptPrefixes = [
            "speaker ", "man:", "woman:", "interviewer:", "candidate:", "narrator:",
            "example:", "e.g.", "ex:", "例:", "例句:", "例句：", "question:", "q:", "answer:",
            "summarise the information", "write at least", "you should spend about",
            "listen to the conversation", "section 1", "section 2", "section 3", "section 4"
        ]
        for prefix in transcriptPrefixes where lower.hasPrefix(prefix) {
            return true
        }

        // If the line has no explicit delimiter and its English part is a full sentence (7+ words or ends with sentence punctuation and >=4 words)
        if splitByExplicitDelimiter(line) == nil {
            let englishWords = line.split { $0.isWhitespace }.filter { token in
                token.unicodeScalars.allSatisfy { isASCIIAlpha($0) || $0 == "-" || $0 == "'" || $0 == "’" || $0 == "." || $0 == "," || $0 == "?" || $0 == "!" }
            }
            if englishWords.count >= 7 {
                return true
            }
            if englishWords.count >= 4 && (line.hasSuffix(".") || line.hasSuffix("?") || line.hasSuffix("!")) {
                return true
            }
        }
        return false
    }

    private static func cleanEnglishTerm(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip leading numbering like `1. `, `1) `, `(1) `, `• `
        if let range = s.range(of: #"^(\(\d+\)|\d+[\.\)\、]|[-•*])\s+"#, options: .regularExpression) {
            s = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        // Strip trailing dashes/colons/pipes left over from informal separators
        let trailingSeparators = CharacterSet(charactersIn: "-—–:|：\t ")
        while let last = s.unicodeScalars.last, trailingSeparators.contains(last) {
            s.unicodeScalars.removeLast()
        }
        while let first = s.unicodeScalars.first, trailingSeparators.contains(first) {
            s.unicodeScalars.removeFirst()
        }
        // Collapse multiple internal spaces to a single space while preserving hyphens and apostrophes
        let tokens = s.split(whereSeparator: { $0.isWhitespace })
        return tokens.joined(separator: " ")
    }

    public static func isValidEnglishTerm(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { return false }
        guard containsLatinLetter(trimmed), !containsCJK(trimmed) else { return false }
        let words = trimmed.split(separator: " ")
        guard words.count <= 6 else { return false }
        if words.count >= 4 && (trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")) {
            return false
        }
        for scalar in trimmed.unicodeScalars {
            let v = scalar.value
            let isAllowed = (v >= 65 && v <= 90) ||
                            (v >= 97 && v <= 122) ||
                            (v >= 48 && v <= 57) ||
                            scalar == " " || scalar == "-" || scalar == "'" || scalar == "’" || scalar == "/" || scalar == "." || scalar == "(" || scalar == ")"
            if !isAllowed { return false }
        }
        return !DictationAnswerPolicy.normalized(trimmed).isEmpty
    }

    public static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { isCJKScalar($0) }
    }

    public static func containsLatinLetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { isASCIIAlpha($0) }
    }

    private static func isASCIIAlpha(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122)
    }

    private static func isCJKScalar(_ scalar: UnicodeScalar) -> Bool {
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) ||
               (v >= 0x3400 && v <= 0x4DBF) ||
               (v >= 0xF900 && v <= 0xFAFF)
    }

    // MARK: - 4. Direct Batch Parser & Deck Builder

    public static func parse(_ data: Data, filename: String) throws -> [VocabularyWord] {
        guard data.count <= 2 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let entries: [Item]
        if filename.lowercased().hasSuffix(".json") {
            entries = try JSONDecoder().decode([Item].self, from: data)
        } else if filename.lowercased().hasSuffix(".tsv") {
            // Preserve strict TSV column order contract when importing explicit .tsv files in automated batch mode
            let text = try decodeText(from: data)
            entries = try text.components(separatedBy: .newlines).enumerated().compactMap { index, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
                let columns = line.components(separatedBy: "\t")
                if index == 0 && columns.first?.lowercased() == "word" { return nil }
                guard columns.count >= 2 else { throw CocoaError(.fileReadCorruptFile) }
                return Item(word: columns[0], meaning: columns[1...].joined(separator: "\t"))
            }
        } else {
            let text = try decodeText(from: data)
            let report = analyzeSmartText(text, filename: filename)
            guard !report.candidates.isEmpty,
                  report.needsConfirmationCount == 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            entries = report.candidates.map { Item(word: $0.word, meaning: $0.meaning) }
        }
        return try build(entries, filename: filename)
    }

    static func parseJSONEntries(_ data: Data, filename: String) throws -> [VocabularyWord] {
        try build(JSONDecoder().decode([Item].self, from: data), filename: filename)
    }

    private static func build(_ entries: [Item], filename: String) throws -> [VocabularyWord] {
        guard !entries.isEmpty, entries.count <= 20000 else { throw CocoaError(.fileReadCorruptFile) }
        let deck = deckIdentifier(for: filename)
        var seen = Set<String>()
        return try entries.compactMap { entry in
            let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, !meaning.isEmpty, word.count <= 200,
                  word.unicodeScalars.allSatisfy({ ($0.value >= 32 && $0.value <= 126) || $0 == "’" }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let id = deck + "." + hex(Data(word.lowercased().utf8))
            guard seen.insert(id).inserted else { return nil }
            return VocabularyWord(
                id: id,
                word: word,
                phoneticUK: "",
                phoneticUS: "",
                partOfSpeech: "",
                definitionZH: meaning,
                exampleSentence: "",
                deckID: deck,
                deckTitle: (filename as NSString).deletingPathExtension
            )
        }
    }

    static func deckIdentifier(for filename: String) -> String {
        "import." + hex(Data(filename.utf8))
    }

    private static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}
