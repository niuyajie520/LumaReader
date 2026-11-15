import Foundation
import SwiftUI
import AppKit

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

enum NewWordDictationStrategy: String {
    case quick, repeating
}

public enum DictationSubmitOutcome: Equatable, Sendable {
    case correct(exitedWrongQueue: Bool)
    case needsCorrection(errorCountForWordToday: Int)
    case skippedIncorrect
    case requeuedForRetry(errorCountForWordToday: Int, insertedAtOffset: Int)
    case promotedToStubbornWords(errorCountForWordToday: Int)
}

public struct DictationSessionStateMachine: Codable, Equatable, Sendable {
    /// 四次正确召回后毕业；最大间隔随队列长度调整，不为凑足 200 词而强制拖长练习。
    public static let expandingRetryOffsets: [Int] = [10, 50, 100, 200]

    /// 学习和错词复习共用间隔策略。候选词不足时在实际可穿插的词内复现，
    /// 避免单词本很小时重复漫长的固定四轮。显式 retryOffset 仅供兼容旧调用/测试。
    public static func adaptiveRetryOffset(cycle: Int, availableWords: Int) -> Int {
        let available = max(0, availableWords)
        guard available > 0 else { return 0 }
        let stage = max(0, min(cycle - 1, expandingRetryOffsets.count - 1))
        let economical = [10, 20, 35, 50][stage]
        return min(available, economical)
    }

    public let sessionID: UUID
    public let mode: DictationSessionMode
    public let dateString: String
    public private(set) var pendingQueue: [VocabularyWord]
    public private(set) var completedWordIDs: Set<String> = []
    public private(set) var sessionErrorCounts: [String: Int] = [:]
    public private(set) var activeWrongRetrySet: Set<String> = []
    /// 记录每个错词当前处于第几轮艾宾浩斯循环（1...4）
    public private(set) var wrongRetryCycleByWordID: [String: Int] = [:]
    public private(set) var correctionPendingIDs: Set<String> = []
    public private(set) var stubbornWordsMap: [String: StubbornWordRecord] = [:]
    public private(set) var slowReactionWordIDs: Set<String> = []
    public private(set) var attemptLogs: [DictationAttemptLog] = []
    /// 这一轮听写是从哪个单元开的（单元 id / 文件夹路径 / 多词本合练标记）。
    /// 用来防止「选了 A 单元却续上 B 单元的旧会话」，把别的单元的单词混进新词学习。
    public private(set) var originDeck: String? = nil
    /// sessionID 既是精确轮次标识；重新开始生成新轮，继续练习解码仍是同一轮。
    public var roundID: UUID { sessionID }
    private var wordsWithInitialAttemptLogged: Set<String> = []

    public init(
        sessionID: UUID = UUID(),
        mode: DictationSessionMode = .newTask,
        dateString: String,
        initialWords: [VocabularyWord],
        existingStubbornWordsForToday: [StubbornWordRecord] = [],
        previousLogs: [DictationAttemptLog] = [],
        originDeck: String? = nil
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.dateString = dateString
        self.originDeck = originDeck
        var seen = Set<String>()
        self.pendingQueue = initialWords.filter { seen.insert($0.id).inserted }
        // 新轮不能继承旧轮错误次数；仅「顽固词复习」按当前选中词条导入既有记录。
        // 其他单元的历史顽固词不能混进本轮报告或错词队列。
        if mode == .stubbornWordReview {
            for item in existingStubbornWordsForToday where item.dateString == dateString && seen.contains(item.wordID) {
                stubbornWordsMap[item.wordID] = item
                sessionErrorCounts[item.wordID] = max(sessionErrorCounts[item.wordID, default: 0], item.errorCount)
            }
        }
        // 旧日志用于全局错词本，不属于这个新轮次；续练通过解码原状态保留进度。
        _ = previousLogs
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID, mode, dateString, pendingQueue, completedWordIDs, sessionErrorCounts
        case activeWrongRetrySet, wrongRetryCycleByWordID, correctionPendingIDs, stubbornWordsMap, slowReactionWordIDs
        case attemptLogs, wordsWithInitialAttemptLogged, originDeck
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try c.decode(UUID.self, forKey: .sessionID)
        mode = try c.decode(DictationSessionMode.self, forKey: .mode)
        dateString = try c.decode(String.self, forKey: .dateString)
        pendingQueue = try c.decode([VocabularyWord].self, forKey: .pendingQueue)
        completedWordIDs = try c.decodeIfPresent(Set<String>.self, forKey: .completedWordIDs) ?? []
        sessionErrorCounts = try c.decodeIfPresent([String: Int].self, forKey: .sessionErrorCounts) ?? [:]
        activeWrongRetrySet = try c.decodeIfPresent(Set<String>.self, forKey: .activeWrongRetrySet) ?? []
        wrongRetryCycleByWordID = try c.decodeIfPresent([String: Int].self, forKey: .wrongRetryCycleByWordID) ?? [:]
        correctionPendingIDs = try c.decodeIfPresent(Set<String>.self, forKey: .correctionPendingIDs) ?? []
        stubbornWordsMap = try c.decodeIfPresent([String: StubbornWordRecord].self, forKey: .stubbornWordsMap) ?? [:]
        slowReactionWordIDs = try c.decodeIfPresent(Set<String>.self, forKey: .slowReactionWordIDs) ?? []
        attemptLogs = try c.decodeIfPresent([DictationAttemptLog].self, forKey: .attemptLogs) ?? []
        wordsWithInitialAttemptLogged = try c.decodeIfPresent(Set<String>.self, forKey: .wordsWithInitialAttemptLogged) ?? []
        originDeck = try c.decodeIfPresent(String.self, forKey: .originDeck)
    }

    /// 这一轮里的词到底属于哪些单元（用队列里剩下的词 + 已完成的词推断）。
    public var wordDeckIDs: Set<String> {
        Set(pendingQueue.map(\.deckID)).union(attemptLogs.map(\.deckID))
    }

    /// 即使本轮尚未提交第一题，也能用待学词集合严格约束窗口显示范围。
    public var roundWordIDs: Set<String> {
        Set(pendingQueue.map(\.id)).union(completedWordIDs).union(attemptLogs.map(\.wordID))
    }

    public mutating func revisitCompletedWord(_ word: VocabularyWord) {
        guard !requiresCorrection, completedWordIDs.contains(word.id) else { return }
        completedWordIDs.remove(word.id)
        pendingQueue.removeAll { $0.id == word.id }
        pendingQueue.insert(word, at: 0)
    }

    /// 逻辑分队列：新词保留初始顺序，错词只在本轮本词本队列内滚动；两队列共用调度器。
    public var pendingLearningWords: [VocabularyWord] {
        pendingQueue.filter { !activeWrongRetrySet.contains($0.id) }
    }
    public var pendingWrongRetryWords: [VocabularyWord] {
        pendingQueue.filter { activeWrongRetrySet.contains($0.id) }
    }

    public var currentWord: VocabularyWord? { pendingQueue.first }
    public var isSessionFinished: Bool { pendingQueue.isEmpty }
    public var requiresCorrection: Bool { currentWord.map { correctionPendingIDs.contains($0.id) } ?? false }

    /// 当前单词所处的错词循环轮次（若为错词重排词条，返回 1...4；否则返回 nil）
    public var currentWordRetryCycle: Int? {
        guard let word = currentWord, activeWrongRetrySet.contains(word.id) else { return nil }
        return max(1, min(Self.expandingRetryOffsets.count, wrongRetryCycleByWordID[word.id, default: 1]))
    }

    public var sortedStubbornWords: [StubbornWordRecord] {
        stubbornWordsMap.values.sorted {
            $0.errorCount != $1.errorCount ? $0.errorCount > $1.errorCount : $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
        }
    }

    @discardableResult
    public mutating func submitAnswer(
        _ rawInput: String,
        durationSeconds: Double = 2.5,
        retryOffset: Int? = nil
    ) -> DictationSubmitOutcome? {
        submitAnswer(rawInput, durationSeconds: durationSeconds, retryOffset: retryOffset, newWordStrategy: nil)
    }

    @discardableResult
    mutating func submitAnswer(
        _ rawInput: String, durationSeconds: Double = 2.5, retryOffset: Int? = nil,
        newWordStrategy: NewWordDictationStrategy?
    ) -> DictationSubmitOutcome? {
        let strategy = mode == .newTask ? newWordStrategy : nil
        let offsets = Self.expandingRetryOffsets
        guard let targetWord = pendingQueue.first else { return nil }
        let isMatch = DictationAnswerPolicy.matches(rawInput, targetWord: targetWord.word)
        let isFirstAttempt = !wordsWithInitialAttemptLogged.contains(targetWord.id)
        wordsWithInitialAttemptLogged.insert(targetWord.id)

        if isMatch {
            if durationSeconds > SlowReactionWordRecord.slowThresholdSeconds {
                slowReactionWordIDs.insert(targetWord.id)
            }
            pendingQueue.removeFirst()
            let currentErrors = sessionErrorCounts[targetWord.id, default: 0]
            // 1. 当场订正后短距重现；若此前已在循环中则保留原轮次。
            if correctionPendingIDs.remove(targetWord.id) != nil {
                attemptLogs.append(DictationAttemptLog(id: UUID(), sessionID: sessionID, mode: mode, wordID: targetWord.id, word: targetWord.word, deckID: targetWord.deckID, userTyped: rawInput, isCorrect: true, isFirstAttemptInSession: false, sessionErrorCountForWord: currentErrors, timestamp: Date(), dateString: dateString, durationSeconds: durationSeconds))
                if currentErrors > 5 || stubbornWordsMap[targetWord.id] != nil {
                    activeWrongRetrySet.remove(targetWord.id)
                    wrongRetryCycleByWordID.removeValue(forKey: targetWord.id)
                    return .promotedToStubbornWords(errorCountForWordToday: max(currentErrors, stubbornWordsMap[targetWord.id]?.errorCount ?? 6))
                }
                pendingQueue.removeAll { $0.id == targetWord.id }
                // 订正后短距离重现；第三轮再错时保留第三轮而不是从第一轮重练。
                let resumedCycle = max(1, wrongRetryCycleByWordID[targetWord.id, default: 0])
                wrongRetryCycleByWordID[targetWord.id] = resumedCycle
                let chosenOffset = retryOffset ?? Self.adaptiveRetryOffset(cycle: resumedCycle, availableWords: pendingQueue.count)
                let insertionIndex = min(max(1, chosenOffset), pendingQueue.count)
                pendingQueue.insert(targetWord, at: insertionIndex)
                return .requeuedForRetry(errorCountForWordToday: currentErrors, insertedAtOffset: insertionIndex)
            }

            // 2. 快速模式仅要求稍后一次无提示正确召回；保留快速跳题与错词反馈，不做四轮长循环。
            if strategy == .quick && activeWrongRetrySet.contains(targetWord.id) {
                activeWrongRetrySet.remove(targetWord.id)
                wrongRetryCycleByWordID.removeValue(forKey: targetWord.id)
                if stubbornWordsMap[targetWord.id] == nil { completedWordIDs.insert(targetWord.id) }
                attemptLogs.append(DictationAttemptLog(id: UUID(), sessionID: sessionID, mode: mode, wordID: targetWord.id, word: targetWord.word, deckID: targetWord.deckID, userTyped: rawInput, isCorrect: true, isFirstAttemptInSession: isFirstAttempt, sessionErrorCountForWord: currentErrors, timestamp: Date(), dateString: dateString, durationSeconds: durationSeconds))
                return .correct(exitedWrongQueue: true)
            }
            // 重复模式 / 错词复习模式：拼对后推进四轮递进循环。
            if activeWrongRetrySet.contains(targetWord.id) {
                let completedCycle = wrongRetryCycleByWordID[targetWord.id, default: 1]
                attemptLogs.append(DictationAttemptLog(id: UUID(), sessionID: sessionID, mode: mode, wordID: targetWord.id, word: targetWord.word, deckID: targetWord.deckID, userTyped: rawInput, isCorrect: true, isFirstAttemptInSession: isFirstAttempt, sessionErrorCountForWord: currentErrors, timestamp: Date(), dateString: dateString, durationSeconds: durationSeconds))

                let totalCycles = offsets.count // 4 轮
                // 若尚未满 4 轮，且队列中还有其他单词可穿插间隔，则进入下一轮循环（+13 -> +30 -> +53）
                if completedCycle < totalCycles && !pendingQueue.isEmpty {
                    let nextCycle = completedCycle + 1
                    wrongRetryCycleByWordID[targetWord.id] = nextCycle
                    pendingQueue.removeAll { $0.id == targetWord.id }
                    let targetOffset = retryOffset ?? Self.adaptiveRetryOffset(cycle: nextCycle, availableWords: pendingQueue.count)
                    let insertionIndex = min(max(1, targetOffset), pendingQueue.count)
                    pendingQueue.insert(targetWord, at: insertionIndex)
                    return .requeuedForRetry(errorCountForWordToday: currentErrors, insertedAtOffset: insertionIndex)
                } else {
                    // 已完成全部 4 轮循环（或词本已无剩余其他词可间隔），正式毕业出列！
                    activeWrongRetrySet.remove(targetWord.id)
                    wrongRetryCycleByWordID.removeValue(forKey: targetWord.id)
                    if stubbornWordsMap[targetWord.id] == nil {
                        completedWordIDs.insert(targetWord.id)
                    }
                    return .correct(exitedWrongQueue: true)
                }
            }

            // 3. 首次直接拼对
            if stubbornWordsMap[targetWord.id] == nil { completedWordIDs.insert(targetWord.id) }
            attemptLogs.append(DictationAttemptLog(id: UUID(), sessionID: sessionID, mode: mode, wordID: targetWord.id, word: targetWord.word, deckID: targetWord.deckID, userTyped: rawInput, isCorrect: true, isFirstAttemptInSession: isFirstAttempt, sessionErrorCountForWord: currentErrors, timestamp: Date(), dateString: dateString, durationSeconds: durationSeconds))
            return .correct(exitedWrongQueue: false)
        }

        // 拼写错误须先当场订正；已经走到后几轮的词保留轮次，不因一次失误重跑全部间隔。
        let newErrorCount = max(sessionErrorCounts[targetWord.id, default: 0], stubbornWordsMap[targetWord.id]?.errorCount ?? 0) + 1
        sessionErrorCounts[targetWord.id] = newErrorCount
        correctionPendingIDs.insert(targetWord.id)
        activeWrongRetrySet.insert(targetWord.id)
        if wrongRetryCycleByWordID[targetWord.id] == nil {
            wrongRetryCycleByWordID[targetWord.id] = 0
        }
        attemptLogs.append(DictationAttemptLog(id: UUID(), sessionID: sessionID, mode: mode, wordID: targetWord.id, word: targetWord.word, deckID: targetWord.deckID, userTyped: rawInput, isCorrect: false, isFirstAttemptInSession: isFirstAttempt, sessionErrorCountForWord: newErrorCount, timestamp: Date(), dateString: dateString, durationSeconds: durationSeconds))
        if strategy == .quick {
            // 保持立即跳题及反馈卡，但不能将答错的词误标为完成：短距插回同一轮，稍后无提示召回。
            pendingQueue.removeFirst()
            correctionPendingIDs.remove(targetWord.id)
            wrongRetryCycleByWordID[targetWord.id] = 1
            let targetOffset = retryOffset ?? Self.adaptiveRetryOffset(cycle: 1, availableWords: pendingQueue.count)
            pendingQueue.insert(targetWord, at: min(max(1, targetOffset), pendingQueue.count))
        }
        if newErrorCount > 5 || stubbornWordsMap[targetWord.id] != nil {
            stubbornWordsMap[targetWord.id] = StubbornWordRecord(wordID: targetWord.id, word: targetWord.word, sourceDeckID: targetWord.deckID, sourceDeckTitle: targetWord.deckTitle, dateString: dateString, errorCount: newErrorCount, triggeringSessionID: sessionID)
            if strategy != .quick { return .promotedToStubbornWords(errorCountForWordToday: newErrorCount) }
        }
        return strategy == .quick ? .skippedIncorrect : .needsCorrection(errorCountForWordToday: newErrorCount)
    }

    public static func todayDictatedWordCount(from logs: [DictationAttemptLog], on dateString: String) -> Int {
        Set(logs.lazy.filter { $0.dateString == dateString && $0.isCorrect }.map(\.wordID)).count
    }
}

public struct DictationSessionReport: Equatable, Sendable {
    public struct Row: Identifiable, Equatable, Sendable {
        public var id: String { wordID }
        public let wordID: String
        public let word: String
        public let errors: Int
        public let status: String
        public let maxReactionSeconds: Double
        public var isSlowReaction: Bool { maxReactionSeconds > SlowReactionWordRecord.slowThresholdSeconds }

        public init(wordID: String, word: String, errors: Int, status: String, maxReactionSeconds: Double = 0.0) {
            self.wordID = wordID
            self.word = word
            self.errors = errors
            self.status = status
            self.maxReactionSeconds = maxReactionSeconds
        }
    }
    public let totalWords: Int
    public let completedWords: Int
    public let firstTryCorrect: Int
    public let stubbornCount: Int
    public let slowReactionCount: Int
    public let rows: [Row]

    public init(session: DictationSessionStateMachine) {
        var words: [String: String] = [:]
        var maxLatencies: [String: Double] = [:]
        for item in session.pendingQueue { words[item.id] = item.word }
        for log in session.attemptLogs {
            words[log.wordID] = log.word
            if log.isCorrect {
                maxLatencies[log.wordID] = max(maxLatencies[log.wordID, default: 0.0], log.durationSeconds)
            }
        }
        for rec in session.stubbornWordsMap.values { words[rec.wordID] = rec.word }
        totalWords = words.count
        completedWords = session.completedWordIDs.count
        firstTryCorrect = Set(session.attemptLogs.filter { $0.isFirstAttemptInSession && $0.isCorrect }.map(\.wordID)).count
        stubbornCount = session.stubbornWordsMap.count
        slowReactionCount = words.keys.filter { maxLatencies[$0, default: 0.0] > SlowReactionWordRecord.slowThresholdSeconds }.count
        rows = words.map { id, word in
            let errors = max(session.sessionErrorCounts[id, default: 0], session.stubbornWordsMap[id]?.errorCount ?? 0)
            let maxLat = maxLatencies[id, default: 0.0]
            let status: String
            if session.stubbornWordsMap[id] != nil {
                status = "顽固单词"
            } else if errors > 0 {
                status = "四轮循环通过"
            } else if maxLat > SlowReactionWordRecord.slowThresholdSeconds {
                status = "慢反应词 (>5s)"
            } else {
                status = "一次通过"
            }
            return Row(wordID: id, word: word, errors: errors, status: status, maxReactionSeconds: maxLat)
        }.sorted { $0.errors != $1.errors ? $0.errors > $1.errors : $0.word < $1.word }
    }

    public var csv: String {
        let body = (["word,errors,status,max_reaction_seconds"] + rows.map {
            "\"\(Self.escape($0.word))\",\"\($0.errors)\",\"\(Self.escape($0.status))\",\"\(String(format: "%.2f", $0.maxReactionSeconds))\""
        }).joined(separator: "\n")
        return "\u{FEFF}" + body
    }

    private static func escape(_ text: String) -> String { text.replacingOccurrences(of: "\"", with: "\"\"") }
}

public struct DictationReportView: View {
    @Environment(\.studyAppearance) private var appearance
    public let report: DictationSessionReport
    public init(session: DictationSessionStateMachine) { self.report = DictationSessionReport(session: session) }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本轮听写报告").font(.headline)
                Spacer()
                Button("导出 CSV") {
                    let panel = NSSavePanel(); panel.nameFieldStringValue = "dictation-report.csv"
                    if panel.runModal() == .OK, let url = panel.url { try? report.csv.data(using: .utf8)?.write(to: url, options: .atomic) }
                }
            }
            Text("完成 \(report.completedWords)/\(report.totalWords) · 首次正确 \(report.firstTryCorrect) · 慢反应词 (>5s) \(report.slowReactionCount) · 顽固单词 \(report.stubbornCount)").font(.caption)
            ForEach(report.rows) { row in
                HStack {
                    Text(row.word).font(.body.weight(.semibold))
                    if row.maxReactionSeconds > 0 {
                        Text(String(format: "反应 %.1fs", row.maxReactionSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(row.isSlowReaction ? appearance.accent : appearance.ink.opacity(0.62))
                    }
                    Spacer()
                    Text("错误 \(row.errors) 次")
                    Text(row.status)
                        .foregroundStyle(appearance.accent)
                }.font(.caption)
            }
        }
    }
}
