import Foundation

struct LumaChoiceQuizQuestion: Identifiable, Equatable, Codable {
    let id: String
    let word: VocabularyWord
    let options: [String]
    let correctIndex: Int

    func isCorrect(_ index: Int) -> Bool { index == correctIndex }
}

struct ReadingQuizDraft: Codable {
    let questions: [LumaChoiceQuizQuestion]
    let index: Int
    let picked: Int?
    let eliminated: Set<Int>
    let revealedByHelp: Bool
    let correctIDs: [String]
    let wrongWords: [VocabularyWord]
    let roundStartCursor: Int
    let roundEndCursor: Int

    var answeredCount: Int { index + (picked == nil ? 0 : 1) }

    func isValid(for words: [VocabularyWord]) -> Bool {
        guard questions.indices.contains(index) else { return false }
        let current = questions[index]
        guard picked.map(current.options.indices.contains) ?? true else { return false }
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return questions.allSatisfy { byID[$0.word.id] == $0.word }
    }
}

enum LumaChoiceQuizBuilder {
    private static let posPattern = #"^\s*((?:n|v|vt|vi|adj|adv|prep|conj|pron|int|interj|num|art|aux|phr|abbr|a|ad)\.(?:\s*[/&,]\s*(?:n|v|vt|vi|adj|adv|a|ad)\.)*)\s*"#

    private static let posRegex = try! NSRegularExpression(pattern: posPattern, options: [.caseInsensitive])

    /// 把 "n. 门廊，走廊" 拆成 ("n.", "门廊，走廊")；无词性时返回 ("", 原文)。
    static func splitPOS(_ raw: String) -> (pos: String, text: String) {
        let flat = raw.replacingOccurrences(of: "\n", with: "；")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = posRegex.firstMatch(in: flat, range: NSRange(flat.startIndex..., in: flat)),
              let posRange = Range(match.range(at: 1), in: flat),
              let whole = Range(match.range, in: flat) else { return ("", flat) }
        let rest = String(flat[whole.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? ("", flat) : (String(flat[posRange]).lowercased(), rest)
    }

    static func displayMeaning(for word: VocabularyWord) -> String {
        let raw = word.definitionZH.trimmingCharacters(in: .whitespacesAndNewlines)
        let split = splitPOS(raw)
        if split.pos.isEmpty && !word.partOfSpeech.isEmpty {
            let pos = word.partOfSpeech.hasSuffix(".") ? word.partOfSpeech : word.partOfSpeech + "."
            return pos + " " + split.text
        }
        return raw.replacingOccurrences(of: "\n", with: "；")
    }

    private struct Candidate {
        let word: VocabularyWord
        let headword: String
        let meaning: String
        let senses: Set<String>
        let pos: String

        init(_ word: VocabularyWord) {
            self.word = word
            headword = word.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            meaning = displayMeaning(for: word)
            senses = senseKeys(meaning)
            pos = splitPOS(meaning).pos.split(separator: ".").first.map { String($0) } ?? ""
        }
    }

    private static let glossAliases: [String: String] = {
        let groups = [
            ["开心", "高兴", "愉快", "快乐"], ["迅速", "快速", "很快", "飞快"],
            ["开始", "开端", "起始"], ["结束", "终结", "完结"], ["购买", "购入", "买"],
            ["援助", "协助", "帮助"], ["栖息地", "生境", "栖息环境"],
            ["选项", "备选项", "可选项"], ["可能性", "有可能"], ["巨大", "庞大", "非常大"]
        ]
        return Dictionary(uniqueKeysWithValues: groups.flatMap { group in group.map { ($0, group[0]) } })
    }()

    private static func senseKeys(_ meaning: String) -> Set<String> {
        let text = meaning.replacingOccurrences(of: #"[（(][^（）()]*[）)]"#, with: "", options: .regularExpression)
        let separators = CharacterSet(charactersIn: "，,；;、/／。\n\r")
        return Set(text.components(separatedBy: separators).compactMap { segment in
            let core = splitPOS(segment).text
            var key = core.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
                .filter { !$0.isWhitespace && !$0.isPunctuation && $0 != "…" }
            if key.hasSuffix("的"), key.count > 1 { key.removeLast() }
            return key.isEmpty ? nil : (glossAliases[key] ?? key)
        })
    }

    static func makeRound(words: [VocabularyWord], deckPool: [VocabularyWord], globalPool: [VocabularyWord]) -> [LumaChoiceQuizQuestion] {
        var random = SystemRandomNumberGenerator()
        return makeRound(words: words, deckPool: deckPool, globalPool: globalPool, random: &random)
    }

    static func makeRound<R: RandomNumberGenerator>(
        words: [VocabularyWord], deckPool: [VocabularyWord], globalPool: [VocabularyWord], random: inout R
    ) -> [LumaChoiceQuizQuestion] {
        let orderedWords = words.shuffled(using: &random)
        var seen = Set<String>()
        let local = deckPool.filter { seen.insert($0.id).inserted }.map(Candidate.init)
        var external: [Candidate]?
        var positions: [Int] = []
        var questions: [LumaChoiceQuizQuestion] = []

        for word in orderedWords {
            let answer = Candidate(word)
            guard !answer.senses.isEmpty else { continue }
            var usedSenses = answer.senses
            var usedHeadwords: Set<String> = [answer.headword]
            var distractors: [String] = []

            func take(from pool: [Candidate], samePOS: Bool) {
                guard distractors.count < 3 else { return }
                for candidate in pool {
                    guard candidate.word.id != word.id,
                          !candidate.senses.isEmpty,
                          usedSenses.isDisjoint(with: candidate.senses),
                          !usedHeadwords.contains(candidate.headword),
                          !samePOS || candidate.pos == answer.pos else { continue }
                    usedSenses.formUnion(candidate.senses)
                    usedHeadwords.insert(candidate.headword)
                    distractors.append(candidate.meaning)
                    if distractors.count == 3 { break }
                }
            }

            let shuffledLocal = local.shuffled(using: &random)
            if !answer.pos.isEmpty { take(from: shuffledLocal, samePOS: true) }
            take(from: shuffledLocal, samePOS: false)
            if distractors.count < 3 {
                if external == nil {
                    external = globalPool.filter { seen.insert($0.id).inserted }.map(Candidate.init)
                }
                let shuffledExternal = (external ?? []).shuffled(using: &random)
                if !answer.pos.isEmpty { take(from: shuffledExternal, samePOS: true) }
                take(from: shuffledExternal, samePOS: false)
                if distractors.count < 3 {
                    usedSenses = answer.senses
                    usedHeadwords = [answer.headword]
                    distractors = []
                    // Broad multi-sense glosses can block several otherwise valid choices.
                    take(from: (shuffledLocal + shuffledExternal).sorted { $0.senses.count < $1.senses.count }, samePOS: false)
                }
            }
            guard distractors.count == 3 else { continue }

            if positions.isEmpty { positions = Array(0..<4).shuffled(using: &random) }
            let correctIndex = positions.removeLast()
            distractors.shuffle(using: &random)
            distractors.insert(answer.meaning, at: correctIndex)
            questions.append(LumaChoiceQuizQuestion(
                id: word.id + "#" + UUID().uuidString,
                word: word, options: distractors, correctIndex: correctIndex
            ))
        }
        return questions
    }
}
