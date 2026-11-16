import Foundation
import Observation

/// 学习数据仓库：与 macOS 版共用同一份 `luma_study_store.json` 架构。
/// 内部保留原始 JSON 字典，只覆盖自己管理的键，macOS 独有字段（写作、AI、星漫…）原样保留，
/// 这样同一份文件在两端来回同步不会丢数据。
@Observable
final class StudyStore {

    // MARK: 路径

    static func defaultFolder() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("StudyCenter", isDirectory: true)
    }

    let folder: URL
    var fileURL: URL { folder.appendingPathComponent("luma_study_store.json") }

    // MARK: 状态

    private(set) var words: [VocabularyWord] = []
    private(set) var schedule: [String: WordReviewProgress] = [:]
    private(set) var logs: [DictationAttemptLog] = []
    private(set) var stubborn: [StubbornWordRecord] = []
    private(set) var selectedDeckID: String = ""

    private var raw: [String: Any] = [:]
    private var saveTask: Task<Void, Never>?

    var lastError: String?

    // MARK: 初始化

    init(folder: URL = StudyStore.defaultFolder()) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            raw = ["schemaVersion": 2]
            words = []
            schedule = [:]
            logs = []
            stubborn = []
            return
        }
        raw = object
        words = Self.decodeWords(object["importedWords"])
        rebuildIndex()
        schedule = Self.decodeSchedule(object["reviewSchedule"])
        logs = Self.decodeLogs(object["dictationLogs"])
        stubborn = Self.decodeStubborn(object["stubbornWords"])
        if let workspace = object["workspace"] as? [String: Any], let id = workspace["selectedDeckID"] as? String {
            selectedDeckID = id
        }
    }

    // MARK: 内置起步词表

    /// 首次打开、词库为空时，用内置的 6063 条阅读词表起个底，保证一上手就能听写。
    static let starterDeckID = "ios.reading.core"
    static let starterDeckTitle = "阅读词表"

    var isStarterOnly: Bool {
        !words.isEmpty && words.allSatisfy { $0.deckID == Self.starterDeckID }
    }

    func seedStarterDeckIfNeeded() {
        guard words.isEmpty else { return }
        let seeded = Self.bundledReadingWords()
        guard !seeded.isEmpty else { return }
        words = seeded
        rebuildIndex()
        if selectedDeckID == nil { selectedDeckID = Self.starterDeckID }
        raw["importedWords"] = seeded.map(\.json)
        scheduleSave()
    }

    static func bundledReadingWords() -> [VocabularyWord] {
        let candidates = [
            Bundle.main.url(forResource: "ReadingVocabulary", withExtension: "json"),
            Bundle.main.url(forResource: "ReadingVocabulary", withExtension: "json", subdirectory: "Resources")
        ]
        guard let url = candidates.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: url),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        var result: [VocabularyWord] = []
        result.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            guard let word = (item["word"] as? String) ?? (item["label"] as? String) else { continue }
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let stableID = (item["id"] as? String).map { $0 } ?? {
                if let number = item["number"] as? Int { return String(number) }
                if let number = item["number"] as? String { return number }
                return String(index)
            }()
            result.append(VocabularyWord(
                id: "ios_reading_\(stableID)",
                word: trimmed,
                phoneticUS: (item["ipa"] as? String) ?? "",
                definitionZH: (item["meaning"] as? String) ?? "",
                deckID: starterDeckID,
                deckTitle: starterDeckTitle
            ))
        }
        return result
    }

    // MARK: 词库

    var decks: [VocabularyDeck] {
        var order: [String] = []
        var grouped: [String: [VocabularyWord]] = [:]
        for word in words {
            if grouped[word.deckID] == nil { order.append(word.deckID) }
            grouped[word.deckID, default: []].append(word)
        }
        return order.compactMap { deckID in
            guard let list = grouped[deckID], !list.isEmpty else { return nil }
            let title = list.first?.deckTitle ?? deckID
            return VocabularyDeck(id: deckID, title: title.isEmpty ? deckID : title, words: list)
        }
    }

    func deck(id: String) -> VocabularyDeck? { decks.first { $0.id == id } }

    func word(id: String) -> VocabularyWord? { index[id] }

    private var index: [String: VocabularyWord] = [:]

    private func rebuildIndex() {
        index = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var activeDeck: VocabularyDeck? {
        deck(id: selectedDeckID) ?? decks.first
    }

    func select(deckID: String) {
        selectedDeckID = deckID
        var workspace = (raw["workspace"] as? [String: Any]) ?? [:]
        workspace["selectedDeckID"] = deckID
        raw["workspace"] = workspace
        scheduleSave()
    }

    func replaceWords(_ list: [VocabularyWord]) {
        words = list
        rebuildIndex()
        raw["importedWords"] = list.map(\.json)
        scheduleSave()
    }

    // MARK: 复习进度

    func progress(for wordID: String) -> WordReviewProgress? { schedule[wordID] }

    /// 记一次「无提示回忆」结果。为了不踩掉 macOS 已经排好的跨天复习，
    /// 同一天第二次答对只会把 dueAt 顶到明天，不会推翻既有间隔。
    func recordReview(wordID: String, cleanRecall: Bool, reactionSeconds: Double, at now: Date = Date()) {
        var progress = schedule[wordID] ?? WordReviewProgress(dueAt: now)
        progress.record(cleanRecall: cleanRecall, reactionSeconds: reactionSeconds, at: now)
        schedule[wordID] = progress
        scheduleSave()
    }

    var dueReviews: [VocabularyWord] {
        let now = Date()
        return words.filter { WordReviewOrdering.isDueForNextDayRecall(schedule[$0.id], now: now) }
    }

    // MARK: 听写记录

    func appendLog(_ log: DictationAttemptLog) {
        logs.append(log)
        scheduleSave()
    }

    func wrongWords(inRound sessionID: UUID?, deckID: String?) -> [DictationAttemptLog] {
        var result = logs.filter { !$0.isCorrect }
        if let sessionID { result = result.filter { $0.sessionID == sessionID } }
        if let deckID { result = result.filter { $0.deckID == deckID } }
        return result.sorted { $0.timestamp > $1.timestamp }
    }

    /// 本轮错误按词去重（一个词错 10 次也只算一个词，不显示次数）。
    func wrongWordIDs(inRound sessionID: UUID?, deckID: String?) -> Set<String> {
        Set(wrongWords(inRound: sessionID, deckID: deckID).map(\.wordID))
    }

    func reviewQueue(deckID: String, limit: Int) -> [VocabularyWord] {
        guard let deck = deck(id: deckID) else { return [] }
        let now = Date()
        let due = deck.words.enumerated()
            .filter { WordReviewOrdering.isDueForNextDayRecall(schedule[$0.element.id], now: now) }
            .sorted { lhs, rhs in
                let l = schedule[lhs.element.id]?.ebbinghausRetrievability(at: now) ?? 0
                let r = schedule[rhs.element.id]?.ebbinghausRetrievability(at: now) ?? 0
                if l == r { return lhs.offset < rhs.offset }
                return l < r
            }
            .map(\.element)
        return Array(due.prefix(limit))
    }

    // MARK: 顽固词

    func markStubborn(word: VocabularyWord, missCount: Int, sessionID: UUID = UUID()) {
        if let index = stubborn.firstIndex(where: { $0.wordID == word.id }) {
            stubborn[index].errorCount += missCount
        } else {
            stubborn.append(StubbornWordRecord(
                wordID: word.id,
                word: word.word,
                sourceDeckID: word.deckID,
                sourceDeckTitle: word.deckTitle,
                dateString: JSONDate.dayString(Date()),
                errorCount: missCount,
                triggeringSessionID: sessionID
            ))
        }
        scheduleSave()
    }

    func stubbornWords(deckID: String) -> [VocabularyWord] {
        let ids = Set(stubborn.filter { $0.sourceDeckID == deckID }.map(\.wordID))
        return (deck(id: deckID)?.words ?? []).filter { ids.contains($0.id) }
    }

    // MARK: 朗读设置（与 macOS 版共用 preferredAccent / preferredSpeechRate 字段）

    var speechAccent: SpeechService.Accent {
        get { SpeechService.Accent(rawValue: (raw["preferredAccent"] as? String) ?? "") ?? .american }
        set {
            raw["preferredAccent"] = newValue.rawValue
            scheduleSave()
        }
    }

    var speechRate: Double {
        get {
            if let value = raw["preferredSpeechRate"] as? Double { return value }
            return 0.48
        }
        set {
            raw["preferredSpeechRate"] = min(max(newValue, 0.2), 0.8)
            scheduleSave()
        }
    }

    var speechRepeatCount: Int {
        get { (raw["speechRepeatCount"] as? Int) ?? 1 }
        set {
            raw["speechRepeatCount"] = min(max(newValue, 1), 3)
            scheduleSave()
        }
    }

    // MARK: 合并（云同步用）

    /// 合并另一端的学习数据：词条按 id 取并集，复习进度取「更靠后的一次复习」，
    /// 听写日志按 id 取并集。绝不删除本地词条，也不会把进度往回退。
    func mergeRemote(words remoteWords: [VocabularyWord],
                     schedule remoteSchedule: [String: WordReviewProgress],
                     logs remoteLogs: [DictationAttemptLog],
                     stubborn remoteStubborn: [StubbornWordRecord],
                     replacingWords: Bool = false) {
        // 合并规则全在 LumaCore.SyncMerge，与 macOS 版同一份实现。
        words = SyncMerge.mergeWords(replacingWords ? [] : words, remoteWords)
            .sorted { $0.id < $1.id }
        schedule = SyncMerge.mergeSchedule(schedule, remoteSchedule)
        logs = SyncMerge.mergeLogs(logs, remoteLogs)
        stubborn = SyncMerge.mergeStubborn(stubborn, remoteStubborn)

        rebuildIndex()
        saveNow()
    }

    /// 导出整份原始 JSON，供同步写入共享目录。
    var rawSnapshotData: Data? {
        var object = raw
        object["importedWords"] = words.map(\.json)
        object["reviewSchedule"] = Self.encodeSchedule(schedule)
        object["dictationLogs"] = Self.encodeLogs(logs)
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return nil }
        return data
    }

    /// 从共享目录读到的整份数据里解析出四类学习记录。
    static func decodeSnapshot(_ data: Data) -> (words: [VocabularyWord], schedule: [String: WordReviewProgress], logs: [DictationAttemptLog], stubborn: [StubbornWordRecord])? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (decodeWords(object["importedWords"]), decodeSchedule(object["reviewSchedule"]),
                decodeLogs(object["dictationLogs"]), decodeStubborn(object["stubbornWords"]))
    }

    // MARK: 保存

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.saveNow() }
        }
    }

    func saveNow() {
        var object = raw
        object["schemaVersion"] = raw["schemaVersion"] ?? 2
        object["importedWords"] = words.map(\.json)
        object["reviewSchedule"] = Self.encodeSchedule(schedule)
        object["dictationLogs"] = Self.encodeLogs(logs)
        object["stubbornWords"] = stubborn.map { record in
            [
                "wordID": record.wordID,
                "word": record.word,
                "sourceDeckID": record.sourceDeckID,
                "sourceDeckTitle": record.sourceDeckTitle,
                "dateString": record.dateString,
                "errorCount": record.errorCount,
                "triggeringSessionID": record.triggeringSessionID.uuidString
            ] as [String: Any]
        }
        var workspace = (object["workspace"] as? [String: Any]) ?? [:]
        workspace["selectedDeckID"] = selectedDeckID
        object["workspace"] = workspace
        raw = object

        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            lastError = "学习数据无法序列化。"
            return
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            lastError = "写入学习数据失败：\(error.localizedDescription)"
        }
    }

    // MARK: 编解码

    private static func decodeWords(_ value: Any?) -> [VocabularyWord] {
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { VocabularyWord(json: $0) }
    }

    private static func decodeSchedule(_ value: Any?) -> [String: WordReviewProgress] {
        guard let dict = value as? [String: Any] else { return [:] }
        var result: [String: WordReviewProgress] = [:]
        for (key, entry) in dict {
            guard let entry = entry as? [String: Any] else { continue }
            var progress = WordReviewProgress(dueAt: JSONDate.decode(entry["dueAt"] as? String) ?? Date())
            progress.stage = (entry["stage"] as? Int) ?? Int((entry["stage"] as? Double) ?? 0)
            progress.lapses = (entry["lapses"] as? Int) ?? 0
            progress.stability = (entry["stability"] as? Double) ?? 1
            progress.difficulty = (entry["difficulty"] as? Double) ?? 5
            progress.lastReviewedAt = JSONDate.decode(entry["lastReviewedAt"] as? String)
            result[key] = progress
        }
        return result
    }

    private static func encodeSchedule(_ schedule: [String: WordReviewProgress]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, progress) in schedule {
            var entry: [String: Any] = [
                "stage": progress.stage,
                "lapses": progress.lapses,
                "stability": progress.stability,
                "difficulty": progress.difficulty,
                "dueAt": JSONDate.encode(progress.dueAt)
            ]
            if let last = progress.lastReviewedAt { entry["lastReviewedAt"] = JSONDate.encode(last) }
            result[key] = entry
        }
        return result
    }

    private static func decodeLogs(_ value: Any?) -> [DictationAttemptLog] {
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let id = (entry["id"] as? String).flatMap(UUID.init(uuidString:)),
                  let wordID = entry["wordID"] as? String else { return nil }
            return DictationAttemptLog(
                id: id,
                sessionID: (entry["sessionID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
                mode: DictationSessionMode(rawValue: (entry["mode"] as? String) ?? "new_task") ?? .newTask,
                wordID: wordID,
                word: (entry["word"] as? String) ?? "",
                deckID: (entry["deckID"] as? String) ?? "",
                userTyped: (entry["userTyped"] as? String) ?? "",
                isCorrect: (entry["isCorrect"] as? Bool) ?? false,
                isFirstAttemptInSession: (entry["isFirstAttemptInSession"] as? Bool) ?? false,
                sessionErrorCountForWord: (entry["sessionErrorCountForWord"] as? Int) ?? 0,
                timestamp: JSONDate.decode(entry["timestamp"] as? String) ?? Date(),
                dateString: (entry["dateString"] as? String) ?? "",
                durationSeconds: (entry["durationSeconds"] as? Double) ?? 0
            )
        }
    }

    private static func encodeLogs(_ logs: [DictationAttemptLog]) -> [[String: Any]] {
        logs.map { log in
            [
                "id": log.id.uuidString,
                "wordID": log.wordID,
                "word": log.word,
                "deckID": log.deckID,
                "userTyped": log.userTyped,
                "isCorrect": log.isCorrect,
                "isFirstAttemptInSession": log.isFirstAttemptInSession,
                "sessionID": log.sessionID.uuidString,
                "mode": log.mode.rawValue,
                "dateString": log.dateString,
                "timestamp": JSONDate.encode(log.timestamp),
                "durationSeconds": log.durationSeconds,
                "sessionErrorCountForWord": log.sessionErrorCountForWord
            ] as [String: Any]
        }
    }

    private static func decodeStubborn(_ value: Any?) -> [StubbornWordRecord] {
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let wordID = entry["wordID"] as? String else { return nil }
            return StubbornWordRecord(
                wordID: wordID,
                word: (entry["word"] as? String) ?? "",
                sourceDeckID: (entry["sourceDeckID"] as? String) ?? (entry["deckID"] as? String) ?? "",
                sourceDeckTitle: (entry["sourceDeckTitle"] as? String) ?? "",
                dateString: (entry["dateString"] as? String) ?? "",
                errorCount: (entry["errorCount"] as? Int) ?? (entry["missCount"] as? Int) ?? 0,
                triggeringSessionID: (entry["triggeringSessionID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            )
        }
    }
}
