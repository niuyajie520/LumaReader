import Foundation

// MARK: - 词条

/// 词条本体来自 LumaCore；这里只补 UI 展示与 JSON 桥接。
extension VocabularyWord {
    var wordCount: Int {
        word.split(whereSeparator: { $0 == " " || $0 == "\t" }).count
    }

    var isPhrase: Bool { wordCount > 1 }

    /// 手机列表里只展示第一层释义，完整释义放到详情页。
    var shortDefinition: String {
        let parts = definitionZH
            .split(whereSeparator: { $0 == "；" || $0 == ";" || $0 == "、" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.first ?? definitionZH
    }

    var phonetic: String {
        if !phoneticUS.trimmingCharacters(in: .whitespaces).isEmpty { return phoneticUS }
        return phoneticUK
    }

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, let word = json["word"] as? String else { return nil }
        self.init(
            id: id,
            word: word,
            phoneticUK: (json["phoneticUK"] as? String) ?? "",
            phoneticUS: (json["phoneticUS"] as? String) ?? "",
            partOfSpeech: (json["partOfSpeech"] as? String) ?? "",
            definitionZH: (json["definitionZH"] as? String) ?? "",
            exampleSentence: (json["exampleSentence"] as? String) ?? "",
            deckID: (json["deckID"] as? String) ?? "",
            deckTitle: (json["deckTitle"] as? String) ?? ""
        )
    }

    var json: [String: Any] {
        var object: [String: Any] = [
            "id": id,
            "word": word,
            "definitionZH": definitionZH,
            "phoneticUS": phoneticUS,
            "phoneticUK": phoneticUK,
            "partOfSpeech": partOfSpeech,
            "exampleSentence": exampleSentence,
            "deckID": deckID,
            "deckTitle": deckTitle
        ]
        if let folderPath { object["folderPath"] = folderPath }
        return object
    }
}

// MARK: - 词本（deck）

struct VocabularyDeck: Identifiable, Hashable {
    var id: String
    var title: String
    var words: [VocabularyWord]

    var count: Int { words.count }
}

// MARK: - 复习进度与听写记录都由 LumaCore 提供，两端共用同一套字段与间隔。

// MARK: - 日期工具

enum JSONDate {
    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func decode(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        if let date = iso.date(from: text) { return date }
        if let date = isoFractional.date(from: text) { return date }
        return nil
    }

    static func encode(_ date: Date) -> String { iso.string(from: date) }
    static func encode(_ date: Date?) -> String? { date.map { iso.string(from: $0) } }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }
}

// MARK: - 排序

enum WordReviewOrdering {
    static func isDueForNextDayRecall(_ progress: WordReviewProgress?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let progress else { return false }
        guard progress.dueAt <= now else { return false }
        guard let last = progress.lastReviewedAt else { return true }
        return !calendar.isDate(last, inSameDayAs: now)
    }

    /// 到期词提前，其余保持原顺序（稳定分区，不重排相对次序）。
    static func dueFirst(_ words: [VocabularyWord], schedule: [String: WordReviewProgress], now: Date = Date(), calendar: Calendar = .current) -> [VocabularyWord] {
        var due: [VocabularyWord] = []
        var rest: [VocabularyWord] = []
        for word in words {
            if isDueForNextDayRecall(schedule[word.id], now: now, calendar: calendar) { due.append(word) } else { rest.append(word) }
        }
        return due + rest
    }
}
