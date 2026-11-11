import Foundation
import Testing
@testable import LumaReaderStudyKit

struct ImportMeaningAndBundledBooksTests {
    @Test func differentMalformedWordsDoNotShareDuplicateIdentity() throws {
        var draft = try VocabularyImportDraft(data: Data("apple----苹果".utf8), filename: "test.txt")
        draft.rows = [
            VocabularyImportRow(word: "maintenance(maintain", meaning: "维修"),
            VocabularyImportRow(word: "confidence(confident", meaning: "自信心")
        ]
        #expect(draft.duplicateKinds(existing: []).isEmpty)
    }

    @Test func fileChineseIsNeverRewritten() {
        #expect(VocabularyImportDraft.cleanChineseMeaning(for: "tables", rawZH: "桌子们") == "桌子们")
        #expect(VocabularyImportDraft.cleanChineseMeaning(for: "newspaper", rawZH: "报纸俱乐部") == "报纸俱乐部")
    }

    @Test func bundledBooksAreAdditiveAndInstalledOnlyOnce() throws {
        let existing = VocabularyWord(id: "keep-progress-id", word: "apple", definitionZH: "苹果", deckID: "personal", deckTitle: "我的词本")
        var snapshot = StudyStoreSnapshot(importedWords: [existing])
        snapshot.legacyDraftBackups = ["draft": "保留草稿"]
        let seeded = try BundledCoraVocabulary.addingTo(snapshot)
        #expect(seeded.importedWords?.first == existing)
        #expect(seeded.legacyDraftBackups == snapshot.legacyDraftBackups)
        #expect((seeded.importedWords?.count ?? 0) > 3600)
        #expect(Set(seeded.importedWords?.map(\.deckID) ?? []).count == 14)
        #expect(try BundledCoraVocabulary.addingTo(seeded) == seeded)
        let restored = try JSONDecoder().decode(StudyStoreSnapshot.self, from: JSONEncoder().encode(seeded))
        #expect(restored.installedVocabularyPackIDs == [BundledCoraVocabulary.packID])
        var deleted = restored
        deleted.importedWords = [existing]
        #expect(try BundledCoraVocabulary.addingTo(deleted) == deleted)
    }
}
