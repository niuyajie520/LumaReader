import Foundation
import SwiftUI

/// 融合艾宾浩斯遗忘曲线 (Ebbinghaus Forgetting Curve) 与 GitHub 开源 FSRS (Free Spaced Repetition Scheduler) DSR 记忆模型：
/// - D (Difficulty): 记忆难度 [1.0, 10.0]，根据拼写正误与反应时长 (>5.0s 慢反应 / <=2.0s 秒答) 自动动态更新
/// - S (Stability): 记忆稳定性（天），即记忆保持率从 100% 衰减至 90% 所需的天数
/// - R (Retrievability): 实时艾宾浩斯记忆保持率 R(t, S) = (1 + 19/81 * t / S)^(-0.5)
public struct WordReviewProgress: Codable, Equatable, Sendable {
    public static let ebbinghausBaseIntervals: [Int] = [1, 3, 5, 7, 10, 14]
    public var stage: Int
    public var dueAt: Date
    public var lastReviewedAt: Date?
    public var stability: Double
    public var difficulty: Double
    public var lapses: Int

    public init(
        stage: Int = 0,
        dueAt: Date = .distantPast,
        lastReviewedAt: Date? = nil,
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        lapses: Int = 0
    ) {
        self.stage = stage
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.stability = stability
        self.difficulty = difficulty
        self.lapses = lapses
    }

    private enum CodingKeys: String, CodingKey {
        case stage, dueAt, lastReviewedAt, stability, difficulty, lapses
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage = try c.decodeIfPresent(Int.self, forKey: .stage) ?? 0
        dueAt = try c.decodeIfPresent(Date.self, forKey: .dueAt) ?? .distantPast
        lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        stability = try c.decodeIfPresent(Double.self, forKey: .stability) ?? 0.0
        difficulty = try c.decodeIfPresent(Double.self, forKey: .difficulty) ?? 5.0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
    }

    /// 实时计算当前时刻的艾宾浩斯记忆保持率 R(t) ∈ [0.0, 1.0]
    public func ebbinghausRetrievability(at now: Date = Date()) -> Double {
        guard let last = lastReviewedAt else {
            return stage > 0 ? 0.90 : 0.0
        }
        let elapsedDays = max(0.0, now.timeIntervalSince(last) / 86400.0)
        let effS = max(0.5, stability > 0 ? stability : Double(Self.ebbinghausBaseIntervals[min(max(0, stage - 1), Self.ebbinghausBaseIntervals.count - 1)]))
        return pow(1.0 + (19.0 / 81.0) * (elapsedDays / effS), -0.5)
    }

    public mutating func record(
        cleanRecall: Bool,
        reactionSeconds: Double? = nil,
        at now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let intervals = Self.ebbinghausBaseIntervals
        let r = ebbinghausRetrievability(at: now)
        lastReviewedAt = now

        if cleanRecall {
            let days = intervals[min(stage, intervals.count - 1)]
            stage = min(stage + 1, intervals.count)
            // FSRS difficulty & stability update modulated by reaction latency
            let isSlow = (reactionSeconds ?? 2.5) > 5.0
            let isFast = (reactionSeconds ?? 2.5) <= 1.8
            let gradeDelta: Double = isSlow ? 0.45 : (isFast ? -0.35 : -0.10)
            difficulty = min(10.0, max(1.0, difficulty + gradeDelta))
            let prevS = max(1.0, stability > 0 ? stability : Double(days))
            let growth = 1.0 + exp(0.75) * (11.0 - difficulty) * pow(prevS, -0.18) * (exp((1.0 - r) * 0.25) - 1.0 + (isFast ? 0.65 : (isSlow ? 0.22 : 0.45)))
            stability = max(Double(days), min(14.0, prevS * max(1.15, growth)))
            dueAt = calendar.date(byAdding: .day, value: days, to: now) ?? now
        } else {
            stage = 0
            lapses += 1
            difficulty = min(10.0, max(1.0, difficulty + 0.85))
            stability = max(0.5, (stability > 0 ? stability : 1.0) * 0.35)
            dueAt = now
        }
    }
}

public struct WritingRevision: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public let submissionID: UUID
    public var part1: String
    public var part2: String
    public var suggestedPart1: String?
    public var suggestedPart2: String?
    public var updatedAt: Date
    public init(id: UUID = UUID(), submissionID: UUID, part1: String = "", part2: String = "", suggestedPart1: String? = nil, suggestedPart2: String? = nil, updatedAt: Date = Date()) {
        self.id = id; self.submissionID = submissionID; self.part1 = part1; self.part2 = part2; self.suggestedPart1 = suggestedPart1; self.suggestedPart2 = suggestedPart2; self.updatedAt = updatedAt
    }
    public init(original: WritingSubmissionRecord) {
        self.init(
            submissionID: original.id,
            part1: original.part1EssayText,
            part2: original.part2EssayText,
            suggestedPart1: original.aiEvaluation.map { WritingSuggestedDraft.applying($0.sentenceCorrections, to: original.part1EssayText) },
            suggestedPart2: original.aiEvaluation.map { WritingSuggestedDraft.applying($0.sentenceCorrections, to: original.part2EssayText) }
        )
    }
}

public enum WritingSuggestedDraft {
    public static func applying(_ corrections: [IELTSFourCriteriaEstimate.SentenceCorrectionItem], to original: String) -> String {
        var result = original
        for item in corrections {
            let quote = item.originalSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = item.correctedSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty, !replacement.isEmpty, let first = result.range(of: quote) else { continue }
            let after = result.index(after: first.lowerBound)
            if after < result.endIndex, result[after...].range(of: quote) != nil { continue }
            result.replaceSubrange(first, with: replacement)
        }
        return result
    }
}

public struct WritingReviewSession: Identifiable {
    public var id: UUID { revision.id }
    public let original: WritingSubmissionRecord
    public var revision: WritingRevision
    public init(original: WritingSubmissionRecord, revision: WritingRevision) {
        self.original = original; self.revision = revision
    }
}

public struct WritingReviewPanel: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studyAppearance) private var appearance
    public let original: WritingSubmissionRecord
    @State public var revision: WritingRevision
    @State private var error: String?
    @State private var vocabImportBanner: String?
    @State private var showInlineDiff = true
    public let onSave: (WritingRevision) -> String?
    public let onImportWordsToListening: (([VocabularyWord]) -> Void)?

    public init(
        session: WritingReviewSession,
        onSave: @escaping (WritingRevision) -> String?,
        onImportWordsToListening: (([VocabularyWord]) -> Void)? = nil
    ) {
        original = session.original
        _revision = State(initialValue: session.revision)
        self.onSave = onSave
        self.onImportWordsToListening = onImportWordsToListening
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("作文修改对照与重写（官方标准红绿差异高亮）")
                        .font(.title2.bold())
                        .foregroundStyle(appearance.ink)
                    Text("红色删除线为原句有误或待升级表达，绿色加粗下划线为雅思高分修正建议；支持一键将高分搭配或错词导入听力生词本")
                        .font(.caption)
                        .foregroundStyle(appearance.ink.opacity(0.68))
                }
                Spacer()
                if let onImportWordsToListening, let evaluation = original.aiEvaluation, !evaluation.sentenceCorrections.isEmpty {
                    Button("📥 一键将本篇好词搭配导入听力生词本") {
                        let words = Self.extractVocabularyWords(from: evaluation.sentenceCorrections, examTitle: original.examTitle)
                        onImportWordsToListening(words)
                        vocabImportBanner = "已导入 \(words.count) 个高分搭配/修正词条到「写作错词与高分搭配本」，可在听力模块直接听写！"
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appearance.accent)
                }
                Toggle("显示红绿行内修改对比", isOn: $showInlineDiff)
                    .toggleStyle(.switch)
                Button("重新生成 AI 建议稿") {
                    let rebuilt = WritingRevision(original: original)
                    revision.suggestedPart1 = rebuilt.suggestedPart1
                    revision.suggestedPart2 = rebuilt.suggestedPart2
                }
            }

            if let vocabImportBanner {
                Text(vocabImportBanner)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.accent)
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showInlineDiff {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Part 1 原文 vs 当前重写稿（红绿行内差异）")
                                .font(.headline)
                            WritingInlineDiffView(originalText: original.part1EssayText, revisedText: revision.part1)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))

                            Text("Part 2 原文 vs 当前重写稿（红绿行内差异）")
                                .font(.headline)
                            WritingInlineDiffView(originalText: original.part2EssayText, revisedText: revision.part2)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                    }

                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("原交卷（只读备份）").font(.headline)
                            Text("Part 1").font(.caption.bold())
                            Text(original.part1EssayText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                            Text("Part 2").font(.caption.bold())
                            Text(original.part2EssayText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI 建议稿（独立副本）").font(.headline)
                            Text("Part 1").font(.caption.bold())
                            Text(revision.suggestedPart1 ?? original.part1EssayText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                            Text("Part 2").font(.caption.bold())
                            Text(revision.suggestedPart2 ?? original.part2EssayText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("我的重写稿（可编辑）").font(.headline)
                            Text("Part 1").font(.caption.bold())
                            TextEditor(text: $revision.part1).frame(minHeight: 150)
                            Text("Part 2").font(.caption.bold())
                            TextEditor(text: $revision.part2).frame(minHeight: 200)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                    }

                    if let evaluation = original.aiEvaluation, !evaluation.sentenceCorrections.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("逐句红绿批改与高分升级建议").font(.headline)
                            ForEach(Array(evaluation.sentenceCorrections.enumerated()), id: \.offset) { _, item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.kind ?? "句子批改")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(appearance.selected))
                                            .foregroundStyle(appearance.accent)
                                        Spacer()
                                        if let onImportWordsToListening {
                                            Button("+ 加入听力生词本") {
                                                let extracted = Self.extractVocabularyWords(from: [item], examTitle: original.examTitle)
                                                onImportWordsToListening(extracted)
                                                vocabImportBanner = "已将「\(extracted.first?.word ?? item.upgradedExpression)」加入听力生词本！"
                                            }
                                            .font(.caption)
                                        }
                                        Button("将此修改应用到 Part 1") {
                                            revision.part1 = WritingSuggestedDraft.applying([item], to: revision.part1)
                                        }
                                        .font(.caption)
                                        Button("将此修改应用到 Part 2") {
                                            revision.part2 = WritingSuggestedDraft.applying([item], to: revision.part2)
                                        }
                                        .font(.caption)
                                    }
                                    WritingInlineDiffView(
                                        originalText: item.originalSentence,
                                        revisedText: item.correctedSentence,
                                        fontSize: 13.5
                                    )
                                    Text("批改解析：\(item.explanationZH)")
                                        .font(.caption)
                                        .foregroundStyle(appearance.ink.opacity(0.82))
                                    if !item.upgradedExpression.isEmpty && item.upgradedExpression != item.correctedSentence {
                                        Text("Band 7.5+ 高分升级：\(item.upgradedExpression)")
                                            .lumaFont(size: 12.5, weight: .medium, design: .serif)
                                            .foregroundStyle(appearance.accent)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                            }
                        }
                    }
                }
            }

            HStack {
                Button("关闭") { dismiss() }
                Spacer()
                Button("另存为新重写版本") {
                    revision.id = UUID()
                    revision.updatedAt = Date()
                    if let message = onSave(revision) { error = message } else { dismiss() }
                }
                Button("保存当前重写稿") {
                    revision.updatedAt = Date()
                    if let message = onSave(revision) { error = message } else { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .tint(appearance.accent)
            }
        }
        .padding(24)
        .frame(minWidth: 980, minHeight: 640)
        .background(appearance.paper)
    }

    public static func extractVocabularyWords(
        from corrections: [IELTSFourCriteriaEstimate.SentenceCorrectionItem],
        examTitle: String
    ) -> [VocabularyWord] {
        var result: [VocabularyWord] = []
        for item in corrections {
            let candidateRaw = item.upgradedExpression.isEmpty ? item.correctedSentence : item.upgradedExpression
            // Extract concise phrase or word (up to 5 words) or clean target
            let cleaned = candidateRaw
                .replacingOccurrences(of: #"^.*->\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: " .,;:?!\"'()[]"))
            let tokens = cleaned.split(whereSeparator: \.isWhitespace)
            let phrase = tokens.count <= 6 ? cleaned : tokens.prefix(5).joined(separator: " ")
            guard !phrase.isEmpty else { continue }
            let dictMeaning = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: phrase)
            let zh = dictMeaning ?? (item.explanationZH.isEmpty ? "写作高分搭配与纠错积累（\(examTitle)）" : item.explanationZH)
            let wordID = "writing_accum_\(abs(phrase.lowercased().hashValue) % 1_000_000)"
            result.append(
                VocabularyWord(
                    id: wordID,
                    word: phrase,
                    definitionZH: zh,
                    exampleSentence: item.correctedSentence,
                    deckID: "vocab_writing_accumulations",
                    deckTitle: "写作错词与高分搭配本"
                )
            )
        }
        return result
    }
}

// MARK: - 易错字母分析（从完整源码包合并，最新归档包缺少此定义会导致编译失败）
public enum WordErrorLetterAnalyzer {
    /// Finds the 0-based character indices in `targetWord` that were frequently omitted or substituted across `attempts`.
    public static func errorProneIndices(targetWord: String, typedAttempts: [String]) -> Set<Int> {
        let targetChars = Array(targetWord.lowercased())
        guard !targetChars.isEmpty else { return [] }
        var missCount = Array(repeating: 0, count: targetChars.count)

        let wrongAttempts = typedAttempts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && $0 != targetWord.lowercased() }

        if wrongAttempts.isEmpty {
            // Highlight double consonants or classic tricky vowel pairs if no attempt string is available
            var tricky = Set<Int>()
            for i in 1..<targetChars.count where targetChars[i] == targetChars[i - 1] {
                tricky.insert(i - 1)
                tricky.insert(i)
            }
            return tricky
        }

        for typed in wrongAttempts {
            let typedChars = Array(typed)
            let matchedTargetPositions = lcsMatchedTargetIndices(target: targetChars, typed: typedChars)
            for idx in 0..<targetChars.count where !matchedTargetPositions.contains(idx) {
                missCount[idx] += 1
            }
        }

        var highlighted = Set<Int>()
        for (idx, count) in missCount.enumerated() where count > 0 {
            highlighted.insert(idx)
        }
        return highlighted
    }

    private static func lcsMatchedTargetIndices(target: [Character], typed: [Character]) -> Set<Int> {
        let n = target.count
        let m = typed.count
        guard n > 0 && m > 0 else { return [] }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if target[i] == typed[j] {
                    dp[i][j] = 1 + dp[i + 1][j + 1]
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        var matched = Set<Int>()
        var i = 0, j = 0
        while i < n && j < m {
            if target[i] == typed[j] {
                matched.insert(i)
                i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return matched
    }

    public static func highlightedAttributedWord(
        _ word: String,
        typedAttempts: [String],
        baseFont: Font = .system(size: 18, weight: .bold, design: .serif),
        normalColor: Color = .primary,
        errorColor: Color = .red
    ) -> AttributedString {
        let badIndices = errorProneIndices(targetWord: word, typedAttempts: typedAttempts)
        var result = AttributedString()
        for (idx, ch) in word.enumerated() {
            var charStr = AttributedString(String(ch))
            charStr.font = baseFont
            if badIndices.contains(idx) {
                charStr.foregroundColor = errorColor
                charStr.underlineStyle = .single
                charStr.backgroundColor = errorColor.opacity(0.14)
            } else {
                charStr.foregroundColor = normalColor
            }
            result.append(charStr)
        }
        return result
    }

    public static func diagnoseSpellingPattern(targetWord: String, typedAttempts: [String]) -> String? {
        let lower = targetWord.lowercased()
        let chars = Array(lower)
        for i in 1..<chars.count where chars[i] == chars[i - 1] {
            return "易错点：注意双写字母「\(chars[i])\(chars[i])」"
        }
        if lower.contains("ie") || lower.contains("ei") {
            return "易错点：注意元音组合 ie / ei 顺序"
        }
        let bad = errorProneIndices(targetWord: targetWord, typedAttempts: typedAttempts)
        if !bad.isEmpty {
            let letters = bad.sorted().compactMap { $0 < chars.count ? String(chars[$0]) : nil }.joined(separator: " / ")
            return "高频漏拼/错拼字母位：\(letters)"
        }
        return nil
    }
}
