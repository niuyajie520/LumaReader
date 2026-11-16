import Foundation

// MARK: - 2. ExamEnglishInputPolicy (Pure Value Type, Testable on Any Platform)

/// Validation decision returned by `ExamEnglishInputPolicy`.
public enum ExamInputValidationDecision: Equatable, Sendable {
    /// Replacement is permitted verbatim (including misspelled English like "teh", "enviroment", "I dont know").
    case allowVerbatim
    /// Replacement is rejected in its entirety; original draft remains untouched.
    case rejectEntirely(reason: RejectionReason, userBannerMessage: String)

    public enum RejectionReason: String, Equatable, Sendable {
        case containsCJKCharacters
        case containsFullWidthPunctuation
        case containsNonASCIIOrDisallowedScript
        case containsEmojiOrSymbol
    }
}

/// Legacy draft compatibility check result when opening an older draft in strict exam mode.
public struct LegacyDraftCompatibilityReport: Equatable, Sendable {
    public let containsLegacyNonEnglishCharacters: Bool
    public let offendingCharacterSamples: [String]
    public let warningBannerMessage: String?
}

/// Independent, stateless, unit-testable policy enforcing IELTS computer-delivered English input rules.
public nonisolated struct ExamEnglishInputPolicy: Sendable {

    public init() {}

    /// Permitted ASCII punctuation in IELTS computer-based writing/reading answers:
    /// `. , ; : ? ! ' " - ( ) [ ] / % & $ # @ + = * _ ~`
    private static let allowedPunctuationScalars: Set<Unicode.Scalar> = Set(
        #".,;:?!'"-()[]/%&$#@+=*_~`<>\|{}"#.unicodeScalars
    )

    /// Evaluates a single candidate replacement string (from typing, IME commit, paste, drag-drop, dictation, or undo/redo).
    /// - Important: Never strips Chinese characters silently to concatenate English, and never alters misspelled English.
    public func validateReplacement(_ replacement: String) -> ExamInputValidationDecision {
        // Deletions (empty replacement string) are always allowed
        if replacement.isEmpty {
            return .allowVerbatim
        }

        for scalar in replacement.unicodeScalars {
            // 1. Check CJK Unified Ideographs, Radicals, Pinyin/Bopomofo, Hangul, Kana
            if Self.isCJKScalar(scalar) {
                return .rejectEntirely(
                    reason: .containsCJKCharacters,
                    userBannerMessage: "当前为雅思纯英文答题模式，仅接收英文与半角标点，中文输入未写入草稿。"
                )
            }

            // 2. Check CJK / Full-width punctuation (e.g. ， 。 ； ： ？ ！ “ ” ‘ ’ （ ） 【 】 — … 、)
            if Self.isFullWidthOrCJKPunctuation(scalar) {
                return .rejectEntirely(
                    reason: .containsFullWidthPunctuation,
                    userBannerMessage: #"请使用英文半角标点（如 , . ; : ? ! ' " -），全角标点未写入草稿。"#
                )
            }

            // 3. Check Emoji or pictographic scalars
            if Self.isEmojiScalar(scalar) {
                return .rejectEntirely(
                    reason: .containsEmojiOrSymbol,
                    userBannerMessage: "考试答题区不支持表情符号或特殊图标。"
                )
            }

            // 4. Strict whitelist check: A-Z, a-z, 0-9, space, tab, newline/CR, or allowed half-width punctuation
            if !Self.isAllowedEnglishExamScalar(scalar) {
                return .rejectEntirely(
                    reason: .containsNonASCIIOrDisallowedScript,
                    userBannerMessage: "当前为雅思纯英文答题模式，非英文字符未写入草稿。"
                )
            }
        }

        return .allowVerbatim
    }

    /// Evaluates a batch of replacement strings (corresponding to `NSTextViewDelegate.textView(_:shouldChangeTextInRanges:replacementStrings:)`).
    /// If ANY replacement in a multi-cursor edit violates the policy, the entire edit operation is rejected atomically.
    public func validateBatchReplacements(_ replacements: [String]) -> ExamInputValidationDecision {
        for item in replacements {
            let decision = validateReplacement(item)
            if case .rejectEntirely = decision {
                return decision
            }
        }
        return .allowVerbatim
    }

    /// Inspects an existing saved draft without deleting or mutating any characters (Section 五.A.7 Data Compatibility).
    public func inspectLegacyDraft(_ draftText: String) -> LegacyDraftCompatibilityReport {
        var samples: [String] = []
        for scalar in draftText.unicodeScalars {
            if !Self.isAllowedEnglishExamScalar(scalar) {
                let s = String(scalar)
                if !samples.contains(s) && samples.count < 8 {
                    samples.append(s)
                }
            }
        }
        if samples.isEmpty {
            return LegacyDraftCompatibilityReport(
                containsLegacyNonEnglishCharacters: false,
                offendingCharacterSamples: [],
                warningBannerMessage: nil
            )
        } else {
            let sampleList = samples.joined(separator: " ")
            return LegacyDraftCompatibilityReport(
                containsLegacyNonEnglishCharacters: true,
                offendingCharacterSamples: samples,
                warningBannerMessage: "历史草稿包含非英文字符（\(sampleList)）。系统已为您完整保留原文与备份副本，请在交卷前手动修改或清理。"
            )
        }
    }

    /// Official IELTS word counter: counts whitespace-delimited tokens containing at least one alphanumeric character.
    /// Hyphenated words (e.g., "well-equipped") and contractions (e.g., "don't", "dont") count as 1 word.
    public func countIELTSWords(in text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        var count = 0
        for token in components where !token.isEmpty {
            if token.unicodeScalars.contains(where: { Self.isASCIIAlphanumeric($0) }) {
                count += 1
            }
        }
        return count
    }

    // MARK: - Scalar Classification Helpers

    public static func isASCIIAlphanumeric(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x30 && v <= 0x39) // 0-9
            || (v >= 0x41 && v <= 0x5A) // A-Z
            || (v >= 0x61 && v <= 0x7A) // a-z
    }

    public static func isAllowedEnglishExamScalar(_ s: Unicode.Scalar) -> Bool {
        if isASCIIAlphanumeric(s) { return true }
        // Standard whitespace: space (0x20), tab (0x09), newline (0x0A), carriage return (0x0D)
        if s.value == 0x20 || s.value == 0x09 || s.value == 0x0A || s.value == 0x0D {
            return true
        }
        return allowedPunctuationScalars.contains(s)
    }

    public static func isCJKScalar(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x4E00 && v <= 0x9FFF)   // CJK Unified Ideographs
            || (v >= 0x3400 && v <= 0x4DBF)   // CJK Unified Ideographs Extension A
            || (v >= 0x20000 && v <= 0x2CEAF) // CJK Extensions B-F
            || (v >= 0xF900 && v <= 0xFAFF)   // CJK Compatibility Ideographs
            || (v >= 0x2E80 && v <= 0x2FDF)   // CJK Radicals / Kangxi
            || (v >= 0x3100 && v <= 0x312F)   // Bopomofo
            || (v >= 0x3040 && v <= 0x30FF)   // Hiragana / Katakana
            || (v >= 0xAC00 && v <= 0xD7AF)   // Hangul Syllables
    }

    public static func isFullWidthOrCJKPunctuation(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x3000 && v <= 0x303F)   // CJK Symbols and Punctuation (。 ， 、 【 】)
            || (v >= 0xFF01 && v <= 0xFF60)   // Fullwidth ASCII variants (！ ， ． ： ； ？ （ ）)
            || (v >= 0xFE10 && v <= 0xFE6F)   // CJK Compatibility Forms / Small Form Variants
            || v == 0x2014                    // Em dash —
            || v == 0x2026                    // Horizontal ellipsis …
            || v == 0x2018 || v == 0x2019     // Curly single quotes ‘ ’
            || v == 0x201C || v == 0x201D     // Curly double quotes “ ”
    }

    public static func isEmojiScalar(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (v >= 0x1F300 && v <= 0x1FAFF)
            || (v >= 0x2600 && v <= 0x27BF)
            || v == 0xFE0F
    }
}
