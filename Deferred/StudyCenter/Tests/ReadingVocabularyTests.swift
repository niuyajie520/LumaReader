import Foundation
import Testing
@testable import LumaReaderStudyKit

@MainActor
struct ReadingVocabularyTests {
    @Test func importedWordsCanBePracticedAndWrongWordsSurviveReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = LumaChoiceLibrary(directory: directory)
        let word = VocabularyWord(id: "import", word: "habitat", definitionZH: "栖息地", deckID: "import", deckTitle: "生态")
        let deck = try #require(library.createDeck(title: "生态", in: ["阅读", "自然", "生态"], words: [word]))
        let imported = try #require(library.readingWords(in: deck).first)
        #expect(library.allReadingWords.contains(imported))

        library.recordReadingMiss(imported.id)
        library.recordReadingMiss(imported.id)
        let reopened = LumaChoiceLibrary(directory: directory)
        #expect(reopened.readingWrongWords == [imported])
        #expect(reopened.snapshot.readingMisses?[imported.id] == 2)
        #expect(reopened.decks(in: ["阅读", "自然", "生态"]).first?.id == deck)
        reopened.removeReadingMiss(imported.id)
        #expect(LumaChoiceLibrary(directory: directory).readingWrongWords.isEmpty)
    }

    @Test func olderReadingStoreDecodesWithoutNewFields() throws {
        let data = Data(#"{"schema":1,"decks":[],"words":[],"folders":[]}"#.utf8)
        let snapshot = try JSONDecoder().decode(LumaChoiceLibrarySnapshot.self, from: data)
        #expect(snapshot.readingMisses == nil)
        #expect(snapshot.builtInReadingFolders == nil)
    }
}
