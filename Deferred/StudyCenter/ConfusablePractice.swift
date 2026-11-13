import Foundation
import SwiftUI
import AppKit

// MARK: - 1.12.0 易混词系统 + 练习引擎（主窗口与悬浮小窗共用）
//
// 易混词库是独立系统：自己的文件（Application Support/LumaReader/Confusable/confusable_groups.json，
// 原子写入 + .bak 备份），不读写听力词库、背词词库和听写会话。
// 听力听写在小窗里只做两件事：读取听力词库里的单词出题；答题结果以普通听写记录写回错词本。

public enum LumaMiniPracticeNotification {
    /// userInfo: ["source": "confusable" | "listening", "scope": 词组 id / 词库 id（可选）]
    public static let open = Notification.Name("LumaReader.OpenMiniPractice")
}

// MARK: 数据模型

struct LumaConfusableEntry: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var word: String
    var meaning: String
    var phonetic: String
    var readingWordID: String?

    init(id: String = UUID().uuidString, word: String, meaning: String = "", phonetic: String = "", readingWordID: String? = nil) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.phonetic = phonetic
        self.readingWordID = readingWordID
    }
}

struct LumaConfusableGroup: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var category: String
    var entries: [LumaConfusableEntry]
    var createdAt: Date
    var updatedAt: Date
    var attempts: Int
    var misses: Int

    init(id: String = UUID().uuidString, title: String = "", category: String = "",
         entries: [LumaConfusableEntry], createdAt: Date = Date(), updatedAt: Date = Date(),
         attempts: Int = 0, misses: Int = 0) {
        self.id = id
        self.title = title
        self.category = category
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attempts = attempts
        self.misses = misses
    }

    var displayTitle: String {
        title.isEmpty ? entries.map(\.word).joined(separator: " / ") : title
    }
    var wordKey: Set<String> { Set(entries.map { $0.word.lowercased() }) }
    var missRate: Double { attempts == 0 ? 0 : Double(misses) / Double(attempts) }
}

struct LumaConfusableSnapshot: Codable, Equatable, Sendable {
    var schema: Int = 1
    var groups: [LumaConfusableGroup] = []
}

// MARK: 词库（独立文件、原子写入）

@MainActor
final class LumaConfusableLibrary: ObservableObject {
    static let shared = LumaConfusableLibrary()

    @Published private(set) var snapshot = LumaConfusableSnapshot()
    @Published var lastError: String?
    private let fileURL: URL?

    init(directory: URL? = nil) {
        let base: URL? = directory ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            .map { $0.appendingPathComponent("LumaReader/Confusable", isDirectory: true) }
        if let base { try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true) }
        fileURL = base?.appendingPathComponent("confusable_groups.json")
        load()
    }

    private var backupURL: URL? { fileURL?.appendingPathExtension("bak") }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(LumaConfusableSnapshot.self, from: data) {
            snapshot = decoded
            return
        }
        let damaged = fileURL.deletingLastPathComponent()
            .appendingPathComponent("confusable_groups.damaged-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.copyItem(at: fileURL, to: damaged)
        if let backupURL, let bak = try? Data(contentsOf: backupURL),
           let decoded = try? decoder.decode(LumaConfusableSnapshot.self, from: bak) {
            snapshot = decoded
            lastError = "易混词文件损坏，已从备份恢复；损坏文件已另存。"
        } else {
            lastError = "易混词文件无法读取，原文件已另存为 damaged 副本。"
        }
    }

    @discardableResult
    private func commit(_ next: LumaConfusableSnapshot) -> Bool {
        let previous = snapshot
        snapshot = next
        guard let fileURL else { return true }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(next)
            if let backupURL, FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            snapshot = previous
            lastError = "保存失败，易混词保持原样：\(error.localizedDescription)"
            return false
        }
    }

    var groups: [LumaConfusableGroup] { snapshot.groups }

    var categories: [String] {
        Array(Set(snapshot.groups.map(\.category).filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func group(_ id: String) -> LumaConfusableGroup? { snapshot.groups.first { $0.id == id } }

    func upsert(_ group: LumaConfusableGroup) -> String? {
        var next = snapshot
        var saved = group
        saved.updatedAt = Date()
        if let i = next.groups.firstIndex(where: { $0.id == group.id }) {
            next.groups[i] = saved
        } else {
            next.groups.append(saved)
        }
        return commit(next) ? nil : lastError
    }

    func add(_ groups: [LumaConfusableGroup]) -> String? {
        guard !groups.isEmpty else { return nil }
        var next = snapshot
        next.groups.append(contentsOf: groups)
        return commit(next) ? nil : lastError
    }

    func delete(_ id: String) -> String? {
        var next = snapshot
        next.groups.removeAll { $0.id == id }
        return commit(next) ? nil : lastError
    }

    func setCategory(_ category: String, for id: String) -> String? {
        var next = snapshot
        guard let i = next.groups.firstIndex(where: { $0.id == id }) else { return nil }
        next.groups[i].category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        next.groups[i].updatedAt = Date()
        return commit(next) ? nil : lastError
    }

    func resetStats(_ id: String) -> String? {
        var next = snapshot
        guard let i = next.groups.firstIndex(where: { $0.id == id }) else { return nil }
        next.groups[i].attempts = 0
        next.groups[i].misses = 0
        return commit(next) ? nil : lastError
    }

    /// 一个词（每题）最终结果：missed = 第一次没答对。
    func recordResult(groupID: String, missed: Bool) {
        var next = snapshot
        guard let i = next.groups.firstIndex(where: { $0.id == groupID }) else { return }
        next.groups[i].attempts += 1
        if missed { next.groups[i].misses += 1 }
        commit(next)
    }
}

// MARK: 文本解析（一行一组，用 , | ; 或制表符分隔；单词后面可直接写中文释义）

enum LumaConfusableParser {
    static func entry(fromToken raw: String) -> LumaConfusableEntry? {
        let chars = Array(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        var i = 0
        while i < chars.count, chars[i].isASCII, chars[i].isLetter || chars[i] == "-" || chars[i] == "'" {
            i += 1
        }
        let word = String(chars[0..<i])
        guard word.count >= 2 else { return nil }
        // "adj." / "n." 这类词性缩写不是单词
        if i < chars.count, chars[i] == "." { return nil }
        var rest = String(chars[i...]).trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = rest.first, "=:：-—".contains(first) {
            rest.removeFirst()
            rest = rest.trimmingCharacters(in: .whitespaces)
        }
        return LumaConfusableEntry(word: word, meaning: rest)
    }

    static func entries(fromLine line: String) -> [LumaConfusableEntry] {
        let separators = CharacterSet(charactersIn: "|,;；、\t")
        var seen = Set<String>()
        var result: [LumaConfusableEntry] = []
        for token in line.components(separatedBy: separators) {
            guard let entry = entry(fromToken: token), seen.insert(entry.word.lowercased()).inserted else { continue }
            result.append(entry)
        }
        return result
    }

    static func groups(from text: String, category: String) -> (groups: [LumaConfusableGroup], ignored: [String]) {
        var groups: [LumaConfusableGroup] = []
        var ignored: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let entries = entries(fromLine: trimmed)
            if entries.count >= 2 {
                groups.append(LumaConfusableGroup(category: category, entries: entries))
            } else {
                ignored.append(trimmed)
            }
        }
        return (groups, ignored)
    }
}

// MARK: 释义 / 音标补全（背词词库 → 听力词库 → 内置词典，仅用于查词）

@MainActor
enum LumaWordLookup {
    static func table() -> [String: VocabularyWord] {
        var map: [String: VocabularyWord] = [:]
        for w in LumaChoiceLibrary.shared.allReadingWords {
            let key = w.word.lowercased()
            if map[key] == nil, !w.definitionZH.isEmpty { map[key] = w }
        }
        return map
    }

    static func fill(_ entries: [LumaConfusableEntry]) -> [LumaConfusableEntry] {
        let known = table()
        return entries.map { entry in
            var e = entry
            let key = e.word.lowercased()
            if let w = known[key] {
                if e.meaning.isEmpty { e.meaning = w.definitionZH }
                if e.phonetic.isEmpty { e.phonetic = w.phoneticUK.isEmpty ? w.phoneticUS : w.phoneticUK }
                if e.meaning == w.definitionZH { e.readingWordID = w.id }
            }
            if e.meaning.isEmpty, let dict = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: e.word) {
                e.meaning = dict
            }
            return e
        }
    }
}

// MARK: 自动发现易混词（拼写只差一个字母 / 相邻字母颠倒 / 音标相同）

enum LumaConfusableSuggester {
    private static let inflectionSuffixes: Set<String> = ["s", "es", "d", "ed", "ing", "er", "ers", "r", "ly"]

    static func suggest(from source: [VocabularyWord], excluding existing: [LumaConfusableGroup], limit: Int = 200) -> [LumaConfusableGroup] {
        var byWord: [String: VocabularyWord] = [:]
        for w in source {
            let key = w.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard key.count >= 4, key.count <= 14, key.allSatisfy({ $0.isASCII && $0.isLetter }) else { continue }
            if byWord[key] == nil { byWord[key] = w }
        }
        var buckets: [String: Set<String>] = [:]
        for (key, w) in byWord {
            let chars = Array(key)
            buckets["s:" + key, default: []].insert(key)
            buckets["d:" + key, default: []].insert(key)
            for i in 0..<chars.count {
                var removed = chars
                removed.remove(at: i)
                buckets["d:" + String(removed), default: []].insert(key)
            }
            for i in 0..<(chars.count - 1) where chars[i] != chars[i + 1] {
                var swapped = chars
                swapped.swapAt(i, i + 1)
                buckets["s:" + String(swapped), default: []].insert(key)
            }
            let phonetic = (w.phoneticUS.isEmpty ? w.phoneticUK : w.phoneticUS)
                .filter { !"[]/ˈˌ ".contains($0) }
            if phonetic.count >= 3 { buckets["p:" + phonetic, default: []].insert(key) }
        }
        let existingKeys = Set(existing.map(\.wordKey))
        var seenSets = Set<Set<String>>()
        var ranked: [(priority: Int, words: [String])] = []
        for (bucketKey, members) in buckets where members.count >= 2 && members.count <= 5 {
            let kept = members.filter { word in
                !members.contains { other in
                    other != word && word.hasPrefix(other) && inflectionSuffixes.contains(String(word.dropFirst(other.count)))
                }
            }
            guard kept.count >= 2 else { continue }
            let set = Set(kept)
            guard !existingKeys.contains(set), seenSets.insert(set).inserted else { continue }
            let priority = bucketKey.hasPrefix("p:") ? 0 : (bucketKey.hasPrefix("s:") ? 1 : 2)
            ranked.append((priority, kept.sorted()))
        }
        ranked.sort { a, b in
            if a.priority != b.priority { return a.priority < b.priority }
            return a.words.joined(separator: " ") < b.words.joined(separator: " ")
        }
        return ranked.prefix(limit).map { item in
            let entries = item.words.map { key -> LumaConfusableEntry in
                let w = byWord[key]
                return LumaConfusableEntry(word: w?.word ?? key, meaning: w?.definitionZH ?? "",
                                           phonetic: (w?.phoneticUK.isEmpty == false ? w?.phoneticUK : w?.phoneticUS) ?? "",
                                           readingWordID: w?.id)
            }
            return LumaConfusableGroup(entries: entries)
        }
    }
}

// MARK: 练习条目 / 顺序 / 模式

struct LumaPracticeSibling: Identifiable, Equatable, Sendable {
    let id: String
    let word: String
    let meaning: String
}

struct LumaPracticeItem: Identifiable, Equatable, Sendable {
    let id: String
    let groupID: String
    let groupTitle: String
    let word: String
    let meaning: String
    let phonetic: String
    /// 易混词：同组的所有词（含自己）；听力单词为空。
    let siblings: [LumaPracticeSibling]
    /// 听力词库的单词才有。
    let deckID: String?
    var readingWordID: String? = nil
}

enum LumaPracticeOrder: String, CaseIterable, Identifiable {
    case sequential, groupShuffle, fullShuffle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sequential: return "顺序"
        case .groupShuffle: return "组内打乱"
        case .fullShuffle: return "全部打乱"
        }
    }
    var symbol: String {
        switch self {
        case .sequential: return "list.number"
        case .groupShuffle: return "rectangle.3.group"
        case .fullShuffle: return "shuffle"
        }
    }
    var next: LumaPracticeOrder {
        switch self {
        case .sequential: return .groupShuffle
        case .groupShuffle: return .fullShuffle
        case .fullShuffle: return .sequential
        }
    }
}

enum LumaPracticeMode: String, CaseIterable, Identifiable {
    case dictation, choice
    var id: String { rawValue }
    var title: String { self == .dictation ? "听写" : "听音选词" }
}

// MARK: 练习引擎

@MainActor
final class LumaPracticeEngine: ObservableObject {
    enum Phase: Equatable { case asking, wrong, correct }

    @Published private(set) var items: [LumaPracticeItem] = []
    @Published private(set) var index = 0
    @Published var input = ""
    @Published private(set) var phase: Phase = .asking
    @Published private(set) var finished = false
    @Published private(set) var rightCount = 0
    @Published private(set) var missed: [LumaPracticeItem] = []
    @Published private(set) var hintLetters = 0
    @Published private(set) var errorPulse = 0
    @Published private(set) var picked: String? = nil
    @Published private(set) var choiceOptions: [LumaPracticeSibling] = []

    /// (条目, 第一次是否答对, 输入内容, 用时秒)；每题只在第一次作答时回调一次。
    var onResolved: ((LumaPracticeItem, Bool, String, Double) -> Void)?

    private var currentMissed = false
    private var questionStart = Date()

    var current: LumaPracticeItem? { items.indices.contains(index) ? items[index] : nil }
    var total: Int { items.count }

    static func ordered(_ source: [LumaPracticeItem], order: LumaPracticeOrder) -> [LumaPracticeItem] {
        switch order {
        case .sequential:
            return source
        case .fullShuffle:
            return source.shuffled()
        case .groupShuffle:
            var groupOrder: [String] = []
            var buckets: [String: [LumaPracticeItem]] = [:]
            for item in source {
                if buckets[item.groupID] == nil { groupOrder.append(item.groupID) }
                buckets[item.groupID, default: []].append(item)
            }
            return groupOrder.shuffled().flatMap { (buckets[$0] ?? []).shuffled() }
        }
    }

    func start(_ source: [LumaPracticeItem], order: LumaPracticeOrder) {
        items = Self.ordered(source, order: order)
        index = 0
        rightCount = 0
        missed = []
        finished = items.isEmpty
        prepareQuestion()
    }

    private func prepareQuestion() {
        input = ""
        phase = .asking
        picked = nil
        currentMissed = false
        hintLetters = 0
        questionStart = Date()
        choiceOptions = current?.siblings.shuffled() ?? []
    }

    private func markMissed(_ item: LumaPracticeItem, typed: String) {
        currentMissed = true
        if !missed.contains(where: { $0.id == item.id }) { missed.append(item) }
        errorPulse += 1
        phase = .wrong
        onResolved?(item, false, typed, Date().timeIntervalSince(questionStart))
    }

    func submitDictation() {
        guard let item = current, phase != .correct else { return }
        let typed = input
        guard !DictationAnswerPolicy.normalized(typed).isEmpty else { return }
        let match = DictationAnswerPolicy.matches(typed, targetWord: item.word)
        if phase == .asking {
            if match {
                rightCount += 1
                phase = .correct
                onResolved?(item, true, typed, Date().timeIntervalSince(questionStart))
            } else {
                input = ""
                markMissed(item, typed: typed)
            }
        } else if match {
            phase = .correct
        } else {
            input = ""
            errorPulse += 1
        }
    }

    func choose(_ siblingID: String) {
        guard let item = current, phase == .asking else { return }
        picked = siblingID
        if siblingID == item.id {
            rightCount += 1
            phase = .correct
            onResolved?(item, true, item.word, Date().timeIntervalSince(questionStart))
        } else {
            let typed = choiceOptions.first { $0.id == siblingID }?.word ?? ""
            markMissed(item, typed: typed)
        }
    }

    func reveal() {
        guard let item = current, phase == .asking else { return }
        markMissed(item, typed: "")
    }

    func showHint() {
        guard let item = current, phase == .asking else { return }
        hintLetters = min(hintLetters + 1, item.word.count)
    }

    func advance() {
        guard phase != .asking, !finished else { return }
        if index + 1 >= items.count {
            finished = true
        } else {
            index += 1
            prepareQuestion()
        }
    }
}

// MARK: 出题来源

@MainActor
enum LumaPracticeSources {
    static let wrongDeckID = "__wrong__"

    static func items(for group: LumaConfusableGroup) -> [LumaPracticeItem] {
        let library = LumaChoiceLibrary.shared
        let entries = group.entries.map { saved in
            guard let id = saved.readingWordID, let current = library.readingWord(id: id) else { return saved }
            return LumaConfusableEntry(id: saved.id, word: current.word, meaning: current.definitionZH,
                                       phonetic: current.phoneticUK.isEmpty ? current.phoneticUS : current.phoneticUK,
                                       readingWordID: id)
        }
        let siblings = entries.map { LumaPracticeSibling(id: $0.id, word: $0.word, meaning: $0.meaning) }
        return entries.map {
            LumaPracticeItem(id: $0.id, groupID: group.id, groupTitle: group.displayTitle, word: $0.word,
                             meaning: $0.meaning, phonetic: $0.phonetic, siblings: siblings, deckID: nil,
                             readingWordID: $0.readingWordID)
        }
    }

    /// scope: "all" | "hard" | "cat:分类名" | 词组 id
    static func confusableItems(scope: String, library: LumaConfusableLibrary) -> [LumaPracticeItem] {
        var groups = library.groups
        if scope == "hard" {
            groups = groups.filter { $0.misses > 0 }.sorted { $0.missRate > $1.missRate }
        } else if scope.hasPrefix("cat:") {
            let category = String(scope.dropFirst(4))
            groups = groups.filter { $0.category == category }
        } else if scope != "all" {
            groups = groups.filter { $0.id == scope }
        }
        return groups.flatMap { items(for: $0) }
    }

    static func scopeTitle(_ scope: String, library: LumaConfusableLibrary) -> String {
        if scope == "all" { return "全部易混词" }
        if scope == "hard" { return "仅易错" }
        if scope.hasPrefix("cat:") { return String(scope.dropFirst(4)) }
        return library.group(scope)?.displayTitle ?? "全部易混词"
    }

    static func listeningDecks() -> [LumaChoiceQuizDeck] {
        let model = LumaStudySession.shared.model
        var decks = model.fastVisibleBaseDecks.map { LumaChoiceQuizDeck(id: $0, title: model.fastDeckTitles[$0] ?? $0) }
        decks.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        decks.append(LumaChoiceQuizDeck(id: wrongDeckID, title: "全部错词"))
        return decks
    }

    static func listeningTitle(_ deckID: String) -> String {
        listeningDecks().first { $0.id == deckID }?.title ?? "听力词库"
    }

    /// limit: 0 = 全部。顺序模式从上次的位置继续；打乱模式随机抽取。
    static func listeningItems(deckID: String, order: LumaPracticeOrder, limit: Int) -> [LumaPracticeItem] {
        let model = LumaStudySession.shared.model
        var pool: [VocabularyWord]
        if deckID == wrongDeckID {
            let wrongIDs = Set(model.storeSnapshot.dictationLogs.filter { !$0.isCorrect }.map(\.wordID))
            pool = model.fastAllWords.filter { wrongIDs.contains($0.id) }
        } else {
            pool = model.fastWordsByDeck[deckID] ?? []
        }
        if limit > 0 && pool.count > limit {
            if order == .sequential {
                let key = "luma.mini.listeningCursor." + deckID
                var cursor = UserDefaults.standard.integer(forKey: key)
                if cursor >= pool.count { cursor = 0 }
                let slice = Array(pool[cursor..<min(pool.count, cursor + limit)])
                UserDefaults.standard.set(cursor + slice.count, forKey: key)
                pool = slice
            } else {
                pool = Array(pool.shuffled().prefix(limit))
            }
        }
        let title = listeningTitle(deckID)
        return pool.map { w in
            LumaPracticeItem(id: w.id, groupID: w.deckID, groupTitle: title, word: w.word, meaning: w.definitionZH,
                             phonetic: w.phoneticUK.isEmpty ? w.phoneticUS : w.phoneticUK, siblings: [], deckID: w.deckID)
        }
    }

    private static let miniSessionID = UUID()

    /// 引擎的统一结果出口：易混词记统计；听力单词按普通听写记录写回错词本（可在小窗设置里关闭）。
    static func resolve(item: LumaPracticeItem, correct: Bool, typed: String, seconds: Double) {
        if item.deckID == nil {
            LumaConfusableLibrary.shared.recordResult(groupID: item.groupID, missed: !correct)
            if !correct {
                let library = LumaChoiceLibrary.shared
                if let match = item.readingWordID.flatMap({ library.readingWord(id: $0) }) ??
                    library.allReadingWords.first(where: {
                        $0.word.caseInsensitiveCompare(item.word) == .orderedSame && $0.definitionZH == item.meaning
                    }) {
                    library.recordReadingMiss(match.id)
                }
            }
            return
        }
        let record = UserDefaults.standard.object(forKey: "luma.mini.recordToWrongBook") as? Bool ?? true
        guard record, let deckID = item.deckID else { return }
        let model = LumaStudySession.shared.model
        let log = DictationAttemptLog(
            id: UUID(), sessionID: miniSessionID, mode: .newTask, wordID: item.id, word: item.word,
            deckID: deckID, userTyped: typed, isCorrect: correct, isFirstAttemptInSession: true,
            sessionErrorCountForWord: correct ? 0 : 1, timestamp: Date(),
            dateString: LumaStudyCenterHostView.todayDateString(), durationSeconds: seconds)
        model.storeSnapshot.dictationLogs.append(log)
        model.scheduleSave(after: 1.0)
    }
}

// MARK: 练习发音

enum LumaMiniVoice: String, CaseIterable {
    case followStudy, kitten, apple
    static let preferenceKey = "luma.mini.voice"

    var title: String {
        switch self {
        case .followStudy: "跟随学习设置"
        case .kitten: "Kitten 本地神经语音"
        case .apple: "Apple 系统语音"
        }
    }

    func usesKitten(studyUsesApple: Bool) -> Bool {
        switch self {
        case .followStudy: !studyUsesApple
        case .kitten: true
        case .apple: false
        }
    }
}

@MainActor
final class LumaPracticeSpeaker: ObservableObject {
    static let shared = LumaPracticeSpeaker()
    static let mini = LumaPracticeSpeaker(isMiniPanel: true)

    private let isMiniPanel: Bool
    private let miniAppleSpeech = MacOSSpeechSynthesisManager()
    private var miniRate: Float = 1
    @Published private(set) var fellBackToApple = false

    private init(isMiniPanel: Bool = false) {
        self.isMiniPanel = isMiniPanel
    }

    func speak(_ text: String, slow: Bool = false) {
        let model = LumaStudySession.shared.model
        let baseRate = model.speechRateMultiplier
        let rate: Float = slow ? min(baseRate, 1.0) * 0.75 : baseRate
        let kokoro = KokoroNeuralBridge.shared
        if isMiniPanel {
            guard !kokoro.isDisplaySuspended else { return }
            miniRate = rate
            fellBackToApple = false
            let raw = UserDefaults.standard.string(forKey: LumaMiniVoice.preferenceKey) ?? ""
            let voice = LumaMiniVoice(rawValue: raw) ?? .followStudy
            if voice.usesKitten(studyUsesApple: kokoro.useAppleSystemSpeech) {
                miniAppleSpeech.stop()
                if kokoro.play(text: text, speed: rate, fromMiniPanel: true, onFailure: { [weak self] in
                    guard let self, !kokoro.isDisplaySuspended else { return }
                    self.fellBackToApple = true
                    self.playApple(text, rate: self.miniRate)
                }) { return }
                fellBackToApple = true
            }
            kokoro.stopMiniPlayback()
            playApple(text, rate: rate)
            return
        }

        if !kokoro.useAppleSystemSpeech && kokoro.isReady {
            model.speech.stop()
            if kokoro.play(text: text, speed: rate, repeats: 1, interval: 0.5) { return }
        }
        kokoro.stop()
        playApple(text, rate: rate)
    }

    private func playApple(_ text: String, rate: Float) {
        let model = LumaStudySession.shared.model
        let engine = isMiniPanel ? miniAppleSpeech : model.speech
        let voices = engine.availableVoices(for: model.selectedAccent)
        let selected = voices.first { $0.id == model.storeSnapshot.selectedVoiceIdentifier }
        let voice = selected ?? engine.selectBestFemaleVoice(
            preferredVoiceID: model.storeSnapshot.selectedVoiceIdentifier, accent: model.selectedAccent)
        engine.repeatCount = 1
        engine.speak(text: text, voice: voice, requestedRate: rate)
    }

    func stop() {
        if isMiniPanel {
            fellBackToApple = false
            miniAppleSpeech.stop()
            KokoroNeuralBridge.shared.stopMiniPlayback()
        } else {
            LumaStudySession.shared.model.speech.stop()
            KokoroNeuralBridge.shared.stop()
        }
    }
}
