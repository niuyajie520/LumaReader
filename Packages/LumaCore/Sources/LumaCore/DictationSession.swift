import Foundation

// 听写会话状态机：判题、错词调度、四轮循环、长措辞小错全在这里，
// 不依赖任何 UI 框架。macOS / iPhone（以及将来的 Android）共用同一套调度。
// 改动这里之后必须同步 spec/behaviour.json 与 spec/constants.json。

public enum DictationSessionMode: String, Codable, Sendable {
    case newTask = "new_task"
    case wrongWordReview = "wrong_word_review"
    case stubbornWordReview = "stubborn_word_review"
    case slowReactionReview = "slow_reaction_review"
}

/// 听写反应时长追踪记录：虽然拼写正确但从语音播完到敲下回车犹豫超过 5.0 秒的「慢反应词」
public struct SlowReactionWordRecord: Codable, Equatable, Identifiable, Sendable {
    public static let slowThresholdSeconds: Double = 5.0
    public var id: String { wordID }
    public let wordID: String
    public let word: String
    public var definitionZH: String
    public let sourceDeckID: String
    public let sourceDeckTitle: String
    public var lastReactionSeconds: Double
    public var maxReactionSeconds: Double
    public var bestReactionSeconds: Double?
    public var slowCount: Int
    public var dateString: String
    public var updatedAt: Date

    public init(
        wordID: String,
        word: String,
        definitionZH: String,
        sourceDeckID: String,
        sourceDeckTitle: String,
        lastReactionSeconds: Double,
        maxReactionSeconds: Double? = nil,
        bestReactionSeconds: Double? = nil,
        slowCount: Int = 1,
        dateString: String,
        updatedAt: Date = Date()
    ) {
        self.wordID = wordID
        self.word = word
        self.definitionZH = definitionZH
        self.sourceDeckID = sourceDeckID
        self.sourceDeckTitle = sourceDeckTitle
        self.lastReactionSeconds = lastReactionSeconds
        self.maxReactionSeconds = maxReactionSeconds ?? lastReactionSeconds
        self.bestReactionSeconds = bestReactionSeconds
        self.slowCount = slowCount
        self.dateString = dateString
        self.updatedAt = updatedAt
    }
}

public struct StubbornWordRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(wordID)_\(dateString)" }
    public let wordID: String
    public let word: String
    public let sourceDeckID: String
    public let sourceDeckTitle: String
    public let dateString: String // YYYY-MM-DD in local timezone
    public var errorCount: Int
    public let triggeringSessionID: UUID

    public init(
        wordID: String,
        word: String,
        sourceDeckID: String,
        sourceDeckTitle: String,
        dateString: String,
        errorCount: Int,
        triggeringSessionID: UUID
    ) {
        self.wordID = wordID
        self.word = word
        self.sourceDeckID = sourceDeckID
        self.sourceDeckTitle = sourceDeckTitle
        self.dateString = dateString
        self.errorCount = errorCount
        self.triggeringSessionID = triggeringSessionID
    }
}

public struct DictationAttemptLog: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let mode: DictationSessionMode
    public let wordID: String
    public let word: String
    public let deckID: String
    public let userTyped: String
    public let isCorrect: Bool
    public let isFirstAttemptInSession: Bool
    public let sessionErrorCountForWord: Int
    public let timestamp: Date
    public let dateString: String // YYYY-MM-DD
    public let durationSeconds: Double
    public var isSlowReaction: Bool {
        isCorrect && durationSeconds > SlowReactionWordRecord.slowThresholdSeconds
    }

    public init(
        id: UUID,
        sessionID: UUID,
        mode: DictationSessionMode,
        wordID: String,
        word: String,
        deckID: String,
        userTyped: String,
        isCorrect: Bool,
        isFirstAttemptInSession: Bool,
        sessionErrorCountForWord: Int,
        timestamp: Date,
        dateString: String,
        durationSeconds: Double
    ) {
        self.id = id
        self.sessionID = sessionID
        self.mode = mode
        self.wordID = wordID
        self.word = word
        self.deckID = deckID
        self.userTyped = userTyped
        self.isCorrect = isCorrect
        self.isFirstAttemptInSession = isFirstAttemptInSession
        self.sessionErrorCountForWord = sessionErrorCountForWord
        self.timestamp = timestamp
        self.dateString = dateString
        self.durationSeconds = durationSeconds
    }
}


public enum NewWordDictationStrategy: String, Sendable {
    case quick, repeating
}

public enum DictationSubmitOutcome: Equatable, Sendable {
    case correct(exitedWrongQueue: Bool)
    case needsCorrection(errorCountForWordToday: Int)
    /// 长措辞只差虚词：已标出差异片段，当场重试一次即可，不计错。
    case needsPhraseFix(fragment: String)
    case skippedIncorrect
    case requeuedForRetry(errorCountForWordToday: Int, insertedAtOffset: Int)
    case promotedToStubbornWords(errorCountForWordToday: Int)
}

/// 听写调度参数集中在这里；改数值不用改逻辑。
public enum DictationTuning {
    /// 学新词 ·「循环复习」的四档词距：隔 5 / 55 / 155 / 255 个词再听，第四档拼对即毕业。
    public static let newWordLadder: [Int] = [5, 55, 155, 255]
    /// 答错订正后的确认步：先隔 5 个词再听一次。
    public static let relearnStep: Int = 5
    /// 本轮同一个词错到第几次就挪到本轮最后单独练。
    public static let moveToEndAfterErrors: Int = 3
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

    /// 学新词「循环复习」的词距：严格按 5 / 55 / 155 / 255，剩余词不够时排到队尾。
    static func newWordLadderOffset(cycle: Int, availableWords: Int) -> Int {
        let available = max(0, availableWords)
        guard available > 0 else { return 0 }
        let ladder = DictationTuning.newWordLadder
        let stage = max(0, min(cycle - 1, ladder.count - 1))
        return min(available, ladder[stage])
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
    /// 学新词阶梯：高档答错后，确认步通过要跳回的档位（错在第 n 档 → 跳回第 n-1 档）。
    public private(set) var relearnTargetCycleByWordID: [String: Int] = [:]
    /// 本轮错满 3 次、已挪到本轮最后单独练的词。
    public private(set) var deferredToEndWordIDs: Set<String> = []
    /// 长措辞只差虚词、给过一次重试机会的词（第二次再差就按正常错词处理）。
    public private(set) var minorSlipWordIDs: Set<String> = []
    /// 本轮真正听错的次数（订正时打错不算新的一次）。
    public private(set) var roundMissCountByWordID: [String: Int] = [:]
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
        case relearnTargetCycleByWordID, deferredToEndWordIDs, roundMissCountByWordID
        case minorSlipWordIDs
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
        relearnTargetCycleByWordID = try c.decodeIfPresent([String: Int].self, forKey: .relearnTargetCycleByWordID) ?? [:]
        deferredToEndWordIDs = try c.decodeIfPresent(Set<String>.self, forKey: .deferredToEndWordIDs) ?? []
        roundMissCountByWordID = try c.decodeIfPresent([String: Int].self, forKey: .roundMissCountByWordID) ?? [:]
        minorSlipWordIDs = try c.decodeIfPresent(Set<String>.self, forKey: .minorSlipWordIDs) ?? []
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
    public mutating func submitAnswer(
        _ rawInput: String, durationSeconds: Double = 2.5, retryOffset: Int? = nil,
        newWordStrategy: NewWordDictationStrategy?
    ) -> DictationSubmitOutcome? {
        let strategy = mode == .newTask ? newWordStrategy : nil
        let offsets = Self.expandingRetryOffsets
        // 仅「学新词 · 循环复习」使用 5/55/155/255 阶梯与「错一次只退一档」规则；错词复习等模式保持原行为。
        let usesNewWordLadder = mode == .newTask && strategy == .repeating
        func ladderOffset(_ cycle: Int, available: Int) -> Int {
            usesNewWordLadder
                ? Self.newWordLadderOffset(cycle: cycle, availableWords: available)
                : Self.adaptiveRetryOffset(cycle: cycle, availableWords: available)
        }
        guard let targetWord = pendingQueue.first else { return nil }
        let isMatch = DictationAnswerPolicy.matches(rawInput, targetWord: targetWord.word)
        let isFirstAttempt = !wordsWithInitialAttemptLogged.contains(targetWord.id)
        wordsWithInitialAttemptLogged.insert(targetWord.id)

        // 长措辞只差虚词（冠词 / 介词 / 连词 / 助动词）：标出片段、当场重试一次。
        // 不计错、不进四轮循环、不进错词本；第二次再差就回到正常错词路径。
        if !isMatch,
           sessionErrorCounts[targetWord.id, default: 0] == 0,
           roundMissCountByWordID[targetWord.id, default: 0] == 0,
           !activeWrongRetrySet.contains(targetWord.id),
           !minorSlipWordIDs.contains(targetWord.id),
           DictationEntryKind.classify(targetWord.word) == .longPhrase,
           let fragment = DictationPhraseDiff.minorSlip(input: rawInput, target: targetWord.word) {
            minorSlipWordIDs.insert(targetWord.id)
            correctionPendingIDs.insert(targetWord.id)
            return .needsPhraseFix(fragment: fragment)
        }

        if isMatch {
            if durationSeconds > SlowReactionWordRecord.slowThresholdSeconds {
                slowReactionWordIDs.insert(targetWord.id)
            }
            pendingQueue.removeFirst()
            let currentErrors = sessionErrorCounts[targetWord.id, default: 0]
            // 1. 当场订正后短距重现；若此前已在循环中则保留原轮次。
            if correctionPendingIDs.remove(targetWord.id) != nil {
                attemptLogs.append(DictationAttemptLog(id: UUID(), sessionID: sessionID, mode: mode, wordID: targetWord.id, word: targetWord.word, deckID: targetWord.deckID, userTyped: rawInput, isCorrect: true, isFirstAttemptInSession: false, sessionErrorCountForWord: currentErrors, timestamp: Date(), dateString: dateString, durationSeconds: durationSeconds))
                if minorSlipWordIDs.remove(targetWord.id) != nil {
                    // 长措辞只差虚词、改对即过：不再插回队列滚动，明天做一次无提示整条回忆。
                    if stubbornWordsMap[targetWord.id] == nil { completedWordIDs.insert(targetWord.id) }
                    return .correct(exitedWrongQueue: false)
                }
                if currentErrors > 5 || stubbornWordsMap[targetWord.id] != nil {
                    activeWrongRetrySet.remove(targetWord.id)
                    wrongRetryCycleByWordID.removeValue(forKey: targetWord.id)
                    return .promotedToStubbornWords(errorCountForWordToday: max(currentErrors, stubbornWordsMap[targetWord.id]?.errorCount ?? 6))
                }
                pendingQueue.removeAll { $0.id == targetWord.id }
                // 订正后短距离重现；第三轮再错时保留第三轮而不是从第一轮重练。
                let resumedCycle = max(1, wrongRetryCycleByWordID[targetWord.id, default: 0])
                wrongRetryCycleByWordID[targetWord.id] = resumedCycle
                if usesNewWordLadder && roundMissCountByWordID[targetWord.id, default: 0] >= DictationTuning.moveToEndAfterErrors {
                    // 本轮错满 3 次：挪到本轮最后单独练，不再插在中间拖慢整轮。
                    deferredToEndWordIDs.insert(targetWord.id)
                    pendingQueue.append(targetWord)
                    return .requeuedForRetry(errorCountForWordToday: currentErrors, insertedAtOffset: pendingQueue.count - 1)
                }
                let chosenOffset = retryOffset ?? (usesNewWordLadder
                    ? min(DictationTuning.relearnStep, pendingQueue.count)
                    : ladderOffset(resumedCycle, available: pendingQueue.count))
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
                // 学新词：高档答错后的确认步通过，直接跳回「原档 - 1」，不从第 1 档重爬。
                let relearnTarget = usesNewWordLadder ? relearnTargetCycleByWordID.removeValue(forKey: targetWord.id) : nil
                // 学新词阶梯：队列里没有别的词可间隔时也不毕业。高档答错后本来就欠一次「退一档」回炉，
                // 一次手滑不该让这个词直接消失成「已掌握」；宁可紧接着再考一轮。
                if completedCycle < totalCycles && (!pendingQueue.isEmpty || usesNewWordLadder) {
                    let nextCycle = relearnTarget ?? (completedCycle + 1)
                    wrongRetryCycleByWordID[targetWord.id] = nextCycle
                    pendingQueue.removeAll { $0.id == targetWord.id }
                    let targetOffset = retryOffset ?? ladderOffset(nextCycle, available: pendingQueue.count)
                    let insertionIndex = min(max(1, targetOffset), pendingQueue.count)
                    pendingQueue.insert(targetWord, at: insertionIndex)
                    return .requeuedForRetry(errorCountForWordToday: currentErrors, insertedAtOffset: insertionIndex)
                } else {
                    // 已完成全部 4 轮循环（或词本已无剩余其他词可间隔），正式毕业出列！
                    activeWrongRetrySet.remove(targetWord.id)
                    wrongRetryCycleByWordID.removeValue(forKey: targetWord.id)
                    relearnTargetCycleByWordID.removeValue(forKey: targetWord.id)
                    deferredToEndWordIDs.remove(targetWord.id)
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
        let isFreshMiss = !correctionPendingIDs.contains(targetWord.id)
        correctionPendingIDs.insert(targetWord.id)
        minorSlipWordIDs.remove(targetWord.id)
        activeWrongRetrySet.insert(targetWord.id)
        if usesNewWordLadder && isFreshMiss {
            roundMissCountByWordID[targetWord.id, default: 0] += 1
            // 错在第 n 档（n ≥ 3）：订正 → 隔 5 个词确认 → 跳回第 n-1 档。
            // 错在第 1、2 档：订正 → 隔 5 个词 → 第 2 档起往上（退一档本来就是第 1 档）。
            // 确认步里又错，以目标档为基准再退一档。
            let effectiveCycle = relearnTargetCycleByWordID[targetWord.id]
                ?? wrongRetryCycleByWordID[targetWord.id, default: 0]
            if effectiveCycle >= 3 {
                relearnTargetCycleByWordID[targetWord.id] = effectiveCycle - 1
            } else {
                relearnTargetCycleByWordID.removeValue(forKey: targetWord.id)
            }
            wrongRetryCycleByWordID[targetWord.id] = 1
        } else if wrongRetryCycleByWordID[targetWord.id] == nil {
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

    /// 提前结束本轮：把剩下的词清空，已完成的进度保留。
    public mutating func skipRemaining() {
        pendingQueue.removeAll()
        correctionPendingIDs.removeAll()
    }

    public static func todayDictatedWordCount(from logs: [DictationAttemptLog], on dateString: String) -> Int {
        Set(logs.lazy.filter { $0.dateString == dateString && $0.isCorrect }.map(\.wordID)).count
    }
}

