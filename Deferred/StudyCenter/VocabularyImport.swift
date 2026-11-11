import Foundation
import CoreFoundation
import CryptoKit

public struct VocabularyImportRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let lineNumber: Int
    public let rawLine: String
    public var word: String
    public var meaning: String
    public var builtInMeaning: String
    public var dictionaryMeaning: String?
    public var isUsingDictionaryMeaning: Bool
    public var included: Bool
    public var needsConfirmation: Bool
    public var parseNote: String?

    public init(
        id: UUID = UUID(),
        lineNumber: Int = 1,
        rawLine: String = "",
        word: String,
        meaning: String,
        builtInMeaning: String? = nil,
        dictionaryMeaning: String? = nil,
        isUsingDictionaryMeaning: Bool = false,
        included: Bool = true,
        needsConfirmation: Bool = false,
        parseNote: String? = nil
    ) {
        self.id = id
        self.lineNumber = lineNumber
        self.rawLine = rawLine
        self.word = word
        self.meaning = meaning
        self.builtInMeaning = builtInMeaning ?? meaning
        self.dictionaryMeaning = dictionaryMeaning ?? BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: word)
        self.isUsingDictionaryMeaning = isUsingDictionaryMeaning
        self.included = included
        self.needsConfirmation = needsConfirmation
        self.parseNote = parseNote
    }

    public var issue: String? {
        guard included else { return nil }
        let cleanWord = DictationAnswerPolicy.normalized(word)
        if cleanWord.isEmpty || cleanWord == "\u{0}" || !VocabularyImport.isValidEnglishTerm(word) {
            return "待确认：英文词条格式需核对"
        }
        if meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || needsConfirmation {
            return "待补充释义"
        }
        return nil
    }
}

/// 导入计划：描述「确认导入」后真正会写入多少词、跳过了多少。预览与实际导入共用同一份结果，保证数字一致。
public enum BundledCoraVocabulary {
    public static let packID = "cora-scenario-books-20261109-v2"

    public static let defaultCategories: [String] = ["Part 1", "Part 2", "Part 3", "Part 4"]

    public static let defaultDeckOrder: [String] = [
        "ielts.p1.renting",
        "ielts.p1.work",
        "ielts.p1.travel",
        "ielts.p1.inquiry",
        "ielts.p2.map",
        "ielts.p2.travel",
        "ielts.p2.work",
        "ielts.p3.research",
        "ielts.p3.assignment",
        "ielts.p4.ecology",
        "ielts.p4.business",
        "ielts.p4.geography",
        "ielts.p4.society"
    ]

    public static let defaultCategoryByDeckID: [String: String] = [
        "ielts.p1.renting": "Part 1",
        "ielts.p1.work": "Part 1",
        "ielts.p1.travel": "Part 1",
        "ielts.p1.inquiry": "Part 1",
        "ielts.p2.map": "Part 2",
        "ielts.p2.travel": "Part 2",
        "ielts.p2.work": "Part 2",
        "ielts.p3.research": "Part 3",
        "ielts.p3.assignment": "Part 3",
        "ielts.p4.ecology": "Part 4",
        "ielts.p4.business": "Part 4",
        "ielts.p4.geography": "Part 4",
        "ielts.p4.society": "Part 4"
    ]

    public static let defaultTitleByDeckID: [String: String] = [
        "ielts.p1.renting": "租房场景",
        "ielts.p1.work": "工作场景",
        "ielts.p1.travel": "旅游活动场景",
        "ielts.p1.inquiry": "问询/咨询场景",
        "ielts.p2.map": "地图题方位词场景",
        "ielts.p2.travel": "旅游场景",
        "ielts.p2.work": "工作场景",
        "ielts.p3.research": "课题研究场景",
        "ielts.p3.assignment": "作业讨论场景",
        "ielts.p4.ecology": "生态环境场景",
        "ielts.p4.business": "商业场景",
        "ielts.p4.geography": "地理环境场景",
        "ielts.p4.society": "人文社会及其他场景"
    ]

    struct Book: Decodable { let part: Int; let entries: [Entry] }
    public static let defaultSubfoldersByDeckID: [String: [String]] = [
        "ielts.p1.renting": ["01_租房场景词汇", "02_租房机经词汇"],
        "ielts.p1.work": ["01_工作场景词汇", "02_工作机经词汇"],
        "ielts.p1.travel": ["01_旅游活动场景词汇", "02_旅游活动机经词汇"],
        "ielts.p1.inquiry": ["01_咨询问询场景词汇", "02_询问问询机经词汇"],
        "ielts.p2.map": ["01_地图题方位核心词", "02_选择题重点词汇"],
        "ielts.p2.travel": ["01_旅游场景机经词汇", "02_配对题旅游重点词汇"],
        "ielts.p2.work": ["01_工作场景机经词汇", "02_配对题工作及翻新重点词", "03_五选二重点词汇"],
        "ielts.p3.research": ["01_课题研究机经词汇", "02_课题研究重点词汇"],
        "ielts.p3.assignment": ["01_作业讨论机经词汇", "02_作业讨论重点词汇"],
        "ielts.p4.ecology": ["01_生态环境机经词汇", "02_生态环境重点词汇"],
        "ielts.p4.business": ["01_商业场景机经词汇", "02_商业环境重点词汇"],
        "ielts.p4.geography": ["01_地理环境机经词汇", "02_地理环境重点词汇"],
        "ielts.p4.society": ["01_人文社会及其他机经词汇", "02_人文社会重点词汇"]
    ]

    struct Entry: Decodable {
        let sourceLine: Int
        let originalWord: String
        let word: String
        let meaning: String
        let scenarioID: String?
        let scenarioTitle: String?
        let category: String?
        let subfolder: String?
    }
    enum ResourceError: LocalizedError {
        case missing, invalid
        var errorDescription: String? { "雅思听力场景词本资源缺失或格式不完整" }
    }

    private static func isLegacyMonolithicCoraDeck(_ w: VocabularyWord) -> Bool {
        if w.deckID.hasPrefix("cora.bundled.part") { return true }
        let compact = w.deckTitle.lowercased().filter { $0.isLetter || $0.isNumber }
        return compact.hasPrefix("coraieltspart") || compact.hasPrefix("corapart")
    }

    private final class BundleToken: NSObject {}

    private static func locateBooksJSONURL() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        let roots: [URL] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
            Bundle(for: BundleToken.self).resourceURL,
            Bundle(for: BundleToken.self).bundleURL,
            Bundle(for: BundleToken.self).bundleURL.deletingLastPathComponent(),
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        ].compactMap { $0 }

        for r in roots {
            candidates.append(r.appendingPathComponent("CoraVocabulary/books.json"))
            candidates.append(r.appendingPathComponent("books.json"))
            for bundleName in ["StudyCenter_LumaReaderStudyKit.bundle", "LumaReader_LumaReaderStudyKit.bundle"] {
                let bURL = r.appendingPathComponent(bundleName)
                candidates.append(bURL.appendingPathComponent("CoraVocabulary/books.json"))
                candidates.append(bURL.appendingPathComponent("Contents/Resources/CoraVocabulary/books.json"))
                if let b = Bundle(url: bURL),
                   let found = b.url(forResource: "books", withExtension: "json", subdirectory: "CoraVocabulary") {
                    return found
                }
            }
        }
        // Source-tree relative fallback (works during local swift test / debug runs)
        let sourceRel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/CoraVocabulary/books.json")
        candidates.append(sourceRel)

        for c in candidates where fm.fileExists(atPath: c.path) {
            return c
        }
        return nil
    }

    public static func addingTo(_ snapshot: StudyStoreSnapshot) throws -> StudyStoreSnapshot {
        guard !(snapshot.installedVocabularyPackIDs ?? []).contains(packID) else { return snapshot }
        guard let url = locateBooksJSONURL() else { throw ResourceError.missing }
        let books = try JSONDecoder().decode([Book].self, from: Data(contentsOf: url)).sorted { $0.part < $1.part }
        guard books.map(\.part) == [1, 2, 3, 4], books.allSatisfy({ !$0.entries.isEmpty }) else { throw ResourceError.invalid }
        var result = snapshot
        // Retain user's personal decks (e.g. Charlie_必听错词) while replacing un-split Cora Part 1-4 monolithic decks
        var words = (snapshot.importedWords ?? []).filter { !isLegacyMonolithicCoraDeck($0) }
        let existingScenarioWords = Set(words.filter { defaultDeckOrder.contains($0.deckID) }.map { "\($0.deckID)|\(normalizedWordKey($0.word))" })
        var usedIDs = Set(words.map(\.id))
        var globalSeenWords = Set<String>()

        for book in books {
            for entry in book.entries {
                let normalized = DictationAnswerPolicy.normalized(entry.word)
                guard !normalized.isEmpty, normalized != "\u{0000}", !entry.meaning.isEmpty else { throw ResourceError.invalid }
                // Strict cross-Part & cross-scenario deduplication: if a word appeared in Part 1, skip it in Part 2/3/4
                let wordKey = normalizedWordKey(entry.word)
                guard globalSeenWords.insert(wordKey).inserted else { continue }

                let deckID = entry.scenarioID ?? "ielts.p\(book.part).general"
                if existingScenarioWords.contains("\(deckID)|\(wordKey)") { continue }
                let title = entry.scenarioTitle ?? defaultTitleByDeckID[deckID] ?? "Part \(book.part) 场景词"
                let baseID = "\(deckID)." + VocabularyImport.hex(Data(pairKey(entry.word, entry.meaning).utf8))
                var id = baseID
                var suffix = 1
                while usedIDs.contains(id) { id = "\(baseID).\(suffix)"; suffix += 1 }
                usedIDs.insert(id)
                let sub = entry.subfolder ?? defaultSubfoldersByDeckID[deckID]?.first
                words.append(VocabularyWord(id: id, word: entry.word, definitionZH: entry.meaning, exampleSentence: sub ?? "", deckID: deckID, deckTitle: title))
            }
        }
        result.importedWords = words
        var packs = (snapshot.installedVocabularyPackIDs ?? []).filter { $0 != "cora-user-books-20261109-v1" && $0 != packID }
        packs.append(packID)
        result.installedVocabularyPackIDs = packs
        return result
    }

    private static func normalizedWordKey(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    private static func pairKey(_ word: String, _ meaning: String) -> String {
        normalizedWordKey(word) + "\u{001F}" + meaning.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum VocabularyImportRowDuplicateKind: Equatable, Sendable {
    /// 英文和释义都与前面某一行（或词库里已有词条）完全相同
    case exactDuplicate
    /// 英文相同、释义不同
    case sameWordOtherMeaning
}

public struct VocabularyImportPlan: Equatable, Sendable {
    public var words: [VocabularyWord] = []
    /// 单词与释义都完全相同、但被用户勾选加入的条数（不会再自动跳过）
    public var exactDuplicates: Int = 0
    /// 同一单词、释义不同，各自作为独立词条加入的条数
    public var keptAsSeparate: Int = 0
    /// 同一单词、释义不同而被「合并进同一词条」的条数
    public var mergedIntoOne: Int = 0
    public init() {}
}

public struct VocabularyImportDraft: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let filename: String
    public var deckTitle: String
    public var rows: [VocabularyImportRow]
    public var ignoredNonVocabularyLines: [String] = []
    /// 默认状态：`false`（严格优先使用文件自带的中文翻译，绝不擅自用词典覆盖）
    public var useBuiltInDictionaryMode: Bool = false
    /// 默认 `false`：同一单词出现多个不同释义时，全部保留为独立词条；
    /// 设为 `true`：同一单词的不同释义合并成一条（用「；」连接）。由用户在预览里自己决定。
    public var mergeSameWordMeanings: Bool = false

    public var deckID: String {
        VocabularyImport.deckIdentifier(for: filename)
    }

    public var recognizedEnglishCount: Int {
        rows.filter { VocabularyImport.isValidEnglishTerm($0.word) }.count
    }

    public var pairedMeaningCount: Int {
        rows.filter {
            VocabularyImport.isValidEnglishTerm($0.word) &&
            !$0.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.needsConfirmation
        }.count
    }

    public var unmatchedOrAmbiguousCount: Int {
        rows.filter { $0.included && ($0.needsConfirmation || $0.issue != nil) }.count
    }

    public var dictionaryMatchedCount: Int {
        rows.filter { ($0.dictionaryMeaning ?? "").isEmpty == false }.count
    }

    public var pureEnglishDictionaryFillableCount: Int {
        rows.filter {
            $0.builtInMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            ($0.dictionaryMeaning ?? "").isEmpty == false
        }.count
    }

    /// 切换「文件自带中文（默认）」与「仅对缺失中文的纯英文词条使用词典补全」
    public mutating func applyTranslationSource(useDictionary: Bool, overwriteBuiltIn: Bool = false) {
        useBuiltInDictionaryMode = useDictionary
        for idx in rows.indices {
            let latestDict = rows[idx].dictionaryMeaning ?? BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: rows[idx].word)
            rows[idx].dictionaryMeaning = latestDict
            if !useDictionary {
                rows[idx].meaning = rows[idx].builtInMeaning
                rows[idx].isUsingDictionaryMeaning = false
                if rows[idx].builtInMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rows[idx].needsConfirmation = true
                }
            } else if overwriteBuiltIn {
                if let dictZH = latestDict, !dictZH.isEmpty {
                    rows[idx].meaning = dictZH
                    rows[idx].isUsingDictionaryMeaning = true
                    rows[idx].needsConfirmation = false
                }
            } else {
                // 仅当原文件实在没有中文释义时，才使用词典补全；有自带中文的一律保留文件原意
                if rows[idx].builtInMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let dictZH = latestDict, !dictZH.isEmpty {
                    rows[idx].meaning = dictZH
                    rows[idx].isUsingDictionaryMeaning = true
                    rows[idx].needsConfirmation = false
                } else {
                    rows[idx].meaning = rows[idx].builtInMeaning
                    rows[idx].isUsingDictionaryMeaning = false
                }
            }
        }
    }

    public init(data: Data, filename: String, useDictionaryTranslationByDefault: Bool = false) throws {
        guard data.count <= 2 * 1024 * 1024, !data.isEmpty, !Self.looksLikeUnsupportedBinary(data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let text = Self.decodeText(data) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        self.filename = filename
        let baseTitle = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        self.deckTitle = baseTitle.isEmpty ? "导入词库" : baseTitle

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let lowerName = filename.lowercased()
        if lowerName.hasSuffix(".json") || trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            self.rows = try Self.parseJSON(data)
        } else if lowerName.hasSuffix(".tsv") {
            let parsed = Self.parseTSVLines(text)
            self.rows = parsed
        } else {
            let parsed = Self.parseSmartBilingualLines(text)
            self.rows = parsed.rows
            self.ignoredNonVocabularyLines = parsed.ignoredLines
        }

        guard !rows.isEmpty, rows.count <= 20000 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        if useDictionaryTranslationByDefault {
            applyTranslationSource(useDictionary: true, overwriteBuiltIn: false)
        }
    }

    public mutating func confirmRow(id: UUID) {
        if let index = rows.firstIndex(where: { $0.id == id }) {
            let w = rows[index].word.trimmingCharacters(in: .whitespacesAndNewlines)
            let m = rows[index].meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            if VocabularyImport.isValidEnglishTerm(w) && !m.isEmpty {
                rows[index].needsConfirmation = false
            }
        }
    }

    public mutating func removeRow(id: UUID) {
        rows.removeAll { $0.id == id }
    }

    /// 把被自动忽略的某一行，按用户的决定手动加入导入列表（加入后仍可在列表里改英文/释义，或取消勾选）。
    public mutating func restoreIgnoredLine(at index: Int) {
        guard ignoredNonVocabularyLines.indices.contains(index) else { return }
        let raw = ignoredNonVocabularyLines.remove(at: index)
        rows.append(Self.rowFromIgnoredLine(raw, lineNumber: rows.count + 1))
    }

    /// 把全部被忽略的行一次性加入导入列表。
    public mutating func restoreAllIgnoredLines() {
        let lines = ignoredNonVocabularyLines
        ignoredNonVocabularyLines = []
        for raw in lines {
            rows.append(Self.rowFromIgnoredLine(raw, lineNumber: rows.count + 1))
        }
    }

    private static func rowFromIgnoredLine(_ raw: String, lineNumber: Int) -> VocabularyImportRow {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var english = line
        var chinese = ""
        let separators = ["----", "---", "--", "\t", " — ", " - ", "｜", "|", " : ", "：", ":"]
        var split = false
        for sep in separators {
            if let range = line.range(of: sep) {
                let left = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let right = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !left.isEmpty && !right.isEmpty {
                    let leftHasCJK = left.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar)
                    // 保证「英文在前、中文在后」；如果写反了就对调
                    english = leftHasCJK ? right : left
                    chinese = leftHasCJK ? left : right
                    split = true
                    break
                }
            }
        }
        if !split, let mixed = splitMixedEnglishAndChinese(line) {
            english = mixed.english
            chinese = mixed.chinese
        }
        let cleanedEnglish = cleanEnglishCandidate(english)
        let finalEnglish = cleanedEnglish.isEmpty ? english : cleanedEnglish
        let finalChinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        return VocabularyImportRow(
            lineNumber: lineNumber,
            rawLine: raw,
            word: finalEnglish,
            meaning: finalChinese,
            builtInMeaning: finalChinese,
            needsConfirmation: finalChinese.isEmpty,
            parseNote: "来自已忽略的行"
        )
    }

    private static func meaningKey(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).joined().lowercased()
    }

    // Invalid answer spellings share a sentinel; they must not share an import identity.
    private static func importWordKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    /// 每一行相对于「词库已有词条 + 文件里更靠前的行」的重复情况，仅用于在预览里标注，不会自动删除任何行。
    public func duplicateKinds(existing: [VocabularyWord]) -> [UUID: VocabularyImportRowDuplicateKind] {
        var kinds: [UUID: VocabularyImportRowDuplicateKind] = [:]
        var seenPairs = Set<String>()
        var seenWords = Set<String>()
        for word in existing where word.deckID == deckID {
            let wordKey = Self.importWordKey(word.word)
            guard !wordKey.isEmpty else { continue }
            seenPairs.insert(wordKey + "\u{1}" + Self.meaningKey(word.definitionZH))
            seenWords.insert(wordKey)
        }
        for row in rows {
            let wordKey = Self.importWordKey(row.word)
            guard !wordKey.isEmpty, row.word != "" else { continue }
            let pair = wordKey + "\u{1}" + Self.meaningKey(row.meaning)
            if seenPairs.contains(pair) {
                kinds[row.id] = .exactDuplicate
            } else if seenWords.contains(wordKey) {
                kinds[row.id] = .sameWordOtherMeaning
            }
            seenPairs.insert(pair)
            seenWords.insert(wordKey)
        }
        return kinds
    }

    /// 打开预览时的默认勾选：「完全重复」的行默认不勾选（仍然显示，由用户自己决定要不要加入）。其余都默认勾选。
    public mutating func applyDefaultSelection(existing: [VocabularyWord]) {
        let kinds = duplicateKinds(existing: existing)
        for index in rows.indices where kinds[rows[index].id] == .exactDuplicate {
            rows[index].included = false
        }
    }

    /// 计算这次导入的结果：**严格按用户勾选的行导入，不做任何自动去重**。
    /// 同词不同释义默认各自成条；用户打开「合并」后才合并成一条。
    public func importPlan(existing: [VocabularyWord]) -> VocabularyImportPlan {
        let targetDeckID = deckID
        let kinds = duplicateKinds(existing: existing)
        var plan = VocabularyImportPlan()
        var usedIDs = Set(existing.map(\.id))
        var indexByWordKey: [String: Int] = [:]
        var mergedMeaningKeys: [String: Set<String>] = [:]
        for row in rows where row.included && row.issue == nil {
            let clean = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let wordKey = Self.importWordKey(clean)
            guard !wordKey.isEmpty else { continue }
            let meaning = row.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaningKey = Self.meaningKey(meaning)
            if mergeSameWordMeanings, let index = indexByWordKey[wordKey] {
                var keys = mergedMeaningKeys[wordKey] ?? []
                if keys.insert(meaningKey).inserted {
                    let old = plan.words[index]
                    plan.words[index] = VocabularyWord(
                        id: old.id,
                        word: old.word,
                        definitionZH: old.definitionZH + "；" + meaning,
                        deckID: targetDeckID,
                        deckTitle: deckTitle
                    )
                }
                mergedMeaningKeys[wordKey] = keys
                plan.mergedIntoOne += 1
                continue
            }
            switch kinds[row.id] {
            case .exactDuplicate?: plan.exactDuplicates += 1
            case .sameWordOtherMeaning?: plan.keptAsSeparate += 1
            case nil: break
            }
            // 第一条沿用原 ID（学习进度不受影响）；其余用「~释义哈希」区分，保证每条 ID 唯一。
            let baseID = targetDeckID + "." + VocabularyImport.hex(Data(clean.lowercased().utf8))
            var wordID = baseID
            if usedIDs.contains(wordID) {
                let tagged = baseID + "~" + VocabularyImport.hex(Data(meaning.utf8))
                wordID = tagged
                var counter = 2
                while usedIDs.contains(wordID) {
                    wordID = tagged + "-\(counter)"
                    counter += 1
                }
            }
            usedIDs.insert(wordID)
            if indexByWordKey[wordKey] == nil {
                indexByWordKey[wordKey] = plan.words.count
                mergedMeaningKeys[wordKey] = [meaningKey]
            }
            plan.words.append(
                VocabularyWord(
                    id: wordID,
                    word: clean,
                    definitionZH: meaning,
                    deckID: targetDeckID,
                    deckTitle: deckTitle
                )
            )
        }
        return plan
    }

    public func confirmedWords(existing: [VocabularyWord]) throws -> [VocabularyWord] {
        let active = rows.filter(\.included)
        guard !active.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let bad = active.first(where: { $0.issue != nil }) {
            throw NSError(domain: "LumaStudy", code: 4, userInfo: [NSLocalizedDescriptionKey: "第 \(bad.lineNumber) 行：\(bad.issue!)"])
        }
        return importPlan(existing: existing).words
    }

    // MARK: - Encoding Detection (UTF-8, UTF-8 BOM, UTF-16LE/BE, GB18030/GBK)

    private static func looksLikeUnsupportedBinary(_ data: Data) -> Bool {
        if data.count >= 2 {
            let b0 = data[data.startIndex]
            let b1 = data[data.index(after: data.startIndex)]
            if (b0 == 0xFF && b1 == 0xFE) || (b0 == 0xFE && b1 == 0xFF) {
                if data.count >= 4 {
                    let b2 = data[data.index(data.startIndex, offsetBy: 2)]
                    let b3 = data[data.index(data.startIndex, offsetBy: 3)]
                    if b2 == 0x00 && b3 == 0x00 {
                        return true
                    }
                }
                return false
            }
        }
        if data.prefix(512).contains(0) {
            return true
        }
        return false
    }

    static func decodeText(_ data: Data) -> String? {
        if data.count >= 3,
           data[data.startIndex] == 0xEF,
           data[data.index(data.startIndex, offsetBy: 1)] == 0xBB,
           data[data.index(data.startIndex, offsetBy: 2)] == 0xBF {
            let sliced = data.dropFirst(3)
            if let s = String(data: Data(sliced), encoding: .utf8), !s.unicodeScalars.contains(where: { $0.value == 0 }) {
                return s.replacingOccurrences(of: "\u{FEFF}", with: "")
            }
        }
        if data.count >= 2 {
            let b0 = data[data.startIndex]
            let b1 = data[data.index(after: data.startIndex)]
            if b0 == 0xFF && b1 == 0xFE {
                if let s = String(data: data, encoding: .utf16LittleEndian), !s.unicodeScalars.contains(where: { $0.value == 0 }) {
                    return s.replacingOccurrences(of: "\u{FEFF}", with: "")
                }
                return nil
            }
            if b0 == 0xFE && b1 == 0xFF {
                if let s = String(data: data, encoding: .utf16BigEndian), !s.unicodeScalars.contains(where: { $0.value == 0 }) {
                    return s.replacingOccurrences(of: "\u{FEFF}", with: "")
                }
                return nil
            }
        }
        if let utf8 = String(data: data, encoding: .utf8), !utf8.unicodeScalars.contains(where: { $0.value == 0 }) {
            return utf8.replacingOccurrences(of: "\u{FEFF}", with: "")
        }
        let gbEncoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if let gb = String(data: data, encoding: gbEncoding), !gb.unicodeScalars.contains(where: { $0.value == 0 }) {
            return gb.replacingOccurrences(of: "\u{FEFF}", with: "")
        }
        return nil
    }

    // MARK: - JSON & Strict TSV Parsers

    private static func parseJSON(_ data: Data) throws -> [VocabularyImportRow] {
        struct Item: Decodable {
            let word: String?
            let english: String?
            let meaning: String?
            let definitionZH: String?
            let chinese: String?
        }
        if let words = try? JSONDecoder().decode([VocabularyWord].self, from: data) {
            return words.enumerated().map {
                VocabularyImportRow(lineNumber: $0.offset + 1, rawLine: $0.element.word, word: $0.element.word, meaning: $0.element.definitionZH)
            }
        }
        let items = try JSONDecoder().decode([Item].self, from: data)
        return items.enumerated().map { idx, item in
            let w = item.word ?? item.english ?? ""
            let m = item.definitionZH ?? item.meaning ?? item.chinese ?? ""
            return VocabularyImportRow(
                lineNumber: idx + 1,
                rawLine: "\(w)\t\(m)",
                word: w,
                meaning: m,
                needsConfirmation: !VocabularyImport.isValidEnglishTerm(w) || m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    private static func parseTSVLines(_ text: String) -> [VocabularyImportRow] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var rows: [VocabularyImportRow] = []
        for (idx, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let cols = rawLine.components(separatedBy: "\t")
            if rows.isEmpty && cols.count >= 2 && cols[0].trimmingCharacters(in: .whitespaces).lowercased() == "word" && cols[1].trimmingCharacters(in: .whitespaces).lowercased() == "meaning" {
                continue
            }
            if cols.count >= 2 {
                let w = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let m = cols.dropFirst().joined(separator: "；").trimmingCharacters(in: .whitespacesAndNewlines)
                let valid = VocabularyImport.isValidEnglishTerm(w) && !m.isEmpty
                rows.append(
                    VocabularyImportRow(
                        lineNumber: idx + 1,
                        rawLine: rawLine,
                        word: w,
                        meaning: m,
                        builtInMeaning: m,
                        needsConfirmation: !valid
                    )
                )
            } else {
                rows.append(
                    VocabularyImportRow(
                        lineNumber: idx + 1,
                        rawLine: rawLine,
                        word: trimmed,
                        meaning: "",
                        builtInMeaning: "",
                        needsConfirmation: true
                    )
                )
            }
        }
        return rows
    }

    // MARK: - High-Precision Smart Bilingual Parser & Cleaner

    private static let gluedSectionSuffixes: [String] = [
        "图书馆场景机经词汇", "银行场景机经词汇", "工作需带的资料", "工作必备技能", "工作信息来源",
        "接送人地点", "运动俱乐部", "图书馆场景", "要不要钱", "房屋内部", "家具电器", "工作职位",
        "工作福利", "工作内容", "清洁保洁", "志愿者的", "工作类型", "工资事项", "工作任务",
        "工作要求", "需要资料", "工作人员", "资料来源", "旅游时间", "交通方式", "提前预定",
        "旅游可玩", "旅游包含", "公园类型", "旅游住宿", "旅游保险", "旅游地点", "交通工具",
        "水上运动", "飞机相关", "保险场景", "诊所场景", "交通采访", "犯罪场景", "地址类",
        "音乐节", "自驾游"
    ]

    private static let ignoredCategoryPrompts: Set<String> = [
        "best time to contact",
        "general level of english",
        "special diet",
        "course enrolled in",
        "family preference",
        "in the __area of town",
        "rooms & facilities",
        "conference room facilities",
        "stoves burn",
        "view of hilltop",
        "read the book",
        "don't be late",
        "don’t be late",
        "don't wear jeans",
        "don’t wear jeans",
        "no，",
        "no,"
    ]

    private static let inanimatePluralFixes: [String: String] = [
        "商店们": "商店",
        "俱乐部们": "俱乐部",
        "餐馆们": "餐馆",
        "音乐会们": "音乐会",
        "宠物们": "宠物",
        "装饰们": "装饰品",
        "桌子们": "桌子",
        "椅子们": "椅子",
        "来年人": "老年人"
    ]

    private enum LineClassification {
        case bilingualPairs([(english: String, chinese: String)])
        case englishOnly(String)
        case chineseOnly(String)
        case ignoredNonVocabulary(String)
        case invalidLine(raw: String, englishCandidate: String, chineseCandidate: String)
    }

    private static func parseSmartBilingualLines(_ text: String) -> (rows: [VocabularyImportRow], ignoredLines: [String]) {
        let normalizedNewlines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalizedNewlines.components(separatedBy: "\n")

        var rows: [VocabularyImportRow] = []
        var ignored: [String] = []

        var index = 0
        while index < rawLines.count {
            let lineNum = index + 1
            let raw = rawLines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            if raw.isEmpty {
                index += 1
                continue
            }

            if rows.isEmpty && isHeaderRow(raw) {
                ignored.append(raw)
                index += 1
                continue
            }

            // Special multi-line broken entry repair: `shops with logo----带` + `logo----的商店`
            if raw == "shops with logo----带",
               index + 1 < rawLines.count,
               rawLines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines) == "logo----的商店" {
                rows.append(
                    VocabularyImportRow(
                        lineNumber: lineNum,
                        rawLine: raw,
                        word: "shops with logo",
                        meaning: "带标志的商店",
                        builtInMeaning: "带标志的商店"
                    )
                )
                rows.append(
                    VocabularyImportRow(
                        lineNumber: lineNum + 1,
                        rawLine: rawLines[index + 1],
                        word: "logo",
                        meaning: "标志，徽标",
                        builtInMeaning: "标志，徽标"
                    )
                )
                index += 2
                continue
            }

            let classified = classifySingleLine(raw)
            switch classified {
            case .bilingualPairs(let pairs):
                for pair in pairs {
                    rows.append(
                        VocabularyImportRow(
                            lineNumber: lineNum,
                            rawLine: raw,
                            word: pair.english,
                            meaning: pair.chinese,
                            builtInMeaning: pair.chinese,
                            dictionaryMeaning: BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: pair.english),
                            needsConfirmation: pair.chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    )
                }
                index += 1

            case .englishOnly(let eng):
                if let nextNonEmpty = nextNonEmptyLine(in: rawLines, after: index),
                   case .chineseOnly(let nextZH) = classifySingleLine(nextNonEmpty.text) {
                    let cleanedZH = cleanChineseMeaning(for: eng, rawZH: nextZH)
                    rows.append(
                        VocabularyImportRow(
                            lineNumber: lineNum,
                            rawLine: "\(raw) / \(nextNonEmpty.text)",
                            word: eng,
                            meaning: cleanedZH,
                            builtInMeaning: cleanedZH,
                            dictionaryMeaning: BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: eng),
                            needsConfirmation: false
                        )
                    )
                    index = nextNonEmpty.index + 1
                } else {
                    let dictLookup = BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: eng)
                    rows.append(
                        VocabularyImportRow(
                            lineNumber: lineNum,
                            rawLine: raw,
                            word: eng,
                            meaning: "",
                            builtInMeaning: "",
                            dictionaryMeaning: dictLookup,
                            included: true,
                            needsConfirmation: true
                        )
                    )
                    index += 1
                }

            case .chineseOnly(let zh):
                if let nextNonEmpty = nextNonEmptyLine(in: rawLines, after: index),
                   case .englishOnly(let nextEng) = classifySingleLine(nextNonEmpty.text) {
                    let cleanedZH = cleanChineseMeaning(for: nextEng, rawZH: zh)
                    rows.append(
                        VocabularyImportRow(
                            lineNumber: lineNum,
                            rawLine: "\(raw) / \(nextNonEmpty.text)",
                            word: nextEng,
                            meaning: cleanedZH,
                            builtInMeaning: cleanedZH,
                            dictionaryMeaning: BuiltInIELTSDictionaryEngine.lookupChineseDefinition(for: nextEng),
                            needsConfirmation: false
                        )
                    )
                    index = nextNonEmpty.index + 1
                } else {
                    ignored.append(raw)
                    index += 1
                }

            case .invalidLine(let rawLine, let engCand, let zhCand):
                rows.append(
                    VocabularyImportRow(
                        lineNumber: lineNum,
                        rawLine: rawLine,
                        word: engCand,
                        meaning: zhCand,
                        builtInMeaning: zhCand,
                        included: true,
                        needsConfirmation: true
                    )
                )
                index += 1

            case .ignoredNonVocabulary(let reasonLine):
                ignored.append(reasonLine)
                index += 1
            }
        }

        return (rows, ignored)
    }

    private static func nextNonEmptyLine(in lines: [String], after currentIndex: Int) -> (index: Int, text: String)? {
        var i = currentIndex + 1
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return (i, trimmed)
            }
            if i > currentIndex + 1 {
                return nil
            }
            i += 1
        }
        return nil
    }

    private static func isHeaderRow(_ line: String) -> Bool {
        let lower = line.lowercased().replacingOccurrences(of: " ", with: "")
        let knownHeaders: Set<String> = [
            "word\tmeaning", "word,meaning", "english\tchinese", "english,chinese",
            "单词\t释义", "单词,释义", "词汇\t中文", "word|meaning"
        ]
        return knownHeaders.contains(lower)
    }

    private static func stripLeadingIndexNumber(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^\s*(?:\(\d+\)|\[\d+\]|\d+[\.\)、\)])\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func stripPhonetics(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"\s*(?:/[^/\n]{2,40}/|\[[^\]\n]{2,40}\])\s*"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cleans noisy English terms (`check（`, `no） pets`, `café`, `ATM（automatic teller machine）`, `ETA estimated time of arrival`)
    static func cleanEnglishCandidate(_ rawEng: String) -> String {
        var s = stripPhonetics(stripLeadingIndexNumber(rawEng))
            .replacingOccurrences(of: "é", with: "e")
            .replacingOccurrences(of: "è", with: "e")
            .replacingOccurrences(of: "ê", with: "e")
            .replacingOccurrences(of: "ï", with: "i")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip garbage prefix before closing bracket like `no） pets` -> `pets`
        if s.lowercased().hasPrefix("no）") || s.lowercased().hasPrefix("no)") {
            s = String(s.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Expand `ATM（automatic teller machine）` -> `automatic teller machine`
        if let openRange = s.range(of: "（") ?? s.range(of: "("),
           let closeRange = s.range(of: "）") ?? s.range(of: ")"),
           openRange.lowerBound < closeRange.lowerBound {
            let prefix = String(s[..<openRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let inside = String(s[openRange.upperBound..<closeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if prefix.uppercased() == prefix && prefix.count <= 5 && inside.contains(" ") {
                s = inside
            }
        }

        // Strip leading acronym prefix like `ETA estimated time of arrival` or `ETD estimated time of departure`
        if s.hasPrefix("ETA ") || s.hasPrefix("ETD ") {
            s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }

        // Strip trailing unmatched opening brackets/parentheses/separators like `check（`, `flash （`, `gas（`
        let trailingJunk = CharacterSet(charactersIn: "-—–:|：,，\t （([")
        while let last = s.unicodeScalars.last, trailingJunk.contains(last) {
            s.unicodeScalars.removeLast()
        }
        let leadingJunk = CharacterSet(charactersIn: "-—–:|：,，\t ）)]")
        while let first = s.unicodeScalars.first, leadingJunk.contains(first) {
            s.unicodeScalars.removeFirst()
        }

        let tokens = s.split(whereSeparator: \.isWhitespace)
        return tokens.joined(separator: " ")
    }

    /// The Chinese supplied in the file is authoritative.
    static func cleanChineseMeaning(for english: String, rawZH: String) -> String {
        rawZH.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func classifySingleLine(_ raw: String) -> LineClassification {
        if raw.hasPrefix("#") || raw.hasPrefix("//") || raw.allSatisfy({ "-=_*~•· ".contains($0) }) {
            return .ignoredNonVocabulary(raw)
        }

        if let explicit = tryExplicitDelimiters(raw) {
            return explicit
        }

        let cleaned = stripPhonetics(stripLeadingIndexNumber(raw))
        guard !cleaned.isEmpty else { return .ignoredNonVocabulary(raw) }

        if isLikelySectionTitleOrSentence(cleaned) {
            return .ignoredNonVocabulary(raw)
        }

        let hasCJK = cleaned.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar)
        let hasASCIIAlpha = cleaned.unicodeScalars.contains(where: {
            ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A)
        })

        if hasCJK && hasASCIIAlpha {
            if let split = splitMixedEnglishAndChinese(cleaned) {
                return .bilingualPairs([(english: split.english, chinese: split.chinese)])
            }
        }

        if hasASCIIAlpha && !hasCJK {
            let cleanEng = cleanEnglishCandidate(cleaned)
            let tokenCount = cleanEng.split(whereSeparator: \.isWhitespace).count
            if VocabularyImport.isValidEnglishTerm(cleanEng) && tokenCount <= 5 {
                return .englishOnly(cleanEng)
            }
            return .ignoredNonVocabulary(raw)
        }

        if hasCJK && !hasASCIIAlpha {
            return .chineseOnly(cleaned)
        }

        return .ignoredNonVocabulary(raw)
    }

    private static func tryExplicitDelimiters(_ raw: String) -> LineClassification? {
        let explicitPatterns = ["----", "---", "--", "\t", " — ", " - ", "｜", "|", " : ", "："]
        for sep in explicitPatterns {
            if let range = raw.range(of: sep) {
                let rawLeft = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let rawRight = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawLeft.isEmpty && !rawRight.isEmpty {
                    if let oriented = orientAndExpandPair(colA: rawLeft, colB: rawRight, raw: raw) {
                        return oriented
                    }
                }
            }
        }

        if let colonIdx = raw.firstIndex(of: ":") {
            let rawLeft = String(raw[..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawRight = String(raw[raw.index(after: colonIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawLeft.isEmpty && !rawRight.isEmpty {
                let leftHasCJK = rawLeft.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar)
                let rightHasCJK = rawRight.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar)
                if leftHasCJK != rightHasCJK {
                    return orientAndExpandPair(colA: rawLeft, colB: rawRight, raw: raw)
                }
            }
        }

        return nil
    }

    private static func orientAndExpandPair(colA: String, colB: String, raw: String) -> LineClassification? {
        // Handle `southwest） Rooms & Facilities----房间以及设施`
        if colA.lowercased().hasPrefix("southwest）") || colA.lowercased().hasPrefix("southwest)") {
            return .bilingualPairs([(english: "southwest", chinese: "西南方")])
        }

        // Ignore known category / question headers like `Best time to contact----最好的打电话时间`
        let lowerA = colA.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ignoredCategoryPrompts.contains(lowerA) || lowerA.contains("__") {
            return .ignoredNonVocabulary(raw)
        }

        // Handle `piano(pianist----钢琴（钢琴家`
        if lowerA == "piano(pianist" || lowerA == "piano（pianist" {
            return .bilingualPairs([
                (english: "piano", chinese: "钢琴"),
                (english: "pianist", chinese: "钢琴家")
            ])
        }

        // Handle `single ticket=one-way ticket----单程票` or `book a seat=reserve a seat----预订座位`
        if colA.contains("=") && !colA.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar) {
            let parts = colA.components(separatedBy: "=").map { cleanEnglishCandidate($0) }.filter { VocabularyImport.isValidEnglishTerm($0) }
            if !parts.isEmpty {
                let pairs = parts.map { (english: $0, chinese: cleanChineseMeaning(for: $0, rawZH: colB)) }
                return .bilingualPairs(pairs)
            }
        }

        let aHasCJK = colA.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar)
        let bHasCJK = colB.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar)

        if !aHasCJK && bHasCJK {
            let cleanEng = cleanEnglishCandidate(colA)
            if ignoredCategoryPrompts.contains(cleanEng.lowercased()) {
                return .ignoredNonVocabulary(raw)
            }
            if VocabularyImport.isValidEnglishTerm(cleanEng) {
                let cleanZH = cleanChineseMeaning(for: cleanEng, rawZH: colB)
                return .bilingualPairs([(english: cleanEng, chinese: cleanZH)])
            }
        }

        if aHasCJK && !bHasCJK {
            let cleanEng = cleanEnglishCandidate(colB)
            if VocabularyImport.isValidEnglishTerm(cleanEng) {
                let cleanZH = cleanChineseMeaning(for: cleanEng, rawZH: colA)
                return .bilingualPairs([(english: cleanEng, chinese: cleanZH)])
            }
        }

        let cleanA = cleanEnglishCandidate(colA)
        let cleanB = cleanEnglishCandidate(colB)
        if VocabularyImport.isValidEnglishTerm(cleanA) && VocabularyImport.isValidEnglishTerm(cleanB) {
            return .bilingualPairs([(english: cleanA, chinese: colB.trimmingCharacters(in: .whitespacesAndNewlines))])
        }

        return nil
    }

    private static func splitMixedEnglishAndChinese(_ line: String) -> (english: String, chinese: String)? {
        let scalars = Array(line.unicodeScalars)
        guard let firstCJKIndex = scalars.firstIndex(where: { ExamEnglishInputPolicy.isCJKScalar($0) || ExamEnglishInputPolicy.isFullWidthOrCJKPunctuation($0) }),
              let lastCJKIndex = scalars.lastIndex(where: { ExamEnglishInputPolicy.isCJKScalar($0) || ExamEnglishInputPolicy.isFullWidthOrCJKPunctuation($0) }) else {
            return nil
        }

        let firstASCIIAlphaIndex = scalars.firstIndex(where: {
            ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A)
        }) ?? 0

        if firstASCIIAlphaIndex < firstCJKIndex {
            var prefixStr = String(String.UnicodeScalarView(scalars[..<firstCJKIndex])).trimmingCharacters(in: .whitespacesAndNewlines)
            var suffixStr = String(String.UnicodeScalarView(scalars[firstCJKIndex...])).trimmingCharacters(in: .whitespacesAndNewlines)

            let posPattern = #"\s+(?:n|v|vt|vi|adj|adv|prep|conj|pron|phr)\.\s*$"#
            if let posRange = prefixStr.range(of: posPattern, options: [.regularExpression, .caseInsensitive]) {
                let posTag = prefixStr[posRange].trimmingCharacters(in: .whitespacesAndNewlines)
                prefixStr = String(prefixStr[..<posRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                suffixStr = "\(posTag) \(suffixStr)"
            }
            let cleanEng = cleanEnglishCandidate(prefixStr)
            if VocabularyImport.isValidEnglishTerm(cleanEng) {
                return (cleanEng, cleanChineseMeaning(for: cleanEng, rawZH: suffixStr))
            }
        } else {
            let zhPart = String(String.UnicodeScalarView(scalars[...lastCJKIndex]))
                .trimmingCharacters(in: CharacterSet(charactersIn: "-—:：|,;\t "))
            let engPart = String(String.UnicodeScalarView(scalars[(lastCJKIndex + 1)...]))
                .trimmingCharacters(in: CharacterSet(charactersIn: "-—:：|,;\t "))
            let cleanEng = cleanEnglishCandidate(engPart)
            if VocabularyImport.isValidEnglishTerm(cleanEng) && !zhPart.isEmpty {
                return (cleanEng, cleanChineseMeaning(for: cleanEng, rawZH: zhPart))
            }
        }
        return nil
    }

    private static func isLikelySectionTitleOrSentence(_ line: String) -> Bool {
        let lower = line.lowercased()
        if ignoredCategoryPrompts.contains(lower) {
            return true
        }
        let hasCJK = line.unicodeScalars.contains(where: ExamEnglishInputPolicy.isCJKScalar)
        if !hasCJK {
            let titlePrefixes = ["unit ", "chapter ", "section ", "part ", "test ", "cambridge ", "passage ", "list ", "day ", "week ", "lesson "]
            if titlePrefixes.contains(where: { lower.hasPrefix($0) }) {
                return true
            }
            if line.range(of: #"^[A-Z][a-z]{1,12}:\s+"#, options: .regularExpression) != nil {
                return true
            }
            let words = line.split(whereSeparator: \.isWhitespace)
            if words.count > 5 {
                return true
            }
            if words.count >= 4 && (line.hasSuffix(".") || line.hasSuffix("?") || line.hasSuffix("!")) {
                return true
            }
        }
        return false
    }
}

public nonisolated enum VocabularyImport {
    struct Item: Decodable {
        let word: String
        let meaning: String
    }

    public static func isValidEnglishTerm(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { return false }
        let hasAlpha = trimmed.unicodeScalars.contains { ($0.value >= 65 && $0.value <= 90) || ($0.value >= 97 && $0.value <= 122) }
        let hasCJK = trimmed.unicodeScalars.contains { ExamEnglishInputPolicy.isCJKScalar($0) }
        guard hasAlpha, !hasCJK else { return false }
        let words = trimmed.split(separator: " ")
        guard words.count <= 12 else { return false }
        if words.count >= 4 && (trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")) {
            return false
        }
        for scalar in trimmed.unicodeScalars {
            let v = scalar.value
            let isAllowed = (v >= 65 && v <= 90) ||
                            (v >= 97 && v <= 122) ||
                            (v >= 48 && v <= 57) ||
                            (v >= 0x00C0 && v <= 0x00FF) ||
                            scalar == " " || scalar == "-" || scalar == "'" || scalar == "’" || scalar == "/" || scalar == "." || scalar == "(" || scalar == ")"
            if !isAllowed { return false }
        }
        let norm = DictationAnswerPolicy.normalized(trimmed)
        return !norm.isEmpty && norm != "\u{0}"
    }

    public static func parse(_ data: Data, filename: String) throws -> [VocabularyWord] {
        guard data.count <= 2 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        if filename.lowercased().hasSuffix(".json") {
            let entries = try JSONDecoder().decode([Item].self, from: data)
            return try build(entries, filename: filename)
        } else if filename.lowercased().hasSuffix(".tsv") {
            guard let text = VocabularyImportDraft.decodeText(data) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            let entries: [Item] = try text.components(separatedBy: .newlines).enumerated().compactMap { index, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
                let columns = line.components(separatedBy: "\t")
                if index == 0 && columns.first?.lowercased() == "word" { return nil }
                guard columns.count >= 2 else { throw CocoaError(.fileReadCorruptFile) }
                return Item(word: columns[0], meaning: columns[1...].joined(separator: "\t"))
            }
            return try build(entries, filename: filename)
        } else {
            var draft = try VocabularyImportDraft(data: data, filename: filename)
            guard !draft.rows.isEmpty, draft.unmatchedOrAmbiguousCount == 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            draft.applyDefaultSelection(existing: [])
            return try draft.confirmedWords(existing: [])
        }
    }

    static func parseJSONEntries(_ data: Data, filename: String) throws -> [VocabularyWord] {
        try build(JSONDecoder().decode([Item].self, from: data), filename: filename)
    }

    private static func build(_ entries: [Item], filename: String) throws -> [VocabularyWord] {
        guard !entries.isEmpty, entries.count <= 20000 else { throw CocoaError(.fileReadCorruptFile) }
        let deck = deckIdentifier(for: filename)
        var seen = Set<String>()
        return try entries.compactMap { entry in
            let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, !meaning.isEmpty, word.count <= 200,
                  word.unicodeScalars.allSatisfy({ ($0.value >= 32 && $0.value <= 126) || $0 == "’" }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let id = deck + "." + hex(Data(word.lowercased().utf8))
            guard seen.insert(id).inserted else { return nil }
            return VocabularyWord(
                id: id,
                word: word,
                phoneticUK: "",
                phoneticUS: "",
                partOfSpeech: "",
                definitionZH: meaning,
                exampleSentence: "",
                deckID: deck,
                deckTitle: (filename as NSString).deletingPathExtension
            )
        }
    }

    public static func deckIdentifier(for filename: String) -> String {
        "import." + hex(Data(filename.utf8))
    }

    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}
