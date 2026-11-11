import Foundation
import SQLite3
import CryptoKit

public final class StudyPersistenceManager: @unchecked Sendable {
    public let fileURL: URL
    private let backupDirectoryURL: URL
    private let writingArchive: WritingArchive?
    private let lock = NSLock()
    private var recovered = false
    private var lastWrittenDigest: SHA256.Digest?
    private var lastWrittenModification: Date?
    public var recoveryPerformed:Bool {lock.lock();defer{lock.unlock()};return recovered}
    private var salvagedPaths: [String] = []
    /// 加载时因格式不兼容而跳过的旧条目（JSON 路径），为空表示没有跳过任何内容。
    public var skippedLegacyEntries: [String] {lock.lock();defer{lock.unlock()};return salvagedPaths}

    /// 逐条剔除无法解码的旧条目，直到整体能解码（最多 300 次）。只删除出错的那一个元素，不删除整类数据。
    static func salvageDecode(_ rawData: Data, decoder: JSONDecoder) -> (StudyStoreSnapshot, [String])? {
        guard var root = (try? JSONSerialization.jsonObject(with: rawData)) as? [String: Any] else { return nil }
        var dropped: [String] = []
        for _ in 0..<300 {
            guard let data = try? JSONSerialization.data(withJSONObject: root) else { return nil }
            do {
                return (try decoder.decode(StudyStoreSnapshot.self, from: data), dropped)
            } catch let error as DecodingError {
                let path: [CodingKey]
                switch error {
                case .keyNotFound(_, let context): path = context.codingPath
                case .typeMismatch(_, let context): path = context.codingPath
                case .valueNotFound(_, let context): path = context.codingPath
                case .dataCorrupted(let context): path = context.codingPath
                @unknown default: return nil
                }
                guard let first = path.first else { return nil }
                let k0 = first.stringValue
                if path.count >= 2, var array = root[k0] as? [Any], let index = path[1].intValue, index < array.count {
                    array.remove(at: index); root[k0] = array
                } else if path.count >= 2, var dict = root[k0] as? [String: Any], dict[path[1].stringValue] != nil {
                    dict.removeValue(forKey: path[1].stringValue); root[k0] = dict
                } else if root[k0] != nil {
                    root.removeValue(forKey: k0)
                } else {
                    return nil
                }
                dropped.append(path.prefix(2).map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: "."))
            } catch {
                return nil
            }
        }
        return nil
    }
    private let policy = ExamEnglishInputPolicy()

    public init(storageDirectory: URL) throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        self.fileURL = storageDirectory.appendingPathComponent("luma_study_store.json")
        self.backupDirectoryURL = storageDirectory.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
        self.writingArchive = try? WritingArchive(url: storageDirectory.appendingPathComponent("writing.sqlite"))
    }

    /// Loads the store and executes forward-compatible migration with automatic backup if needed.
    /// Never wipes or overwrites existing user history or legacy drafts.
    public func loadAndMigrateIfNeeded() throws -> StudyStoreSnapshot {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let fresh = StudyStoreSnapshot()
            try saveUnlocked(fresh)
            return fresh
        }

        let rawData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var snapshot: StudyStoreSnapshot
        do { snapshot = try decoder.decode(StudyStoreSnapshot.self, from: rawData) }
        catch {
            let backup = backupDirectoryURL.appendingPathComponent("last-good.json")
            if let data = try? Data(contentsOf:backup), let recovered = try? decoder.decode(StudyStoreSnapshot.self,from:data) {
                try rawData.write(to:backupDirectoryURL.appendingPathComponent("damaged-"+UUID().uuidString+".json"),options:.atomic)
                snapshot = recovered
                self.recovered = true
                try data.write(to:fileURL,options:.atomic)
            } else if let salvage = Self.salvageDecode(rawData, decoder: decoder) {
                let salvaged = salvage.0, dropped = salvage.1
                // 旧版记录里个别条目与新版格式不兼容：只跳过这些条目，其余记录全部保留；原文件完整备份。
                try rawData.write(to:backupDirectoryURL.appendingPathComponent("before-salvage-"+UUID().uuidString+".json"),options:.atomic)
                snapshot = salvaged
                self.recovered = true
                self.salvagedPaths = dropped
            } else {
                throw error
            }
        }

        // Writing is stored in SQLite once available; JSON remains the export/cloud mirror.
        if let archive = writingArchive, let stored = archive.load(),
           !stored.drafts.isEmpty || !stored.submissions.isEmpty {
            // SQLite is authoritative for essays; local JSON intentionally omits them.
            snapshot.activeWritingDrafts = stored.drafts
            snapshot.writingSubmissions = stored.submissions
        } else if let archive = writingArchive {
            // First run (or an older JSON store): seed SQLite from the JSON mirror.
            try? archive.save(drafts: snapshot.activeWritingDrafts, submissions: snapshot.writingSubmissions)
        }

        let upgradeBackup = backupDirectoryURL.appendingPathComponent("before-study-editor-upgrade.json")
        if !FileManager.default.fileExists(atPath: upgradeBackup.path) {
            try? rawData.write(to: upgradeBackup, options: .atomic)
        }

        if snapshot.schemaVersion < StudySchemaVersion.current {
            // 1. Create a timestamped backup before migrating
            let backupName = "luma_study_store_v\(snapshot.schemaVersion.rawValue)_backup_\(Int(Date().timeIntervalSince1970)).json"
            let backupURL = backupDirectoryURL.appendingPathComponent(backupName)
            try rawData.write(to: backupURL, options: .atomic)

            // 2. Migrate v1 -> v2: preserve any legacy drafts containing Chinese characters in `legacyDraftBackups`
            //    and flag `containsLegacyNonEnglishNotice = true` without deleting user text.
            for (qID, var draft) in snapshot.activeWritingDrafts {
                let p1Report = policy.inspectLegacyDraft(draft.part1EssayText)
                let p2Report = policy.inspectLegacyDraft(draft.part2EssayText)
                if p1Report.containsLegacyNonEnglishCharacters || p2Report.containsLegacyNonEnglishCharacters {
                    draft.containsLegacyNonEnglishNotice = true
                    snapshot.activeWritingDrafts[qID] = draft
                    if snapshot.legacyDraftBackups[qID] == nil {
                        snapshot.legacyDraftBackups[qID] = """
                        Part1:
                        \(draft.part1EssayText)

                        Part2:
                        \(draft.part2EssayText)
                        """
                    }
                }
            }

            snapshot.schemaVersion = .current
            try saveUnlocked(snapshot)
        }

        // 上一版为了读出记录而跳过的旧条目：现在格式已兼容，把它们无损合并回来（只做一次）
        var restoredFromBackup = false
        let fm = FileManager.default
        let backups = ((try? fm.contentsOfDirectory(at: backupDirectoryURL, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .sorted { (a, b) in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
        for url in backups where url.lastPathComponent.hasPrefix("before-salvage-") && url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url) {
                var older = try? decoder.decode(StudyStoreSnapshot.self, from: data)
                if older == nil { older = Self.salvageDecode(data, decoder: decoder)?.0 }
                if let older {
                    snapshot = StudyCloudSyncManager.merge(local: snapshot, remote: older)
                    if snapshot.speechService == nil { snapshot.speechService = older.speechService }
                    restoredFromBackup = true
                }
            }
            try? fm.moveItem(at: url, to: backupDirectoryURL.appendingPathComponent("merged-" + url.lastPathComponent))
        }
        // 自然发音服务设置丢失时，从最近的备份里找回（服务地址 / 模型 / 声线；密钥一直在钥匙串里）
        if snapshot.speechService == nil {
            for url in backups where url.pathExtension == "json" {
                guard let data = try? Data(contentsOf: url),
                      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let service = object["speechService"],
                      let serviceData = try? JSONSerialization.data(withJSONObject: service),
                      let decoded = try? decoder.decode(SpeechServiceSettings.self, from: serviceData) else { continue }
                snapshot.speechService = decoded
                restoredFromBackup = true
                break
            }
        }
        if !StudyStoreHygiene.isRunningTests {
            let cleaned = StudyStoreHygiene.removingTestFixtures(snapshot)
            if cleaned != snapshot { snapshot = cleaned; restoredFromBackup = true }
        }
        if restoredFromBackup { try saveUnlocked(snapshot) }

        return snapshot
    }

    public func save(_ snapshot: StudyStoreSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        try saveUnlocked(snapshot)
    }

    private func saveUnlocked(_ snapshot: StudyStoreSnapshot) throws {
        let encoder = JSONEncoder()
        if (snapshot.importedWords?.count ?? 0) <= 200 {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        encoder.dateEncodingStrategy = .iso8601

        // Keep a single long-term copy of essays: SQLite is authoritative. The local JSON
        // snapshot omits drafts/submissions so the same essay is not stored twice. If the
        // archive cannot be written, fall back to keeping them in JSON.
        var stored = snapshot
        var archiveSaved = false
        if let archive = writingArchive {
            do {
                try archive.save(drafts: snapshot.activeWritingDrafts, submissions: snapshot.writingSubmissions)
                archiveSaved = true
            } catch {
                archiveSaved = false
            }
        }
        if archiveSaved {
            stored.activeWritingDrafts = [:]
            stored.writingSubmissions = []
        }
        let data = try encoder.encode(stored)
        let digest = SHA256.hash(data: data)
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modification = attributes?[.modificationDate] as? Date
        if lastWrittenDigest == digest, lastWrittenModification != nil, modification == lastWrittenModification { return }
        let lastGoodURL = backupDirectoryURL.appendingPathComponent("last-good.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let shouldRefreshBackup: Bool = {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: lastGoodURL.path),
                      let modDate = attrs[.modificationDate] as? Date else { return true }
                return Date().timeIntervalSince(modDate) > 300
            }()
            if shouldRefreshBackup {
                try? FileManager.default.removeItem(at: lastGoodURL)
                try? FileManager.default.copyItem(at: fileURL, to: lastGoodURL)
            }
        }
        try data.write(to: fileURL, options: .atomic)
        lastWrittenDigest = digest
        lastWrittenModification = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
    }
}


// MARK: - SQLite archive for writing
//
// Essays are the only study data that benefits from per-record storage, revisions and
// transactional edits. JSON stays the interchange/snapshot format for cloud/export.

final class WritingArchive: @unchecked Sendable {
    struct Loaded {
        var drafts: [String: WritingExamDraftState]
        var submissions: [WritingSubmissionRecord]
        var savedAt: Date?
    }

    private var db: OpaquePointer?
    private let lock = NSLock()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    // Value snapshots share Swift's copy-on-write text/arrays; no duplicate encoded essay blobs.
    private var committedDrafts: [String: WritingExamDraftState]?
    private var committedSubmissions: [String: WritingSubmissionRecord]?
    private var observedDataVersion: Int32?


    init(url: URL) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            throw NSError(domain: "WritingArchive", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法打开作文数据库"])
        }
        db = handle
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("""
        CREATE TABLE IF NOT EXISTS writing_drafts (id TEXT PRIMARY KEY, payload BLOB NOT NULL, updated_at REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS writing_submissions (id TEXT PRIMARY KEY, payload BLOB NOT NULL, submitted_at REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS writing_meta (key TEXT PRIMARY KEY, value TEXT);
        """)
    }

    deinit { if let db { sqlite3_close(db) } }

    private func exec(_ sql: String) throws {
        guard let db, sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "WritingArchive", code: 2, userInfo: [NSLocalizedDescriptionKey: "作文数据库执行失败"])
        }
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    private func dataVersion() throws -> Int32 {
        guard let db else { throw NSError(domain: "WritingArchive", code: 7) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA data_version;", -1, &statement, nil) == SQLITE_OK else { throw NSError(domain: "WritingArchive", code: 7) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw NSError(domain: "WritingArchive", code: 7) }
        return sqlite3_column_int(statement, 0)
    }

    private func ids(in table: String) throws -> Set<String> {
        guard let db else { throw NSError(domain: "WritingArchive", code: 8) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT id FROM \(table);", -1, &statement, nil) == SQLITE_OK else { throw NSError(domain: "WritingArchive", code: 8) }
        defer { sqlite3_finalize(statement) }
        var result: Set<String> = []
        var code = sqlite3_step(statement)
        while code == SQLITE_ROW {
            if let value = sqlite3_column_text(statement, 0) { result.insert(String(cString: value)) }
            code = sqlite3_step(statement)
        }
        guard code == SQLITE_DONE else { throw NSError(domain: "WritingArchive", code: 8) }
        return result
    }

    private func remove(_ ids: Set<String>, from table: String) throws {
        guard !ids.isEmpty, let db else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM \(table) WHERE id=?;", -1, &statement, nil) == SQLITE_OK else { throw NSError(domain: "WritingArchive", code: 9) }
        defer { sqlite3_finalize(statement) }
        for id in ids {
            sqlite3_reset(statement); sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, id, -1, transient)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw NSError(domain: "WritingArchive", code: 9) }
        }
    }

    func save(drafts: [String: WritingExamDraftState], submissions: [WritingSubmissionRecord]) throws {
        lock.lock(); defer { lock.unlock() }
        guard let db else { throw NSError(domain: "WritingArchive", code: 1) }
        let draftMap = Dictionary(drafts.values.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { _, new in new })
        let submissionMap = Dictionary(submissions.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { _, new in new })
        try exec("BEGIN IMMEDIATE;")
        do {
            let version = try dataVersion()
            // Cloud/import code can use a second SQLite connection. Never trust a stale local cache.
            if observedDataVersion != version { committedDrafts = nil; committedSubmissions = nil }
            let existingDrafts: Set<String>
            let existingSubmissions: Set<String>
            if let committedDrafts { existingDrafts = Set(committedDrafts.keys) }
            else { existingDrafts = try ids(in: "writing_drafts") }
            if let committedSubmissions { existingSubmissions = Set(committedSubmissions.keys) }
            else { existingSubmissions = try ids(in: "writing_submissions") }
            let removedDrafts = existingDrafts.subtracting(draftMap.keys)
            let removedSubmissions = existingSubmissions.subtracting(submissionMap.keys)
            let changedDrafts = draftMap.filter { committedDrafts?[$0.key] != $0.value }
            let changedSubmissions = submissionMap.filter { committedSubmissions?[$0.key] != $0.value }
            try remove(removedDrafts, from: "writing_drafts")
            try remove(removedSubmissions, from: "writing_submissions")
            let recordEncoder = encoder()
            let draftSQL = "INSERT INTO writing_drafts(id,payload,updated_at) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at=excluded.updated_at WHERE writing_drafts.payload != excluded.payload;"
            var draftStatement: OpaquePointer?
            guard sqlite3_prepare_v2(db, draftSQL, -1, &draftStatement, nil) == SQLITE_OK else { throw NSError(domain: "WritingArchive", code: 3) }
            defer { sqlite3_finalize(draftStatement) }
            for (id, draft) in changedDrafts {
                let data = try recordEncoder.encode(draft)
                sqlite3_reset(draftStatement); sqlite3_clear_bindings(draftStatement)
                sqlite3_bind_text(draftStatement, 1, id, -1, transient)
                data.withUnsafeBytes { sqlite3_bind_blob(draftStatement, 2, $0.baseAddress, Int32(data.count), transient) }
                sqlite3_bind_double(draftStatement, 3, draft.lastSavedAt.timeIntervalSince1970)
                guard sqlite3_step(draftStatement) == SQLITE_DONE else { throw NSError(domain: "WritingArchive", code: 4) }
            }
            let submissionSQL = "INSERT INTO writing_submissions(id,payload,submitted_at) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,submitted_at=excluded.submitted_at WHERE writing_submissions.payload != excluded.payload;"
            var submissionStatement: OpaquePointer?
            guard sqlite3_prepare_v2(db, submissionSQL, -1, &submissionStatement, nil) == SQLITE_OK else { throw NSError(domain: "WritingArchive", code: 5) }
            defer { sqlite3_finalize(submissionStatement) }
            for (id, item) in changedSubmissions {
                let data = try recordEncoder.encode(item)
                sqlite3_reset(submissionStatement); sqlite3_clear_bindings(submissionStatement)
                sqlite3_bind_text(submissionStatement, 1, id, -1, transient)
                data.withUnsafeBytes { sqlite3_bind_blob(submissionStatement, 2, $0.baseAddress, Int32(data.count), transient) }
                sqlite3_bind_double(submissionStatement, 3, item.submittedAt.timeIntervalSince1970)
                guard sqlite3_step(submissionStatement) == SQLITE_DONE else { throw NSError(domain: "WritingArchive", code: 6) }
            }
            if !removedDrafts.isEmpty || !removedSubmissions.isEmpty || !changedDrafts.isEmpty || !changedSubmissions.isEmpty {
                let stamp = String(Date().timeIntervalSince1970)
                try exec("INSERT OR REPLACE INTO writing_meta(key,value) VALUES('saved_at','\(stamp)');")
            }
            try exec("COMMIT;")
            committedDrafts = draftMap; committedSubmissions = submissionMap; observedDataVersion = version
        } catch {
            try? exec("ROLLBACK;")
            committedDrafts = nil; committedSubmissions = nil; observedDataVersion = nil
            throw error
        }
    }

    func load() -> Loaded? {
        lock.lock(); defer { lock.unlock() }
        guard let db else { return nil }
        var drafts: [String: WritingExamDraftState] = [:]
        var submissions: [WritingSubmissionRecord] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT payload FROM writing_drafts;", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let bytes = sqlite3_column_blob(stmt, 0) else { continue }
                let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))
                if let draft = try? decoder().decode(WritingExamDraftState.self, from: data) {
                    drafts[draft.id.uuidString] = draft
                }
            }
        }
        if sqlite3_prepare_v2(db, "SELECT payload FROM writing_submissions;", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let bytes = sqlite3_column_blob(stmt, 0) else { continue }
                let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 0)))
                if let record = try? decoder().decode(WritingSubmissionRecord.self, from: data) {
                    submissions.append(record)
                }
            }
        }
        var savedAt: Date?
        if sqlite3_prepare_v2(db, "SELECT value FROM writing_meta WHERE key='saved_at';", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0),
               let value = Double(String(cString: text)) {
                savedAt = Date(timeIntervalSince1970: value)
            }
        }
        return Loaded(drafts: drafts, submissions: submissions, savedAt: savedAt)
    }
}

// MARK: - Point 4.4: Cloud Drive Sync Manager for Study Center (`luma_study_store.json`)
// Synchronizes custom vocabulary decks, stubborn words, slow reaction words, dictation logs,
// active writing drafts, writing submissions, and revisions across iCloud Drive, OneDrive, and Google Drive.

public enum StudyCloudSyncManager {
    public static let customDirectoriesDefaultsKey = "luma.studyCloudSyncDirectories"
    public static let lastSyncSummaryDefaultsKey = "luma.studyCloudLastSyncSummary"

    /// Losslessly merges two `StudyStoreSnapshot` instances (local and cloud) by unioning
    /// vocabulary decks, logs, stubborn words, slow reaction words, submissions, and selecting newer timestamps for drafts/revisions.
    public static func merge(local: StudyStoreSnapshot, remote: StudyStoreSnapshot) -> StudyStoreSnapshot {
        var merged = local
        merged.installedVocabularyPackIDs = Array(Set((local.installedVocabularyPackIDs ?? []) + (remote.installedVocabularyPackIDs ?? []))).sorted()

        // 1. Imported Vocabulary Words (union by deckID + word.lowercased())
        var wordMap: [String: VocabularyWord] = [:]
        var orderedWords: [VocabularyWord] = []
        for w in (local.importedWords ?? []) + (remote.importedWords ?? []) {
            let key = "\(w.deckID)|\(w.word.lowercased())|\(w.definitionZH)"
            if wordMap[key] == nil {
                wordMap[key] = w
                orderedWords.append(w)
            }
        }
        if !orderedWords.isEmpty {
            merged.importedWords = orderedWords
        }

        // 2. Stubborn Words (union by wordID + dateString, keeping max errorCount)
        var stubbornMap: [String: StubbornWordRecord] = [:]
        for rec in local.stubbornWords + remote.stubbornWords {
            let key = "\(rec.wordID)|\(rec.dateString)"
            if let existing = stubbornMap[key] {
                if rec.errorCount > existing.errorCount {
                    stubbornMap[key] = rec
                }
            } else {
                stubbornMap[key] = rec
            }
        }
        merged.stubbornWords = stubbornMap.values.sorted {
            $0.errorCount != $1.errorCount ? $0.errorCount > $1.errorCount : $0.word < $1.word
        }

        // 2b. Slow Reaction Words (union by wordID, keeping max slowCount & maxReactionSeconds)
        var slowMap: [String: SlowReactionWordRecord] = [:]
        for rec in (local.slowReactionWords ?? []) + (remote.slowReactionWords ?? []) {
            if var existing = slowMap[rec.wordID] {
                existing.slowCount = max(existing.slowCount, rec.slowCount)
                existing.maxReactionSeconds = max(existing.maxReactionSeconds, rec.maxReactionSeconds)
                if rec.updatedAt > existing.updatedAt {
                    existing.lastReactionSeconds = rec.lastReactionSeconds
                    existing.updatedAt = rec.updatedAt
                    existing.dateString = rec.dateString
                }
                if let rBest = rec.bestReactionSeconds {
                    existing.bestReactionSeconds = min(existing.bestReactionSeconds ?? rBest, rBest)
                }
                slowMap[rec.wordID] = existing
            } else {
                slowMap[rec.wordID] = rec
            }
        }
        if !slowMap.isEmpty {
            merged.slowReactionWords = slowMap.values.sorted { $0.lastReactionSeconds > $1.lastReactionSeconds }
        }

        // 2c. Daily Reading Seconds (keep max seconds per date)
        var readingMap = local.dailyReadingSeconds ?? [:]
        for (dateKey, secs) in (remote.dailyReadingSeconds ?? [:]) {
            readingMap[dateKey] = max(readingMap[dateKey, default: 0], secs)
        }
        if !readingMap.isEmpty {
            merged.dailyReadingSeconds = readingMap
        }

        // 3. Dictation Attempt Logs (union by ID, sorted chronologically)
        var seenLogIDs = Set<UUID>()
        var combinedLogs: [DictationAttemptLog] = []
        for log in local.dictationLogs + remote.dictationLogs {
            if seenLogIDs.insert(log.id).inserted {
                combinedLogs.append(log)
            }
        }
        combinedLogs.sort { $0.timestamp < $1.timestamp }
        merged.dictationLogs = combinedLogs

        // 4. Review Schedule (keep higher stage or later dueAt per wordID)
        var schedule = local.reviewSchedule ?? [:]
        for (wordID, remoteProg) in (remote.reviewSchedule ?? [:]) {
            if let localProg = schedule[wordID] {
                if remoteProg.stage > localProg.stage || (remoteProg.stage == localProg.stage && remoteProg.dueAt > localProg.dueAt) {
                    schedule[wordID] = remoteProg
                }
            } else {
                schedule[wordID] = remoteProg
            }
        }
        if !schedule.isEmpty {
            merged.reviewSchedule = schedule
        }

        // 5. Active Writing Drafts (keep newer lastSavedAt per draft key)
        var drafts = local.activeWritingDrafts
        for (key, remoteDraft) in remote.activeWritingDrafts {
            if let localDraft = drafts[key] {
                if remoteDraft.lastSavedAt > localDraft.lastSavedAt {
                    drafts[key] = remoteDraft
                }
            } else {
                drafts[key] = remoteDraft
            }
        }
        merged.activeWritingDrafts = drafts

        // 6. Writing Submissions (union by ID; prefer entry with non-nil aiEvaluation)
        var subMap: [UUID: WritingSubmissionRecord] = [:]
        for sub in local.writingSubmissions + remote.writingSubmissions {
            if let existing = subMap[sub.id] {
                if existing.aiEvaluation == nil && sub.aiEvaluation != nil {
                    subMap[sub.id] = sub
                }
            } else {
                subMap[sub.id] = sub
            }
        }
        merged.writingSubmissions = subMap.values.sorted { $0.submittedAt > $1.submittedAt }

        // 7. Writing Revisions (union by ID, keeping newer updatedAt)
        var revMap: [UUID: WritingRevision] = [:]
        for rev in (local.writingRevisions ?? []) + (remote.writingRevisions ?? []) {
            if let existing = revMap[rev.id] {
                if rev.updatedAt > existing.updatedAt {
                    revMap[rev.id] = rev
                }
            } else {
                revMap[rev.id] = rev
            }
        }
        if !revMap.isEmpty {
            merged.writingRevisions = revMap.values.sorted { $0.updatedAt > $1.updatedAt }
        }

        // 8. Dictation Sessions per Deck (keep session with more progress)
        var sessions = local.dictationSessions ?? [:]
        for (key, remoteSess) in (remote.dictationSessions ?? [:]) {
            if let localSess = sessions[key] {
                if remoteSess.completedWordIDs.count > localSess.completedWordIDs.count
                    || (remoteSess.completedWordIDs.count == localSess.completedWordIDs.count && remoteSess.attemptLogs.count > localSess.attemptLogs.count) {
                    sessions[key] = remoteSess
                }
            } else {
                sessions[key] = remoteSess
            }
        }
        if !sessions.isEmpty {
            merged.dictationSessions = sessions
        }

        return merged
    }

    /// Discovers connected cloud drive directories (iCloud Drive, OneDrive, Google Drive, plus any user-configured folders).
    public static func discoverActiveCloudStudyDirectories(additionalRoots: [URL] = []) -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var candidates: [URL] = additionalRoots

        if let savedPaths = UserDefaults.standard.stringArray(forKey: customDirectoriesDefaultsKey) {
            for p in savedPaths where !p.isEmpty {
                candidates.append(URL(fileURLWithPath: p, isDirectory: true))
            }
        }

        // 1. iCloud Drive
        let iCloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if fm.fileExists(atPath: iCloudDocs.path) {
            candidates.append(iCloudDocs.appendingPathComponent("LumaReader", isDirectory: true))
        }

        // 2. CloudStorage (OneDrive, Google Drive, Dropbox, Box)
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for entry in entries {
                let name = entry.lastPathComponent.lowercased()
                if name.contains("onedrive") || name.contains("googledrive") || name.contains("google drive") || name.contains("dropbox") {
                    let myDrive = entry.appendingPathComponent("My Drive", isDirectory: true)
                    if fm.fileExists(atPath: myDrive.path) {
                        candidates.append(myDrive.appendingPathComponent("LumaReader", isDirectory: true))
                    } else {
                        candidates.append(entry.appendingPathComponent("LumaReader", isDirectory: true))
                    }
                }
            }
        }

        var uniqueDirs: [URL] = []
        var seen = Set<String>()
        for dir in candidates {
            let studyDir = dir.lastPathComponent == "StudyCenter" ? dir : dir.appendingPathComponent("StudyCenter", isDirectory: true)
            let standardized = studyDir.standardizedFileURL.path
            if seen.insert(standardized).inserted {
                uniqueDirs.append(studyDir)
            }
        }
        return uniqueDirs
    }

    public static func registerCloudRoot(_ url: URL) {
        var existing = UserDefaults.standard.stringArray(forKey: customDirectoriesDefaultsKey) ?? []
        let path = url.standardizedFileURL.path
        if !existing.contains(path) {
            existing.append(path)
            UserDefaults.standard.set(existing, forKey: customDirectoriesDefaultsKey)
        }
    }

    /// Synchronizes the local `StudyStoreSnapshot` with all discovered cloud directories.
    @discardableResult
    public static func sync(
        localSnapshot: StudyStoreSnapshot,
        localPersistence: StudyPersistenceManager?,
        cloudRoots: [URL] = []
    ) -> (merged: StudyStoreSnapshot, syncedDirectories: [URL]) {
        var targets = discoverActiveCloudStudyDirectories(additionalRoots: cloudRoots)
        // 测试进程绝不能读写你真实的 iCloud / OneDrive / Google Drive 学习记录，只允许测试显式传入的目录
        if StudyStoreHygiene.isRunningTests {
            targets = targets.filter { t in cloudRoots.contains { t.standardizedFileURL.path.hasPrefix($0.standardizedFileURL.path) } }
        }
        guard !targets.isEmpty else { return (localSnapshot, []) }

        var current = localSnapshot
        var syncedDirs: [URL] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // Pass 1: Pull and merge from all available cloud mirrors
        for dir in targets {
            let storeFile = dir.appendingPathComponent("luma_study_store.json")
            if let data = try? Data(contentsOf: storeFile),
               let remoteSnap = try? decoder.decode(StudyStoreSnapshot.self, from: data) {
                current = merge(local: current, remote: remoteSnap)
            }
        }

        if !StudyStoreHygiene.isRunningTests { current = StudyStoreHygiene.removingTestFixtures(current) }

        // Pass 2: Write unified snapshot back to local persistence and all cloud mirrors
        if let localPersistence {
            try? localPersistence.save(current)
        }
        if let encoded = try? encoder.encode(current) {
            for dir in targets {
                do {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let storeFile = dir.appendingPathComponent("luma_study_store.json")
                    try encoded.write(to: storeFile, options: .atomic)
                    syncedDirs.append(dir)
                } catch {
                    continue
                }
            }
        }

        if !syncedDirs.isEmpty {
            let names = syncedDirs.map { $0.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent }.joined(separator: ", ")
            UserDefaults.standard.set("已同步学习数据至云盘 (\(names))", forKey: lastSyncSummaryDefaultsKey)
        }

        return (current, syncedDirs)
    }
}

/// 之前的测试曾把示例草稿同步进真实云盘记录；这里识别并清除这些固定的测试文本（只匹配完全相同的测试句子）。
public enum StudyStoreHygiene {
    public static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil || env["SWIFT_TESTING_ENABLED"] != nil { return true }
        let name = ProcessInfo.processInfo.processName.lowercased()
        return name.contains("xctest") || name.contains("packagetests") || name.hasSuffix("tests")
    }

    static let fixtureTexts: Set<String> = [
        "Discard these changes.", "Legacy original text.", "Original unchanged draft.", "Saved revised draft.",
        "teh new draft", "teh saved essay", "original draft", "new draft",
        "The chart illustrates urban electricity trends.",
        "In 2010, Metropolis A consumed 450 GWh of electricity."
    ]

    static let fixtureDeckIDs: Set<String> = ["vocab_daily", "fixture", "custom", "d1", "d"]
    static let fixtureWordIDs: Set<String> = ["vw-001", "vw-002", "vw-003", "vw-004", "vw-005", "w1", "w2", "lat-1", "lat-2"]

    public static func removingTestFixtures(_ snapshot: StudyStoreSnapshot) -> StudyStoreSnapshot {
        var s = snapshot
        func isFixture(_ p1: String, _ p2: String) -> Bool {
            let a = p1.trimmingCharacters(in: .whitespacesAndNewlines), b = p2.trimmingCharacters(in: .whitespacesAndNewlines)
            return fixtureTexts.contains(a) && (b.isEmpty || fixtureTexts.contains(b))
        }
        s.activeWritingDrafts = s.activeWritingDrafts.filter { !isFixture($0.value.part1EssayText, $0.value.part2EssayText) }
        s.writingSubmissions.removeAll { isFixture($0.part1EssayText, $0.part2EssayText) }
        if let imported = s.importedWords {
            let filtered = imported.filter { !fixtureDeckIDs.contains($0.deckID) && !fixtureWordIDs.contains($0.id) }
            s.importedWords = filtered
        }
        s.dictationLogs.removeAll { fixtureDeckIDs.contains($0.deckID) || fixtureWordIDs.contains($0.wordID) }
        s.stubbornWords.removeAll { fixtureDeckIDs.contains($0.sourceDeckID) || fixtureWordIDs.contains($0.wordID) }
        s.slowReactionWords?.removeAll { fixtureDeckIDs.contains($0.sourceDeckID) || fixtureWordIDs.contains($0.wordID) }
        if let sessions = s.dictationSessions {
            s.dictationSessions = sessions.filter { key, sess in
                let isFixtureKey = fixtureDeckIDs.contains { key.hasSuffix("|" + $0) }
                let hasFixtureWord = sess.pendingQueue.contains { fixtureDeckIDs.contains($0.deckID) || fixtureWordIDs.contains($0.id) }
                return !isFixtureKey && !hasFixtureWord
            }
        }
        if let sess = s.dictationSession {
            let hasFixtureWord = sess.pendingQueue.contains { fixtureDeckIDs.contains($0.deckID) || fixtureWordIDs.contains($0.id) }
                || sess.attemptLogs.contains { fixtureDeckIDs.contains($0.deckID) || fixtureWordIDs.contains($0.wordID) }
            if hasFixtureWord {
                s.dictationSession = nil
            }
        }
        if let sel = s.workspace?.selectedDeckID, fixtureDeckIDs.contains(sel) {
            s.workspace?.selectedDeckID = nil
        }
        return s
    }
}
