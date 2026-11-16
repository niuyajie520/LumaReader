import Foundation

public enum DictationAnswerPolicy {
    public static func normalized(_ raw: String) -> String {
        // IMEs and copy/paste can insert full-width or zero-width characters that are
        // invisible in the field but would make an otherwise correct answer fail.
        let halfWidth = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
        // ZWJ/ZWNJ form grapheme clusters, so remove them at scalar level instead of
        // using replacingOccurrences, which would not match inside a cluster.
        let cleanedScalars = halfWidth.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            switch scalar.value {
            case 0x00A0, 0x3000: return " "
            case 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF: return nil
            default: return scalar
            }
        }
        let folded = String(String.UnicodeScalarView(cleanedScalars))
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let edgePunctuation = CharacterSet(charactersIn: ".,;:?!\"()[]{}")
        let stripped = folded.unicodeScalars.drop { edgePunctuation.contains($0) }.reversed().drop { edgePunctuation.contains($0) }.reversed()
        let text = String(String.UnicodeScalarView(stripped))
            .replacingOccurrences(of: "\\s*-\\s*", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !text.isEmpty, text.unicodeScalars.contains(where: ExamEnglishInputPolicy.isASCIIAlphanumeric) else { return "" }
        guard text.unicodeScalars.allSatisfy({ ExamEnglishInputPolicy.isASCIIAlphanumeric($0) || $0 == " " || $0 == "-" || $0 == "_" || $0 == "'" }) else { return "\u{0}" }
        return text
    }

    /// Lenient comparison for phrases and fixed collocations:
    /// spaces, hyphens and underscores are treated as interchangeable separators,
    /// but the letters themselves must still match. A single target word may not
    /// contain an internal space (no splitting one word into two).
    public static func matches(_ rawInput: String, targetWord: String) -> Bool {
        let input = normalized(rawInput)
        let target = normalized(targetWord)
        guard !input.isEmpty, !target.isEmpty, input != "\u{0}", target != "\u{0}" else { return false }
        let separators: Set<Character> = [" ", "-", "_"]
        if target.contains(" ") {
            let a = String(input.filter { !separators.contains($0) })
            let b = String(target.filter { !separators.contains($0) })
            return !a.isEmpty && a == b
        }
        // Single word: reject internal spaces, but still tolerate hyphen/underscore differences.
        guard !input.contains(" ") else { return false }
        let a = String(input.filter { $0 != "-" && $0 != "_" })
        let b = String(target.filter { $0 != "-" && $0 != "_" })
        return !a.isEmpty && a == b
    }
}

/// 听写条目按「单词标准」还是「长措辞轻量门槛」处理。
/// 4 个词以内（单个词、两三个词的固定搭配）一律按单词的逻辑和阶梯走；
/// 5 个词以上才算长措辞，只加一道轻量门槛。
public enum DictationEntryKind: String, Codable, Sendable {
    case word
    case longPhrase

    public static let longPhraseMinimumWords = 5

    public static func classify(_ text: String) -> DictationEntryKind {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        return words.count >= longPhraseMinimumWords ? .longPhrase : .word
    }
}

/// 长措辞的差异分析：只差冠词 / 介词 / 连词 / 助动词等虚词时给出差异片段，
/// 只标错重试一次；实词或搭配错则返回 nil，按正常错词路径处理。
public enum DictationPhraseDiff {
    public static let functionWords: Set<String> = [
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
    ]

    /// 返回差在目标里的那一段（例如 "on the"）；不是「只差虚词」时返回 nil。
    public static func minorSlip(input: String, target: String) -> String? {
        let typed = tokens(input)
        let expected = tokens(target)
        guard !typed.isEmpty, !expected.isEmpty, typed.count == expected.count else { return nil }
        var differs = false
        var missed: [String] = []
        for (a, b) in zip(typed, expected) where a != b {
            guard functionWords.contains(a), functionWords.contains(b) else { return nil }
            differs = true
            if !missed.contains(b) { missed.append(b) }
        }
        return differs ? missed.joined(separator: " ") : nil
    }

    static func tokens(_ text: String) -> [String] {
        let normalized = DictationAnswerPolicy.normalized(text)
        guard !normalized.isEmpty, normalized != "\u{0}" else { return [] }
        return normalized.split(separator: " ").map(String.init)
    }
}
