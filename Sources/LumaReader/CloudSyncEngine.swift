import Foundation

// One independently written snapshot per device avoids read/modify/write races
// between offline Macs. Providers transport ordinary files through their desktop clients.
enum ReadingDevice {
    static let id: String = {
        let prefs = UserDefaults.standard
        if let existing = prefs.string(forKey: "readingDeviceID"), UUID(uuidString: existing) != nil { return existing }
        let value = UUID().uuidString
        prefs.set(value, forKey: "readingDeviceID")
        return value
    }()
}

struct CloudSyncSnapshot: Codable, Sendable {
    var schemaVersion = 1
    var deviceID: String
    var updatedAt: Date
    var provider: CloudProvider
    var books: [Book]
    var ledger: ReadingLedger
    var collections: LibraryGroups? = nil
}

struct CloudSyncResult: Sendable {
    var books: [Book]
    var ledger: ReadingLedger
    var collections = LibraryGroups()
}

enum CloudSyncEngine {
    static func syncRoot(in directory: URL) -> URL {
        directory.lastPathComponent == "LumaReader" ? directory : directory.appendingPathComponent("LumaReader", isDirectory: true)
    }

    static func mergeLedger(local: ReadingLedger, remote: ReadingLedger) -> ReadingLedger {
        var merged = local.components ?? ["legacy": local.dailySeconds]
        for (device, days) in remote.components ?? ["legacy": remote.dailySeconds] {
            for (day, seconds) in days where seconds.isFinite && seconds >= 0 {
                merged[device, default: [:]][day] = max(merged[device]?[day] ?? 0, seconds)
            }
        }
        var totals: [String: Double] = [:]
        for days in merged.values { for (day, seconds) in days { totals[day, default: 0] += seconds } }
        let resets = (local.resetDays ?? [:]).merging(remote.resetDays ?? [:],uniquingKeysWith:max)
        let sessions = (local.sessions ?? [:]).merging(remote.sessions ?? [:],uniquingKeysWith:{ a,b in a.end >= b.end ? a:b })
        let restored = (local.restoredDays ?? [:]).merging(remote.restoredDays ?? [:],uniquingKeysWith:max)
        return ReadingLedger(dailySeconds:totals,components:merged,sessions:sessions.isEmpty ? nil:sessions,resetDays:resets.isEmpty ? nil:resets,restoredDays:restored.isEmpty ? nil:restored)
    }

    private static func tombstones(_ a: [String: Date]?, _ b: [String: Date]?) -> [String: Date] {
        (a ?? [:]).merging(b ?? [:], uniquingKeysWith: max)
    }

    static func mergeBooks(local: [Book], remote: [Book], provider: CloudProvider) -> [Book] {
        var result: [UUID: Book] = [:]
        for book in local { result[book.id] = book }
        for incoming in remote {
            guard var book = result[incoming.id] else { result[incoming.id] = incoming; continue }
            if (incoming.progressUpdatedAt ?? .distantPast) > (book.progressUpdatedAt ?? .distantPast) {
                book.position = incoming.position
                book.progress = incoming.progress
                book.readerOffset = incoming.readerOffset
                book.readerAnchor = incoming.readerAnchor
                book.progressUpdatedAt = incoming.progressUpdatedAt
            }
            if let shelf = incoming.shelf, shelf.modifiedAt > (book.shelf?.modifiedAt ?? .distantPast) { book.shelf = shelf }
            book.coverFilename = book.coverFilename ?? incoming.coverFilename
            book.lastOpened = max(book.lastOpened, incoming.lastOpened)
            let noteDeletions = tombstones(book.deletedNotes, incoming.deletedNotes)
            let bookmarkDeletions = tombstones(book.deletedBookmarks, incoming.deletedBookmarks)
            book.deletedNotes = noteDeletions.isEmpty ? nil : noteDeletions
            book.deletedBookmarks = bookmarkDeletions.isEmpty ? nil : bookmarkDeletions
            var notes: [UUID: ReadingNote] = [:]
            for note in book.notes + incoming.notes {
                if let old = notes[note.id], (old.modifiedAt ?? old.created) >= (note.modifiedAt ?? note.created) { continue }
                notes[note.id] = note
            }
            book.notes = notes.values.filter {
                (book.deletedNotes?[$0.id.uuidString] ?? .distantPast) < ($0.modifiedAt ?? $0.created)
            }.sorted { $0.created < $1.created }
            var marks: [UUID: ReadingBookmark] = [:]
            for mark in (book.bookmarks ?? []) + (incoming.bookmarks ?? []) { marks[mark.id] = mark }
            let hasBookmarkField = book.bookmarks != nil || incoming.bookmarks != nil
            let mergedMarks = marks.values.filter {
                (book.deletedBookmarks?[$0.id.uuidString] ?? .distantPast) < $0.created
            }.sorted { $0.created < $1.created }
            book.bookmarks = hasBookmarkField ? mergedMarks : nil
            result[book.id] = book
        }
        return result.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    static func managedFilename(_ book: Book) throws -> String {
        guard ["pdf", "epub"].contains(book.kind) else { throw ReaderFailure.message("云端图书类型无效。") }
        return book.id.uuidString + "." + book.kind
    }

    private static func safeLocalFile(_ filename: String, root: URL) throws -> URL {
        guard !filename.isEmpty, filename != ".", filename != "..", !filename.contains("/"), !filename.contains("\\") else {
            throw ReaderFailure.message("云存档包含无效文件名。")
        }
        let candidate = root.appendingPathComponent(filename)
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard candidate.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(resolvedRoot) else {
            throw ReaderFailure.message("云存档包含越界文件路径。")
        }
        return candidate
    }

    private static func copyIfMissing(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { return }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".transfer-" + UUID().uuidString)
        defer { try? fm.removeItem(at: temporary) }
        #if os(macOS)
        try? fm.startDownloadingUbiquitousItem(at: source)
        #endif
        try fm.copyItem(at: source, to: temporary)
        try fm.moveItem(at: temporary, to: destination)
    }

    static func exchange(directory: URL, localRoot: URL, books: [Book], ledger: ReadingLedger,
                         provider: CloudProvider, deviceID: String = ReadingDevice.id, collections: LibraryGroups = LibraryGroups()) throws -> CloudSyncResult {
        guard UUID(uuidString: deviceID) != nil else { throw ReaderFailure.message("设备标识无效。") }
        let fm = FileManager.default
        let root = syncRoot(in: directory)
        let snapshots = root.appendingPathComponent("Devices", isDirectory: true)
        let cloudFiles = root.appendingPathComponent("Books", isDirectory: true)
        let localFiles = localRoot.appendingPathComponent("Books", isDirectory: true)
        let localCovers = localRoot.appendingPathComponent("Covers",isDirectory:true)
        let cloudCovers = root.appendingPathComponent("Covers",isDirectory:true)
        for folder in [snapshots, cloudFiles, localFiles, localCovers, cloudCovers] {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            guard !((try folder.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink ?? false) else {
                throw ReaderFailure.message("请直接选择云盘目录，不要使用符号链接。")
            }
        }
        var mergedBooks = mergeBooks(local: books, remote: [], provider: provider)
        var mergedLedger = mergeLedger(local: ledger, remote: ReadingLedger())
        var mergedCollections = LibraryGroups.merge(local:collections,remote:LibraryGroups())
        var snapshotFiles = try fm.contentsOfDirectory(at: snapshots, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let legacy = root.appendingPathComponent("luma-sync.json")
        if fm.fileExists(atPath: legacy.path) { snapshotFiles.append(legacy) }
        for file in snapshotFiles {
            // A corrupt, unavailable or newer snapshot stops the transaction; never overwrite it.
            let data = try Data(contentsOf: file)
            let snapshot: CloudSyncSnapshot
            do { snapshot = try JSONDecoder().decode(CloudSyncSnapshot.self, from: data) }
            catch { throw ReaderFailure.message("云存档 \(file.lastPathComponent) 无法读取；请等待云盘下载完成或恢复备份。原文件已保留。") }
            guard snapshot.schemaVersion == 1 else { throw ReaderFailure.message("云存档由更新版本创建，请先更新应用。") }
            mergedBooks = mergeBooks(local: mergedBooks, remote: snapshot.books, provider: provider)
            mergedLedger = mergeLedger(local: mergedLedger, remote: snapshot.ledger)
            mergedCollections = LibraryGroups.merge(local:mergedCollections,remote:snapshot.collections ?? LibraryGroups())
        }
        let existing = Dictionary(books.map { ($0.id, $0.filename) }, uniquingKeysWith: { first, _ in first })
        for index in mergedBooks.indices {
            let cloudName = try managedFilename(mergedBooks[index])
            let cloudFile = try safeLocalFile(cloudName, root: cloudFiles)
            let localName = existing[mergedBooks[index].id] ?? cloudName
            let localFile = try safeLocalFile(localName, root: localFiles)
            if !fm.fileExists(atPath: localFile.path) {
                try copyIfMissing(from: cloudFile, to: localFile)
            }
            try copyIfMissing(from: localFile, to: cloudFile)
            if mergedBooks[index].coverFilename != nil {
                let coverName = mergedBooks[index].id.uuidString + ".png"
                let localCover = try safeLocalFile(coverName,root:localCovers)
                let cloudCover = try safeLocalFile(coverName,root:cloudCovers)
                if !fm.fileExists(atPath:localCover.path) { try? copyIfMissing(from:cloudCover,to:localCover) }
                if fm.fileExists(atPath:localCover.path) { try? copyIfMissing(from:localCover,to:cloudCover) }
                mergedBooks[index].coverFilename = fm.fileExists(atPath:localCover.path) ? coverName:nil
            }
            mergedBooks[index].filename = localName
            if mergedBooks[index].cloudProvider == nil { mergedBooks[index].cloudProvider = provider }
        }
        try FontFileSync.exchange(localRoot:localRoot,cloudRoot:root)
        // Publish only after all referenced book and font files have been transferred successfully.
        var publishedBooks = mergedBooks
        for i in publishedBooks.indices { publishedBooks[i].filename = try managedFilename(publishedBooks[i]) }
        try exportMarkdownNotes(for: mergedBooks, in: root)
        let snapshot = CloudSyncSnapshot(deviceID: deviceID, updatedAt: Date(), provider: provider, books: publishedBooks, ledger: mergedLedger, collections:mergedCollections)
        let encoded = try JSONEncoder().encode(snapshot)
        let destination = snapshots.appendingPathComponent(deviceID + ".json")
        if let oldData = try? Data(contentsOf: destination),
           let previous = try? JSONDecoder().decode(CloudSyncSnapshot.self, from: oldData),
           previous.schemaVersion == snapshot.schemaVersion, previous.deviceID == snapshot.deviceID,
           previous.provider == snapshot.provider, previous.books == snapshot.books, previous.ledger == snapshot.ledger, previous.collections == snapshot.collections {
            return CloudSyncResult(books: mergedBooks, ledger: mergedLedger, collections:mergedCollections)
        }
        // Keep the previous valid version outside the scanned directory.
        if fm.fileExists(atPath: destination.path) {
            let backup = root.appendingPathComponent("Backups", isDirectory: true)
            try fm.createDirectory(at: backup, withIntermediateDirectories: true)
            let old = try Data(contentsOf: destination)
            try old.write(to: backup.appendingPathComponent(deviceID + ".previous.json"), options: .atomic)
        }
        if (try? Data(contentsOf: destination)) != encoded { try encoded.write(to: destination, options: .atomic) }
        return CloudSyncResult(books: mergedBooks, ledger: mergedLedger, collections:mergedCollections)
    }

    private static func exportMarkdownNotes(for books: [Book], in root: URL) throws {
        let directory = root.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for book in books {
            let quotes = book.notes.map { note in
                "> " + note.quote.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n" + note.note + "\n"
            }.joined(separator: "\n---\n\n")
            let marks = (book.bookmarks ?? []).map { "- " + $0.title }.joined(separator: "\n")
            let data = Data(("# " + book.title + "\n\n" + quotes + "\n## 书签\n\n" + marks + "\n").utf8)
            let file = try safeLocalFile(book.id.uuidString + ".md", root: directory)
            if (try? Data(contentsOf: file)) != data { try data.write(to: file, options: .atomic) }
        }
    }

}
