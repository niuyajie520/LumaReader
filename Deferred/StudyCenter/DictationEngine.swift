import Foundation

public struct DictationSessionStateMachine: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let mode: DictationSessionMode
    public let dateString: String
    public let spacingInterval: Int

    public private(set) var pendingQueue: [VocabularyWord]
    public private(set) var completedWordIDs: Set<String> = []
    public private(set) var activeWrongCycleWordIDs: Set<String> = []
    public private(set) var sessionErrorCounts: [String: Int] = [:]
    public private(set) var stubbornWordsMap: [String: StubbornWordRecord] = [:]
    public private(set) var attemptLogs: [DictationAttemptLog] = []
    private var seenWordIDsInSession: Set<String> = []

    public init(
        sessionID: UUID = UUID(),
        mode: DictationSessionMode = .newTask,
        dateString: String,
        initialWords: [VocabularyWord],
        existingStubbornWordsForToday: [StubbornWordRecord] = [],
        spacingInterval: Int = 3,
        previousLogs: [DictationAttemptLog] = []
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.dateString = dateString
        self.spacingInterval = max(1, spacingInterval)
        for log in previousLogs where log.dateString == dateString && log.mode == mode && !log.isCorrect {
            sessionErrorCounts[log.wordID,default:0] += 1
        }

        for rec in existingStubbornWordsForToday where rec.dateString == dateString {
            stubbornWordsMap[rec.wordID] = rec
        }

        // Filter out words already quarantined as stubborn today unless explicitly in stubbornWordReview mode
        if mode == .stubbornWordReview {
            self.pendingQueue = initialWords
        } else {
            let quarantinedIDs = Set(stubbornWordsMap.keys)
            self.pendingQueue = initialWords.filter { !quarantinedIDs.contains($0.id) }
        }
    }

    public var currentWord: VocabularyWord? {
        pendingQueue.first
    }

    public var isSessionFinished: Bool {
        pendingQueue.isEmpty
    }

    /// Submits the user's dictated spelling for `currentWord`.
    @discardableResult
    public mutating func submitAnswer(_ rawInput: String, durationSeconds: Double = 2.5) -> DictationSubmissionOutcome? {
        guard !pendingQueue.isEmpty else { return nil }
        let wordItem = pendingQueue.removeFirst()

        let normalizedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTarget = wordItem.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isCorrect = (normalizedInput == normalizedTarget)

        let isFirstAttempt = !seenWordIDsInSession.contains(wordItem.id)
        seenWordIDsInSession.insert(wordItem.id)

        if isCorrect {
            activeWrongCycleWordIDs.remove(wordItem.id)
            completedWordIDs.insert(wordItem.id)
            let errCount = sessionErrorCounts[wordItem.id, default: 0]
            let log = DictationAttemptLog(
                id: UUID(),
                sessionID: sessionID,
                mode: mode,
                wordID: wordItem.id,
                word: wordItem.word,
                deckID: wordItem.deckID,
                userTyped: rawInput,
                isCorrect: true,
                isFirstAttemptInSession: isFirstAttempt,
                sessionErrorCountForWord: errCount,
                timestamp: Date(),
                dateString: dateString,
                durationSeconds: durationSeconds
            )
            attemptLogs.append(log)
            return .correct(exitedWrongCycle: errCount > 0)
        } else {
            let newErrCount = sessionErrorCounts[wordItem.id, default: 0] + 1
            sessionErrorCounts[wordItem.id] = newErrCount

            let log = DictationAttemptLog(
                id: UUID(),
                sessionID: sessionID,
                mode: mode,
                wordID: wordItem.id,
                word: wordItem.word,
                deckID: wordItem.deckID,
                userTyped: rawInput,
                isCorrect: false,
                isFirstAttemptInSession: isFirstAttempt,
                sessionErrorCountForWord: newErrCount,
                timestamp: Date(),
                dateString: dateString,
                durationSeconds: durationSeconds
            )
            attemptLogs.append(log)

            // Update error count if already in stubborn map
            if var existingStubborn = stubbornWordsMap[wordItem.id] {
                existingStubborn.errorCount = max(existingStubborn.errorCount + 1, newErrCount)
                stubbornWordsMap[wordItem.id] = existingStubborn
            }

            if newErrCount >= 5 && mode != .stubbornWordReview {
                // 5th error today -> enters Stubborn Words, removed from today's automatic queue
                activeWrongCycleWordIDs.remove(wordItem.id)
                let record = StubbornWordRecord(
                    wordID: wordItem.id,
                    word: wordItem.word,
                    sourceDeckID: wordItem.deckID,
                    sourceDeckTitle: wordItem.deckTitle,
                    dateString: dateString,
                    errorCount: newErrCount,
                    triggeringSessionID: sessionID
                )
                stubbornWordsMap[wordItem.id] = record
                return .promotedToStubbornWords(record: record)
            } else {
                // 1..4 errors -> re-insert into pendingQueue at spaced interval
                activeWrongCycleWordIDs.insert(wordItem.id)
                let insertIndex = min(spacingInterval, pendingQueue.count)
                pendingQueue.insert(wordItem, at: insertIndex)
                return .requeuedForRetry(errorCount: newErrCount, insertedAtOffset: insertIndex)
            }
        }
    }

    /// Returns stubborn words sorted by `errorCount` descending (Section 四.6).
    public var sortedStubbornWords: [StubbornWordRecord] {
        stubbornWordsMap.values.sorted {
            if $0.errorCount != $1.errorCount {
                return $0.errorCount > $1.errorCount
            }
            return $0.word < $1.word
        }
    }

    /// Computes real daily dictated unique word count for the Listening home card subtitle
    /// ("今天已听写 N 个单词", Section 三).
    public static func todayDictatedWordCount(from logs: [DictationAttemptLog], on dateString: String) -> Int {
        let todayWordIDs = Set(
            logs.lazy
                .filter { $0.dateString == dateString }
                .map(\.wordID)
        )
        return todayWordIDs.count
    }
}

public enum DictationSubmissionOutcome: Equatable, Sendable {
    case correct(exitedWrongCycle: Bool)
    case requeuedForRetry(errorCount: Int, insertedAtOffset: Int)
    case promotedToStubbornWords(record: StubbornWordRecord)
}


