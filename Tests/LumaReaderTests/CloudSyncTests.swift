import Foundation
import Testing
@testable import LumaReader

struct CloudSyncTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func offlineNotesBookmarksAndDeletionMerge() throws {
        var a = Book(title: "Book", filename: "book.epub", kind: "epub")
        let first = ReadingNote(quote: "first", ink: .yellow)
        let second = ReadingNote(quote: "second", ink: .pink)
        let mark = ReadingBookmark(title: "Chapter", position: 3, offset: 0.4)
        a.notes = [first]; a.bookmarks = [mark]
        var b = a; b.notes = [second]; b.bookmarks = []
        let merged = CloudSyncEngine.mergeBooks(local: [a], remote: [b], provider: .iCloud)[0]
        #expect(merged.notes.count == 2)
        #expect(merged.bookmarks?.count == 1)
        var deleted = merged
        deleted.notes.removeAll { $0.id == first.id }
        deleted.deletedNotes = [first.id.uuidString: Date().addingTimeInterval(1)]
        deleted.bookmarks = []
        deleted.deletedBookmarks = [mark.id.uuidString: Date().addingTimeInterval(1)]
        let reconciled = CloudSyncEngine.mergeBooks(local: [a], remote: [deleted], provider: .iCloud)[0]
        #expect(reconciled.notes.count == 1)
        #expect(reconciled.notes.first?.id == second.id)
        #expect(reconciled.bookmarks?.isEmpty == true)
        let repeated = CloudSyncEngine.mergeBooks(local: [reconciled], remote: [a], provider: .iCloud)[0]
        #expect(repeated.notes.count == 1)
        #expect(repeated.bookmarks?.isEmpty == true)
    }

    @Test func newestEditsProgressAndUndoSurvive() {
        let early = Date(timeIntervalSince1970: 10)
        let late = Date(timeIntervalSince1970: 30)
        var a = Book(title: "Book", filename: "book.pdf", kind: "pdf")
        var note = ReadingNote(quote: "q", ink: .yellow); note.created = early
        a.notes = [note]; a.position = 8; a.progressUpdatedAt = early
        var b = a; b.notes[0].note = "edited"; b.notes[0].modifiedAt = late
        b.position = 2; b.readerOffset = 0.7; b.progressUpdatedAt = late
        a.deletedNotes = [note.id.uuidString: Date(timeIntervalSince1970: 20)]
        let merged = CloudSyncEngine.mergeBooks(local: [a], remote: [b], provider: .oneDrive)[0]
        #expect(merged.notes.first?.note == "edited")
        #expect(merged.position == 2)
        #expect(merged.readerOffset == 0.7)
    }

    @Test func deviceCountersAddWithoutDoubleCountingAndMigrateOldTotals() {
        let a = ReadingLedger(dailySeconds: ["2026-11-05": 100], components: ["A": ["2026-11-05": 100]])
        let b = ReadingLedger(dailySeconds: ["2026-11-05": 200], components: ["B": ["2026-11-05": 200]])
        let merged = CloudSyncEngine.mergeLedger(local: a, remote: b)
        #expect(merged.dailySeconds["2026-11-05"] == 300)
        #expect(CloudSyncEngine.mergeLedger(local: merged, remote: a) == merged)
        #expect(CloudSyncEngine.mergeLedger(local: b, remote: a) == merged)
        let old = ReadingLedger(dailySeconds: ["2026-11-04": 60])
        let migrated = CloudSyncEngine.mergeLedger(local: old, remote: old)
        #expect(migrated.dailySeconds["2026-11-04"] == 60)
    }

    @Test func bookFilesAndAnnotationsTransferBetweenDevices() throws {
        let base = try directory(); defer { try? FileManager.default.removeItem(at: base) }
        let cloud = base.appendingPathComponent("cloud")
        let first = base.appendingPathComponent("first")
        let second = base.appendingPathComponent("second")
        try FileManager.default.createDirectory(at: first.appendingPathComponent("Books"), withIntermediateDirectories: true)
        var book = Book(title: "Same / title", filename: "local.epub", kind: "epub")
        book.notes = [ReadingNote(quote: "同步 📖", ink: .purple)]
        book.coverFilename = book.id.uuidString + ".png"
        try FileManager.default.createDirectory(at:first.appendingPathComponent("Covers"),withIntermediateDirectories:true)
        try Data("cover-fixture".utf8).write(to:first.appendingPathComponent("Covers").appendingPathComponent(book.coverFilename!))
        book.bookmarks = [ReadingBookmark(title: "Bookmark", position: 2, offset: 0.3)]
        try Data("book-content".utf8).write(to: first.appendingPathComponent("Books/local.epub"))
        let deviceA = UUID().uuidString, deviceB = UUID().uuidString
        _ = try CloudSyncEngine.exchange(directory: cloud, localRoot: first, books: [book], ledger: ReadingLedger(), provider: .iCloud, deviceID: deviceA)
        let result = try CloudSyncEngine.exchange(directory: cloud, localRoot: second, books: [], ledger: ReadingLedger(), provider: .iCloud, deviceID: deviceB)
        #expect(result.books.count == 1)
        #expect(result.books[0].id == book.id)
        #expect(result.books[0].notes == book.notes)
        #expect(result.books[0].bookmarks == book.bookmarks)
        let downloadedCover = try Data(contentsOf:second.appendingPathComponent("Covers").appendingPathComponent(result.books[0].coverFilename!))
        #expect(downloadedCover == Data("cover-fixture".utf8))
        let downloaded = try Data(contentsOf: second.appendingPathComponent("Books").appendingPathComponent(result.books[0].filename))
        #expect(downloaded == Data("book-content".utf8))
        var edited = result.books
        edited[0].notes[0].note = "Second device edit"
        edited[0].notes[0].modifiedAt = Date()
        let twice = try CloudSyncEngine.exchange(directory: cloud, localRoot: second, books: edited, ledger: result.ledger, provider: .iCloud, deviceID: deviceB)
        #expect(twice.books.count == 1)
        #expect(FileManager.default.fileExists(atPath: cloud.appendingPathComponent("LumaReader/Backups/" + deviceB + ".previous.json").path))
    }

    @Test func entireLibraryPreservesEveryAnnotationAndBookmark() throws {
        let base = try directory(); defer { try? FileManager.default.removeItem(at:base) }
        let cloud = base.appendingPathComponent("cloud")
        let first = base.appendingPathComponent("first")
        let second = base.appendingPathComponent("second")
        try FileManager.default.createDirectory(at:first.appendingPathComponent("Books"),withIntermediateDirectories:true)
        var books:[Book] = []
        for index in 0..<4 {
            let kind = index.isMultiple(of:2) ? "epub":"pdf"
            var book = Book(title:"Book \(index)",filename:"book-\(index)."+kind,kind:kind)
            for position in 0..<120 {
                var note = ReadingNote(quote:"全文批注 📖 \(position)",ink:Ink.allCases[position % Ink.allCases.count])
                note.note = "笔记 \(position)"; note.chapter = position % 12
                if kind == "epub" { note.start = position*10; note.end = position*10+8 }
                else { note.rects = [PageRect(page:position,x:12,y:20,width:80,height:18)] }
                book.notes.append(note)
            }
            book.bookmarks = (0..<120).map { ReadingBookmark(title:"Bookmark \($0)",position:$0,offset:0.4) }
            try Data("source-\(index)".utf8).write(to:first.appendingPathComponent("Books").appendingPathComponent(book.filename))
            books.append(book)
        }
        _ = try CloudSyncEngine.exchange(directory:cloud,localRoot:first,books:books,ledger:ReadingLedger(),provider:.oneDrive,deviceID:"00000000-0000-4000-8000-000000000001")
        let result = try CloudSyncEngine.exchange(directory:cloud,localRoot:second,books:[],ledger:ReadingLedger(),provider:.oneDrive,deviceID:"00000000-0000-4000-8000-000000000002")
        #expect(result.books.count == books.count)
        for expected in books {
            let actual = try #require(result.books.first { $0.id == expected.id })
            #expect(actual.notes == expected.notes)
            #expect(actual.bookmarks == expected.bookmarks)
            #expect(try Data(contentsOf:second.appendingPathComponent("Books").appendingPathComponent(actual.filename)) == Data(contentsOf:first.appendingPathComponent("Books").appendingPathComponent(expected.filename)))
        }
    }

    @Test func corruptSnapshotIsPreservedAndStopsPublication() throws {
        let base = try directory(); defer { try? FileManager.default.removeItem(at: base) }
        let cloud = base.appendingPathComponent("cloud")
        let snapshots = cloud.appendingPathComponent("LumaReader/Devices")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        let file = snapshots.appendingPathComponent("broken.json")
        let bad = Data("unfinished-cloud-download".utf8); try bad.write(to: file)
        let device = UUID().uuidString
        var rejected = false
        do { _ = try CloudSyncEngine.exchange(directory: cloud, localRoot: base.appendingPathComponent("local"), books: [], ledger: ReadingLedger(), provider: .googleDrive, deviceID: device) }
        catch { rejected = true }
        #expect(rejected)
        #expect(try Data(contentsOf: file) == bad)
        #expect(!FileManager.default.fileExists(atPath: snapshots.appendingPathComponent(device + ".json").path))
    }

    @Test func missingBookDoesNotPublishSuccessfulSnapshot() throws {
        let base = try directory(); defer { try? FileManager.default.removeItem(at: base) }
        let cloud = base.appendingPathComponent("cloud")
        let device = UUID().uuidString
        let book = Book(title: "Missing", filename: "missing.pdf", kind: "pdf")
        var rejected = false
        do { _ = try CloudSyncEngine.exchange(directory: cloud, localRoot: base.appendingPathComponent("local"), books: [book], ledger: ReadingLedger(), provider: .iCloud, deviceID: device) }
        catch { rejected = true }
        #expect(rejected)
        #expect(!FileManager.default.fileExists(atPath: cloud.appendingPathComponent("LumaReader/Devices/" + device + ".json").path))
    }

    @Test func unsafeLocalFilenameIsRejected() throws {
        let base = try directory(); defer { try? FileManager.default.removeItem(at: base) }
        let book = Book(title: "Unsafe", filename: "../outside.pdf", kind: "pdf")
        var rejected = false
        do { _ = try CloudSyncEngine.exchange(directory: base.appendingPathComponent("cloud"), localRoot: base.appendingPathComponent("local"), books: [book], ledger: ReadingLedger(), provider: .iCloud) }
        catch { rejected = true }
        #expect(rejected)
    }

    @Test func oldBookJSONStillLoadsWithoutNewSyncFields() throws {
        let original = Book(title: "Old", filename: "old.pdf", kind: "pdf")
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        for key in ["bookmarks", "deletedNotes", "deletedBookmarks", "progressUpdatedAt", "readerOffset", "cloudProvider"] { object.removeValue(forKey: key) }
        let restored = try JSONDecoder().decode(Book.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.title == "Old")
        #expect(restored.bookmarks == nil)
        #expect(restored.notes.isEmpty)
    }

    @Test func noChangesDoNotRewriteSnapshotAndSameTitlesKeepSeparateFiles() throws {
        let base = try directory(); defer { try? FileManager.default.removeItem(at: base) }
        let local = base.appendingPathComponent("local")
        let files = local.appendingPathComponent("Books")
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        let a = Book(title: "Same", filename: "a.pdf", kind: "pdf")
        let b = Book(title: "Same", filename: "b.pdf", kind: "pdf")
        try Data("first".utf8).write(to: files.appendingPathComponent("a.pdf"))
        try Data("second".utf8).write(to: files.appendingPathComponent("b.pdf"))
        let cloud = base.appendingPathComponent("cloud")
        let device = UUID().uuidString
        let first = try CloudSyncEngine.exchange(directory: cloud, localRoot: local, books: [a,b], ledger: ReadingLedger(), provider: .iCloud, deviceID: device)
        let snapshot = cloud.appendingPathComponent("LumaReader/Devices/" + device + ".json")
        let before = try Data(contentsOf: snapshot)
        _ = try CloudSyncEngine.exchange(directory: cloud, localRoot: local, books: first.books, ledger: first.ledger, provider: .iCloud, deviceID: device)
        #expect(try Data(contentsOf: snapshot) == before)
        let copyA = try Data(contentsOf: cloud.appendingPathComponent("LumaReader/Books/" + a.id.uuidString + ".pdf"))
        let copyB = try Data(contentsOf: cloud.appendingPathComponent("LumaReader/Books/" + b.id.uuidString + ".pdf"))
        #expect(copyA == Data("first".utf8))
        #expect(copyB == Data("second".utf8))
    }

}
