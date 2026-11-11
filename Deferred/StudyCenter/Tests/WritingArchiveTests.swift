import XCTest
@testable import LumaReaderStudyKit

final class WritingArchiveTests: XCTestCase {
    func testDraftsAndSubmissionsRoundTripThroughSQLite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("writing-archive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let archive = try WritingArchive(url: dir.appendingPathComponent("writing.sqlite"))
        let draft = WritingExamDraftState(
            id: UUID(), questionID: "q1", examTitle: "Test Essay", activePart: .part1,
            part1EssayText: "Some text", part2EssayText: "", remainingSeconds: 1200,
            elapsedSeconds: 30, isPaused: false, isSingleTaskMode: true,
            lastSavedAt: Date(), containsLegacyNonEnglishNotice: false
        )
        let submission = WritingSubmissionRecord(
            id: UUID(), draftSessionID: draft.id, questionID: "q1", examTitle: "Test Essay",
            part1EssayText: "Some text", part2EssayText: "", part1WordCount: 2,
            part2WordCount: 0, durationSeconds: 30, submittedAt: Date(),
            dateString: "2026-11-10", aiEvaluation: nil
        )
        try archive.save(drafts: [draft.id.uuidString: draft], submissions: [submission])

        let loaded = try XCTUnwrap(archive.load())
        XCTAssertEqual(loaded.drafts[draft.id.uuidString]?.part1EssayText, "Some text")
        XCTAssertEqual(loaded.submissions.count, 1)
        XCTAssertEqual(loaded.submissions.first?.id, submission.id)
        XCTAssertNotNil(loaded.savedAt)
    }
}

extension WritingArchiveTests {
    func testLocalJSONDoesNotKeepDuplicateEssays() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("writing-single-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = try StudyPersistenceManager(storageDirectory: dir)
        var snapshot = StudyStoreSnapshot()
        let draft = WritingExamDraftState(
            id: UUID(), questionID: "q1", examTitle: "Single Copy", activePart: .part1,
            part1EssayText: "Only in sqlite", part2EssayText: "", remainingSeconds: 1200,
            elapsedSeconds: 10, isPaused: false, isSingleTaskMode: true,
            lastSavedAt: Date(), containsLegacyNonEnglishNotice: false
        )
        snapshot.activeWritingDrafts[draft.id.uuidString] = draft
        snapshot.writingSubmissions = [WritingSubmissionRecord(
            id: UUID(), draftSessionID: draft.id, questionID: "q1", examTitle: "Single Copy",
            part1EssayText: "Only in sqlite", part2EssayText: "", part1WordCount: 3,
            part2WordCount: 0, durationSeconds: 10, submittedAt: Date(),
            dateString: "2026-11-10", aiEvaluation: nil
        )]
        try manager.save(snapshot)

        let raw = try Data(contentsOf: dir.appendingPathComponent("luma_study_store.json"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: raw) as? [String: Any])
        XCTAssertEqual((json["activeWritingDrafts"] as? [String: Any])?.count, 0)
        XCTAssertEqual((json["writingSubmissions"] as? [Any])?.count, 0)

        let loaded = try StudyPersistenceManager(storageDirectory: dir).loadAndMigrateIfNeeded()
        XCTAssertEqual(loaded.activeWritingDrafts[draft.id.uuidString]?.part1EssayText, "Only in sqlite")
        XCTAssertEqual(loaded.writingSubmissions.count, 1)
    }
}
