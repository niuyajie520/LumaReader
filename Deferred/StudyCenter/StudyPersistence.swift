import Foundation

public final class StudyPersistenceManager: @unchecked Sendable {
    private let fileURL: URL
    private let backupDirectoryURL: URL
    private let lock = NSLock()
    private var recovered = false
    public var recoveryPerformed:Bool {lock.lock();defer{lock.unlock()};return recovered}
    private let policy = ExamEnglishInputPolicy()

    public init(storageDirectory: URL) throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        self.fileURL = storageDirectory.appendingPathComponent("luma_study_store.json")
        self.backupDirectoryURL = storageDirectory.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
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
            guard let data = try? Data(contentsOf:backup), let recovered = try? decoder.decode(StudyStoreSnapshot.self,from:data) else { throw error }
            try rawData.write(to:backupDirectoryURL.appendingPathComponent("damaged-"+UUID().uuidString+".json"),options:.atomic)
            snapshot = recovered
            self.recovered = true
            try data.write(to:fileURL,options:.atomic)
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

        return snapshot
    }

    public func save(_ snapshot: StudyStoreSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        try saveUnlocked(snapshot)
    }

    private func saveUnlocked(_ snapshot: StudyStoreSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        if let previous = try? Data(contentsOf:fileURL) {
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            if (try? decoder.decode(StudyStoreSnapshot.self,from:previous)) != nil {
                try previous.write(to:backupDirectoryURL.appendingPathComponent("last-good.json"),options:.atomic)
            }
        }
        try data.write(to: fileURL, options: .atomic)
    }
}


