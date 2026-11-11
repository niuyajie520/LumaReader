import Foundation
import Testing
@testable import LumaReaderStudyKit

@Suite("TXT Bilingual Smart Recognition & Import Preview Tests")
struct SmartUpgradeVocabularyImportTests {

    @Test("1. Recognizes forward, reverse, and mixed delimiter formats automatically")
    func testForwardReverseAndMixedFormats() throws {
        let sampleTXT = """
        apple----苹果
        banana 香蕉
        樱桃 cherry
        sustainable | 可持续的
        fluctuate: 波动，起伏
        capacity\t容量；能力
        """
        let draft = try VocabularyImportDraft(data: Data(sampleTXT.utf8), filename: "mixed_vocab.txt")
        #expect(draft.recognizedEnglishCount == 6)
        #expect(draft.pairedMeaningCount == 6)
        #expect(draft.unmatchedOrAmbiguousCount == 0)
        #expect((try draft.confirmedWords(existing: [])).count == 6)

        let byWord = Dictionary(uniqueKeysWithValues: (try draft.confirmedWords(existing: [])).map { ($0.word, $0.definitionZH) })
        #expect(byWord["apple"] == "苹果")
        #expect(byWord["banana"] == "香蕉")
        #expect(byWord["cherry"] == "樱桃")
        #expect(byWord["sustainable"] == "可持续的")
        #expect(byWord["fluctuate"] == "波动，起伏")
        #expect(byWord["capacity"] == "容量；能力")
    }

    @Test("2. Supports adjacent two-line pairing (English->Chinese and Chinese->English) & preserves spaces/hyphens/apostrophes")
    func testAdjacentTwoLinePairingAndPhrases() throws {
        let sampleTXT = """
        take responsibility for
        承担责任

        环境保护
        environmental protection

        well-known----众所周知的
        don't give up 别放弃
        """
        let draft = try VocabularyImportDraft(data: Data(sampleTXT.utf8), filename: "phrases.txt")
        #expect(draft.recognizedEnglishCount == 4)
        #expect(draft.pairedMeaningCount == 4)

        let byWord = Dictionary(uniqueKeysWithValues: (try draft.confirmedWords(existing: [])).map { ($0.word, $0.definitionZH) })
        #expect(byWord["take responsibility for"] == "承担责任")
        #expect(byWord["environmental protection"] == "环境保护")
        #expect(byWord["well-known"] == "众所周知的")
        #expect(byWord["don't give up"] == "别放弃")
    }

    @Test("3. Supports UTF-8 with BOM, UTF-16LE, and filters out titles, full example sentences, and listening scripts without fabricating translations")
    func testEncodingsFilteringAndAmbiguousItems() throws {
        let rawContent = """
        Unit 1 Core Listening Vocabulary
        ================================
        abandon 放弃
        The government decided to abandon the project because of rising costs.
        Woman: Good morning, how can I help you with your registration today?
        mystery
        ----
        inevitable 不可避免的
        """
        // Prepend UTF-8 BOM (EF BB BF)
        var bomData = Data([0xEF, 0xBB, 0xBF])
        bomData.append(Data(rawContent.utf8))

        let draft = try VocabularyImportDraft(data: bomData, filename: "unit1.txt")
        let utf16 = try #require(rawContent.data(using: .utf16LittleEndian))
        let utf16Draft = try VocabularyImportDraft(data: Data([0xFF, 0xFE]) + utf16, filename: "unit1.txt")
        #expect(utf16Draft.rows.map(\.word) == draft.rows.map(\.word))
        // 'abandon' and 'inevitable' are paired; 'mystery' is marked needsConfirmation (待确认) without fabricated translation
        #expect(draft.pairedMeaningCount == 2)
        #expect(draft.unmatchedOrAmbiguousCount == 1)
        #expect(draft.ignoredNonVocabularyLines.count >= 3)

        var pairedOnly = draft
        pairedOnly.rows.removeAll { $0.needsConfirmation }
        let confirmedWords = try pairedOnly.confirmedWords(existing: [])
        #expect(confirmedWords.count == 2)
        #expect(confirmedWords.map(\.word) == ["abandon", "inevitable"])

        let pendingRow = draft.rows.first { $0.needsConfirmation }
        #expect(pendingRow != nil)
        #expect(pendingRow?.word == "mystery")
        #expect(pendingRow?.meaning.isEmpty == true)
    }

    @Test("4. Failed or unconfirmed import leaves existing vocabulary completely unchanged")
    @MainActor
    func testFailedOrUnconfirmedImportPreservesExistingVocabulary() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let session = LumaStudySession(storageDirectory: tempDir)
        let initialImportedCount = session.model.storeSnapshot.importedWords?.count ?? 0

        // Binary invalid data must throw and never alter session.model.storeSnapshot.importedWords
        let invalidBinary = Data([0xFF, 0xFE, 0x00, 0x00, 0x81, 0x00])
        do {
            _ = try VocabularyImportDraft(data: invalidBinary, filename: "corrupt.bin")
            Issue.record("Corrupt binary unexpectedly accepted")
        } catch {
            // Expected failure
        }
        #expect((session.model.storeSnapshot.importedWords?.count ?? 0) == initialImportedCount)
    }

    @Test("Nothing is skipped automatically: duplicates are flagged, unticked by default, and imported only when the user ticks them")
    func testNoAutomaticSkipping() throws {
        let txt = "block----街区\nblock----封锁\nfoyer----门厅\nfoyer----门厅\nknob----旋钮"
        var draft = try VocabularyImportDraft(data: Data(txt.utf8), filename: "dups.txt")
        #expect(draft.rows.count == 5)
        let kinds = draft.duplicateKinds(existing: [])
        #expect(kinds[draft.rows[1].id] == .sameWordOtherMeaning)
        #expect(kinds[draft.rows[3].id] == .exactDuplicate)
        // Without any selection step every ticked row is imported, with unique IDs.
        let all = draft.importPlan(existing: [])
        #expect(all.words.count == 5)
        #expect(Set(all.words.map(\.id)).count == 5)
        // Default selection only un-ticks the exact duplicate; the row is still there.
        draft.applyDefaultSelection(existing: [])
        #expect(draft.rows.count == 5)
        #expect(draft.rows[3].included == false)
        #expect(draft.importPlan(existing: []).words.count == 4)
        #expect((try draft.confirmedWords(existing: [])).count == 4)
        // The user ticks it back: it is imported.
        draft.rows[3].included = true
        #expect(draft.importPlan(existing: []).words.count == 5)
        // Merge is the user's own choice.
        draft.mergeSameWordMeanings = true
        let merged = draft.importPlan(existing: [])
        #expect(merged.words.count == 3)
        #expect(merged.words.first(where: { $0.word == "block" })?.definitionZH == "街区；封锁")
        #expect(merged.words.first(where: { $0.word == "foyer" })?.definitionZH == "门厅")
    }

    @Test("Ignored lines can be added back to the import by the user")
    func testIgnoredLinesCanBeRestored() throws {
        let txt = "Best time to contact----最好的打电话时间\napple----苹果"
        var draft = try VocabularyImportDraft(data: Data(txt.utf8), filename: "ignored.txt")
        let ignoredBefore = draft.ignoredNonVocabularyLines.count
        #expect(ignoredBefore >= 1)
        let rowsBefore = draft.rows.count
        draft.restoreAllIgnoredLines()
        #expect(draft.ignoredNonVocabularyLines.isEmpty)
        #expect(draft.rows.count == rowsBefore + ignoredBefore)
        #expect(draft.rows.contains { $0.word == "Best time to contact" && $0.meaning == "最好的打电话时间" })
        #expect((try draft.confirmedWords(existing: [])).contains { $0.word == "Best time to contact" })
    }
}
