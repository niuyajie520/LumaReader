import Foundation

public struct VocabularyWord: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let word: String
    public let phoneticUK: String
    public let phoneticUS: String
    public let partOfSpeech: String
    public let definitionZH: String
    public let exampleSentence: String
    public let deckID: String
    public let deckTitle: String
    /// Optional explicit three-level folder path (e.g. 剑桥20/第5章/5.3-2).
    /// Imported datasets can preserve their original workbook hierarchy without
    /// depending on the deck-title heuristic.
    public var folderPath: [String]? = nil

    public init(
        id: String,
        word: String,
        phoneticUK: String = "",
        phoneticUS: String = "",
        partOfSpeech: String = "",
        definitionZH: String,
        exampleSentence: String = "",
        deckID: String,
        deckTitle: String,
        folderPath: [String]? = nil
    ) {
        self.id = id
        self.word = word
        self.phoneticUK = phoneticUK
        self.phoneticUS = phoneticUS
        self.partOfSpeech = partOfSpeech
        self.definitionZH = definitionZH
        self.exampleSentence = exampleSentence
        self.deckID = deckID
        self.deckTitle = deckTitle
        self.folderPath = folderPath
    }
}
