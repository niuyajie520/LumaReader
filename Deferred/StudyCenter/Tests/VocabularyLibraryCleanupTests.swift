import XCTest
@testable import LumaReaderStudyKit

final class VocabularyLibraryCleanupTests: XCTestCase {
    private func word(
        _ id: String,
        _ text: String,
        _ definition: String,
        deck: String
    ) -> VocabularyWord {
        VocabularyWord(id: id, word: text, definitionZH: definition, deckID: deck, deckTitle: deck)
    }

    func testRedundantDeckCopiesAreDropped() {
        let words = [
            word("a", "donations", "捐款", deck: "c20.corpus.u11"),
            word("b", "donations", "捐款", deck: "luma.c20.ch11"),
            word("c", "rent", "租金", deck: "luma.p1.租房场景"),
        ]
        let outcome = VocabularyLibraryCleanup.cleaned(words)
        XCTAssertEqual(outcome.words.map(\.id), ["a"])
        XCTAssertEqual(outcome.removedWordIDs, ["b", "c"])
    }

    func testBritishSpellingBecomesAmericanAndCollapsesIntoOneEntry() {
        let words = [
            word("a", "labour market", "劳动力市场", deck: "ielts.p1.work"),
            word("b", "labor market", "", deck: "ielts.p1.work"),
            word("c", "cheque", "英式写法", deck: "ielts.p1.renting"),
        ]
        let outcome = VocabularyLibraryCleanup.cleaned(words)
        XCTAssertEqual(outcome.words.map(\.word), ["labor market", "check"])
        XCTAssertEqual(outcome.words.last?.definitionZH, "支票；检查")
    }

    func testSameWordWithHyphenAndSpaceCollapsesAcrossParallelDecks() {
        let words = [
            word("a", "double grill", "双层烤架", deck: "c20.corpus.u5"),
            word("b", "double-grill", "双层烤架", deck: "c20.corpus.u11"),
        ]
        let outcome = VocabularyLibraryCleanup.cleaned(words)
        XCTAssertEqual(outcome.words.map(\.id), ["a"])
    }

    func testWordCoveredByPhraseInTheSameDeckIsDropped() {
        let words = [
            word("a", "kangaroo", "袋鼠", deck: "c20.corpus.u5"),
            word("b", "red kangaroo", "红袋鼠", deck: "c20.corpus.u5"),
            word("c", "cement", "水泥", deck: "c20.corpus.u5"),
            word("d", "eco-cement", "生态水泥", deck: "c20.corpus.u5"),
        ]
        let outcome = VocabularyLibraryCleanup.cleaned(words)
        XCTAssertEqual(outcome.words.map(\.id), ["b", "d"])
        XCTAssertEqual(outcome.removedWordIDs, ["a", "c"])
    }

    func testCoreWordIsKeptWhenThePhraseOnlyUsesItAsAModifier() {
        let words = [
            word("a", "bus", "公交车", deck: "ielts.p1.renting"),
            word("b", "bus stop", "公交站", deck: "ielts.p1.renting"),
            word("c", "rent", "租金", deck: "ielts.p1.renting"),
            word("d", "rent a flat", "租公寓", deck: "ielts.p1.renting"),
        ]
        let outcome = VocabularyLibraryCleanup.cleaned(words)
        XCTAssertEqual(outcome.words.map(\.id), ["a", "b", "c", "d"])
        XCTAssertTrue(outcome.removedWordIDs.isEmpty)
    }

    func testRepairDropsRecordsOfDeletedWordsAndReturnsSelectionToLiveDeck() {
        var snapshot = StudyStoreSnapshot()
        snapshot.importedWords = [word("keep", "apple juice", "苹果汁", deck: "c20.corpus.u5")]
        snapshot.reviewSchedule = [
            "keep": WordReviewProgress(dueAt: Date()),
            "gone": WordReviewProgress(dueAt: Date()),
        ]
        snapshot.dictationLogs = [
            DictationAttemptLog(
                id: UUID(),
                sessionID: UUID(),
                mode: .newTask,
                wordID: "gone",
                word: "kangaroo",
                deckID: "luma.c20.ch5",
                userTyped: "kangaru",
                isCorrect: false,
                isFirstAttemptInSession: true,
                sessionErrorCountForWord: 1,
                timestamp: Date(),
                dateString: "2026-11-15",
                durationSeconds: 3
            )
        ]
        var workspace = StudyWorkspaceState()
        workspace.selectedDeckID = "luma.c20.ch5"
        snapshot.workspace = workspace

        VocabularyLibraryCleanup.repairReferences(in: &snapshot, removedWordIDs: ["gone"])

        XCTAssertEqual(snapshot.reviewSchedule?.keys.sorted(), ["keep"])
        XCTAssertTrue(snapshot.dictationLogs.isEmpty)
        XCTAssertNotEqual(snapshot.workspace?.selectedDeckID, "luma.c20.ch5")
    }
}
