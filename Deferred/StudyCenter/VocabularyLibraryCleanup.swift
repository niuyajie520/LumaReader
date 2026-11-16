import Foundation

/// 词库一次性清理。
///
/// 同一份词本被重复导入时，同一批词会以两套平行 deck 并存（`luma.c20.*` 与
/// `c20.corpus.*`、`luma.p*` 与 `ielts.*`），听写时会听到同一个词两遍；另外
/// 少数条目是英式拼写，与美式拼写并存。清理在首次启动时执行一次，并把标记写进
/// `installedVocabularyPackIDs`，所以重复启动不会反复搬运词库。
public enum VocabularyLibraryCleanup {
    /// 幂等标记；沿用 `installedVocabularyPackIDs` 里既有的做法（"replaced.listening.*"）。
    public static let marker = "vocabulary-dedupe-20261115"

    /// 同一份内容重复导入后留下的第二份拷贝，直接丢弃。
    public static let redundantDeckPrefixes: [String] = ["luma.c20.", "luma.p"]

    /// 词库里残留的英式拼写 → 美式拼写（统一按美式保存）。
    public static let americanSpellingByBritish: [String: String] = [
        "catalogue": "catalog",
        "cheque": "check",
        "civilisation": "civilization",
        "favourable": "favorable",
        "favourite": "favorite",
        "flavour": "flavor",
        "labour": "labor",
        "litre": "liter",
        "mould": "mold",
        "moustache": "mustache",
        "odour": "odor",
        "organisation": "organization",
        "organiser": "organizer",
        "chequebook": "checkbook",
        "traveller": "traveler",
    ]

    /// 合并英美拼写后只剩「英式写法／美式写法」这类占位释义的条目，补上真正的释义。
    static let definitionPatches: [String: String] = [
        "check": "支票；检查",
    ]

    /// 同一个词本家族（同一本书或同一套场景词）内的重复视为多余词条；
    /// 不同家族之间即使同形也各自保留，因为那是不同单元的学习内容。
    public static func family(of deckID: String) -> String {
        if deckID.hasPrefix("c20.corpus.") { return "c20" }
        if deckID.hasPrefix("ielts.") { return "ielts" }
        return deckID
    }

    /// 判重键：忽略大小写、连字符与下划线差异（`double-grill` == `double grill`）。
    public static func normalizedKey(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
    }

    /// 把英式拼写改写成美式拼写；多词条目只替换整词匹配的部分。
    public static func americanized(_ text: String) -> String {
        if let direct = lookup(text.lowercased()) { return direct }
        let tokens = text.split(separator: " ", omittingEmptySubsequences: false)
        var changed = false
        let mapped = tokens.map { token -> String in
            guard let american = lookup(token.lowercased()) else { return String(token) }
            changed = true
            return american
        }
        return changed ? mapped.joined(separator: " ") : text
    }

    /// 复数、所有格（`favourites`、`traveller's`）也要跟着换，否则词库里会残留英式写法。
    static func lookup(_ lowercased: String) -> String? {
        if let direct = americanSpellingByBritish[lowercased] { return direct }
        if lowercased.hasSuffix("'s"), let base = americanSpellingByBritish[String(lowercased.dropLast(2))] {
            return base + "'s"
        }
        if lowercased.hasSuffix("s"), let base = americanSpellingByBritish[String(lowercased.dropLast())] {
            return base + "s"
        }
        return nil
    }

    public static func isRedundantDeck(_ deckID: String) -> Bool {
        redundantDeckPrefixes.contains { deckID.hasPrefix($0) }
    }

    public struct CleanupOutcome: Equatable, Sendable {
        public var words: [VocabularyWord]
        /// 本次被删掉的词条 ID（重复词本、重复词条、被同单元短语覆盖的单词）。
        public var removedWordIDs: Set<String>
    }

    /// 去重 + 拼写统一。保留第一次出现的词条（导入顺序即词本顺序），
    /// 但同一判重键里若有释义更完整的条目，则用更完整的那条替换。
    ///
    /// 最后再执行一次「短语覆盖单词」：同一单元里已经用整条短语考同一个意思时
    /// （`red apple` 已收时不再单列 `apple`），单词条目就是多余的练习量。
    public static func cleaned(_ words: [VocabularyWord]) -> CleanupOutcome {
        var indexByKey: [String: Int] = [:]
        var result: [VocabularyWord] = []
        var removed: Set<String> = []
        result.reserveCapacity(words.count)

        for word in words {
            guard !isRedundantDeck(word.deckID) else {
                removed.insert(word.id)
                continue
            }
            let text = americanized(word.word)
            let key = family(of: word.deckID) + "|" + normalizedKey(text)
            let candidate = rebuilt(word, word: text)
            if let existing = indexByKey[key] {
                if hasNoMeaning(result[existing]), !hasNoMeaning(candidate) {
                    removed.insert(result[existing].id)
                    result[existing] = candidate
                } else {
                    removed.insert(candidate.id)
                }
                continue
            }
            indexByKey[key] = result.count
            result.append(candidate)
        }

        let survivors = droppingWordsCoveredByPhrases(result)
        let kept = Set(survivors.map(\.id))
        removed.formUnion(result.map(\.id).filter { !kept.contains($0) })
        return CleanupOutcome(words: survivors, removedWordIDs: removed)
    }

    /// 同一 deck 内，短语已经把某个单词完整练到时，单词条目就是多余的：
    /// `kangaroo` 与 `red kangaroo` 同单元时只留短语。
    ///
    /// 只认「短语中心词就是它」（单词是短语的最后一个词）、短语不超过三个词、
    /// 且短语释义里确实包含单词释义，避免 `bus`/`rent` 这类核心词被 `bus stop`、
    /// `rent a flat` 顺手删掉。
    static func droppingWordsCoveredByPhrases(_ words: [VocabularyWord]) -> [VocabularyWord] {
        var wordsByDeck: [String: [VocabularyWord]] = [:]
        for word in words { wordsByDeck[word.deckID, default: []].append(word) }

        return words.filter { word in
            let tokens = normalizedKey(word.word).split(separator: " ").map(String.init)
            guard tokens.count == 1, let token = tokens.first else { return true }
            let meanings = definitionSegments(word.definitionZH)
            guard !meanings.isEmpty else { return true }
            let covered = wordsByDeck[word.deckID]?.contains { other in
                guard other.id != word.id else { return false }
                let otherTokens = normalizedKey(other.word).split(separator: " ").map(String.init)
                guard otherTokens.count >= 2, otherTokens.count <= 3, otherTokens.last == token else { return false }
                return meanings.contains { other.definitionZH.contains($0) }
            } ?? false
            return !covered
        }
    }

    static func definitionSegments(_ definition: String) -> [String] {
        definition
            .split(whereSeparator: { "；;，,、/（）()【】[]：:".contains($0) || $0 == " " || $0 == "\t" })
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    static func hasNoMeaning(_ word: VocabularyWord) -> Bool {
        let trimmed = word.definitionZH.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "英式写法" || trimmed == "美式写法"
    }

    static func rebuilt(_ word: VocabularyWord, word text: String) -> VocabularyWord {
        var definition = word.definitionZH
        if hasNoMeaning(word), let patch = definitionPatches[normalizedKey(text)] {
            definition = patch
        }
        guard text != word.word || definition != word.definitionZH else { return word }
        return VocabularyWord(
            id: word.id,
            word: text,
            phoneticUK: word.phoneticUK,
            phoneticUS: word.phoneticUS,
            partOfSpeech: word.partOfSpeech,
            definitionZH: definition,
            exampleSentence: word.exampleSentence,
            deckID: word.deckID,
            deckTitle: word.deckTitle,
            folderPath: word.folderPath
        )
    }

    /// 删掉重复词本后，把还指向已消失 deck 的导航状态收回到当前词库，
    /// 并清掉被删词条留下的零散记录，避免错词本出现空词条。
    public static func repairReferences(in snapshot: inout StudyStoreSnapshot, removedWordIDs: Set<String> = []) {
        if !removedWordIDs.isEmpty {
            snapshot.dictationLogs.removeAll { removedWordIDs.contains($0.wordID) }
            snapshot.stubbornWords.removeAll { removedWordIDs.contains($0.wordID) }
            snapshot.slowReactionWords?.removeAll { removedWordIDs.contains($0.wordID) }
            if let schedule = snapshot.reviewSchedule {
                snapshot.reviewSchedule = schedule.filter { !removedWordIDs.contains($0.key) }
            }
        }
        let deckIDs = Set((snapshot.importedWords ?? []).map(\.deckID))
        if var workspace = snapshot.workspace,
           let selected = workspace.selectedDeckID,
           !selected.isEmpty,
           !deckIDs.contains(selected) {
            workspace.selectedDeckID = deckIDs.contains(BundledCoraVocabulary.defaultDeckOrder.first ?? "")
                ? BundledCoraVocabulary.defaultDeckOrder.first
                : deckIDs.sorted().first
            snapshot.workspace = workspace
        }
        if let session = snapshot.dictationSession, !deckIDs.contains(session.currentWord?.deckID ?? "") {
            snapshot.dictationSession = nil
        }
    }
}
