import XCTest
import SQLite3
@testable import LumaReaderStudyKit

final class ResourceRegressionTests: XCTestCase {
    private func draft(_ text: String = "Original") -> WritingExamDraftState {
        WritingExamDraftState(id: UUID(), questionID: "q", examTitle: "Test", activePart: .part1,
            part1EssayText: text, part2EssayText: "", remainingSeconds: 1200, elapsedSeconds: 0,
            isPaused: false, isSingleTaskMode: true, lastSavedAt: Date(), containsLegacyNonEnglishNotice: false)
    }
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func rowID(_ file: URL, id: UUID) throws -> Int64 {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(file.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT rowid FROM writing_drafts WHERE id='\(id.uuidString)';", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        return sqlite3_column_int64(statement, 0)
    }
    func testUnchangedSaveKeepsTimestampAndRowIdentity() throws {
        let dir = try folder(); defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("writing.sqlite"), archive = try WritingArchive(url: file)
        let first = draft(), second = draft("Keep")
        try archive.save(drafts: [first.id.uuidString: first, second.id.uuidString: second], submissions: [])
        let stamp = archive.load()?.savedAt
        let row = try rowID(file, id: second.id)
        try archive.save(drafts: [first.id.uuidString: first, second.id.uuidString: second], submissions: [])
        XCTAssertEqual(archive.load()?.savedAt, stamp)
        var changed = first; changed.part1EssayText = "Changed"
        try archive.save(drafts: [first.id.uuidString: changed, second.id.uuidString: second], submissions: [])
        XCTAssertEqual(try rowID(file, id: second.id), row)
        XCTAssertEqual(archive.load()?.drafts[first.id.uuidString]?.part1EssayText, "Changed")
    }
    func testExternalConnectionInvalidatesCachedState() throws {
        let dir = try folder(); defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("writing.sqlite")
        let local = try WritingArchive(url: file), other = try WritingArchive(url: file)
        let original = draft(); var remote = original; remote.part1EssayText = "Remote"
        try local.save(drafts: [original.id.uuidString: original], submissions: [])
        try other.save(drafts: [remote.id.uuidString: remote], submissions: [])
        try local.save(drafts: [original.id.uuidString: original], submissions: [])
        XCTAssertEqual(local.load()?.drafts[original.id.uuidString]?.part1EssayText, "Original")
        try local.save(drafts: [:], submissions: [])
        XCTAssertTrue(try XCTUnwrap(local.load()).drafts.isEmpty)
    }
    func testJSONNoOpDoesNotReplaceFile() throws {
        let dir = try folder(); defer { try? FileManager.default.removeItem(at: dir) }
        let manager = try StudyPersistenceManager(storageDirectory: dir)
        let snapshot = StudyStoreSnapshot()
        try manager.save(snapshot)
        let before = try FileManager.default.attributesOfItem(atPath: manager.fileURL.path)[.systemFileNumber] as? NSNumber
        try manager.save(snapshot)
        let after = try FileManager.default.attributesOfItem(atPath: manager.fileURL.path)[.systemFileNumber] as? NSNumber
        XCTAssertNotNil(before); XCTAssertEqual(before, after)
    }
    func testShortcutsRespectModifiersAndPreserveHideCommand() {
        let command = DictationShortcutPolicy.command
        XCTAssertEqual(DictationShortcutPolicy.action(keyCode: 15, characters: "r", modifiers: command), .replay)
        XCTAssertEqual(DictationShortcutPolicy.action(keyCode: 15, characters: "R", modifiers: command | DictationShortcutPolicy.shift), .slowReplay)
        XCTAssertEqual(DictationShortcutPolicy.action(keyCode: 35, characters: "p", modifiers: command | DictationShortcutPolicy.option), .togglePause)
        XCTAssertEqual(DictationShortcutPolicy.action(keyCode: 123, characters: "", modifiers: command | DictationShortcutPolicy.option), .previous)
        XCTAssertNil(DictationShortcutPolicy.action(keyCode: 4, characters: "h", modifiers: command))
        XCTAssertNil(DictationShortcutPolicy.action(keyCode: 15, characters: "r", modifiers: 0))
        XCTAssertNil(DictationShortcutPolicy.action(keyCode: 15, characters: "r", modifiers: command | DictationShortcutPolicy.control))
    }
}
