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
    private var correctionPendingIDs:Set<String>? = nil
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

    private enum CodingKeys:String,CodingKey { case sessionID,mode,dateString,spacingInterval,pendingQueue,completedWordIDs,activeWrongCycleWordIDs,sessionErrorCounts,stubbornWordsMap,attemptLogs,correctionPendingIDs,seenWordIDsInSession }
    public init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        let logs = try c.decodeIfPresent([DictationAttemptLog].self,forKey:.attemptLogs) ?? []
        self.init(sessionID:try c.decode(UUID.self,forKey:.sessionID),mode:try c.decodeIfPresent(DictationSessionMode.self,forKey:.mode) ?? .newTask,dateString:try c.decode(String.self,forKey:.dateString),initialWords:try c.decode([VocabularyWord].self,forKey:.pendingQueue),spacingInterval:try c.decodeIfPresent(Int.self,forKey:.spacingInterval) ?? 3,previousLogs:logs)
        completedWordIDs = try c.decodeIfPresent(Set<String>.self,forKey:.completedWordIDs) ?? []
        activeWrongCycleWordIDs = try c.decodeIfPresent(Set<String>.self,forKey:.activeWrongCycleWordIDs) ?? []
        sessionErrorCounts = try c.decodeIfPresent([String:Int].self,forKey:.sessionErrorCounts) ?? sessionErrorCounts
        stubbornWordsMap = try c.decodeIfPresent([String:StubbornWordRecord].self,forKey:.stubbornWordsMap) ?? [:]
        attemptLogs = logs
        correctionPendingIDs = try c.decodeIfPresent(Set<String>.self,forKey:.correctionPendingIDs)
        seenWordIDsInSession = try c.decodeIfPresent(Set<String>.self,forKey:.seenWordIDsInSession) ?? Set(logs.map(\.wordID))
    }

    public var currentWord: VocabularyWord? {
        pendingQueue.first
    }

    public var requiresCorrection:Bool {currentWord.map{correctionPendingIDs?.contains($0.id)==true} ?? false}

    public var isSessionFinished: Bool {
        pendingQueue.isEmpty
    }

    /// Incorrect input never advances. Correcting a failed presentation schedules
    /// one delayed retrieval; only a later clean retrieval completes that cycle.
    @discardableResult
    public mutating func submitAnswer(_ rawInput:String,durationSeconds:Double=2.5,retryOffset:Int?=nil)->DictationSubmissionOutcome? {
        guard let wordItem=pendingQueue.first else{return nil}
        let target=DictationAnswerPolicy.normalized(wordItem.word)
        let isCorrect = !target.isEmpty && DictationAnswerPolicy.normalized(rawInput)==target
        let first = !seenWordIDsInSession.contains(wordItem.id)
        seenWordIDsInSession.insert(wordItem.id)
        let errors=sessionErrorCounts[wordItem.id,default:0] + (isCorrect ? 0:1)
        sessionErrorCounts[wordItem.id]=errors
        attemptLogs.append(DictationAttemptLog(id:UUID(),sessionID:sessionID,mode:mode,wordID:wordItem.id,word:wordItem.word,deckID:wordItem.deckID,userTyped:rawInput,isCorrect:isCorrect,isFirstAttemptInSession:first,sessionErrorCountForWord:errors,timestamp:Date(),dateString:dateString,durationSeconds:durationSeconds))
        if !isCorrect {
            if correctionPendingIDs==nil{correctionPendingIDs=[]}
            correctionPendingIDs?.insert(wordItem.id)
            activeWrongCycleWordIDs.insert(wordItem.id);completedWordIDs.remove(wordItem.id)
            if var existing=stubbornWordsMap[wordItem.id] {
                existing.errorCount=max(existing.errorCount+1,errors)
                stubbornWordsMap[wordItem.id]=existing
            }
            if errors>5 {
                let record=StubbornWordRecord(wordID:wordItem.id,word:wordItem.word,sourceDeckID:wordItem.deckID,sourceDeckTitle:wordItem.deckTitle,dateString:dateString,errorCount:max(errors,stubbornWordsMap[wordItem.id]?.errorCount ?? 0),triggeringSessionID:sessionID)
                stubbornWordsMap[wordItem.id]=record
                return .promotedToStubbornWords(record:record)
            }
            return .needsCorrection(errorCount:errors)
        }
        pendingQueue.removeFirst()
        if correctionPendingIDs?.remove(wordItem.id) != nil {
            // Quarantine only AFTER the current word is corrected, never skip it.
            if stubbornWordsMap[wordItem.id] != nil {
                activeWrongCycleWordIDs.remove(wordItem.id)
                return .correct(exitedWrongCycle:false)
            }
            let upper=min(max(2,spacingInterval+2),pendingQueue.count)
            let lower=min(2,upper)
            let offset=min(upper,max(lower,retryOffset ?? Int.random(in:lower...upper)))
            pendingQueue.insert(wordItem,at:offset)
            return .requeuedForRetry(errorCount:errors,insertedAtOffset:offset)
        }
        let exited=activeWrongCycleWordIDs.remove(wordItem.id) != nil
        completedWordIDs.insert(wordItem.id)
        return .correct(exitedWrongCycle:exited)
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
    case needsCorrection(errorCount:Int)
    case correct(exitedWrongCycle: Bool)
    case requeuedForRetry(errorCount: Int, insertedAtOffset: Int)
    case promotedToStubbornWords(record: StubbornWordRecord)
}



/// Matching only: original input is never rewritten in the saved attempt log.
public nonisolated enum DictationAnswerPolicy {
    public static func normalized(_ text:String)->String {
        let ignored=CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols).union(.controlCharacters)
        return String(String.UnicodeScalarView(text.precomposedStringWithCanonicalMapping.lowercased().unicodeScalars.filter{!ignored.contains($0)}))
    }
}
