import CryptoKit
import Foundation
import Testing
@testable import LumaReaderStudyKit

@Suite("First-launch dictation reset and epoch sync")
struct DictationResetMigrationTests {
    private func fixture() -> (StudyStoreSnapshot, DictationAttemptLog) {
        let word = VocabularyWord(id: "keep-word", word: "keep", definitionZH: "保留", deckID: "keep-deck", deckTitle: "Keep Deck")
        var session = DictationSessionStateMachine(dateString: "2026-11-14", initialWords: [word])
        session.submitAnswer("incorrect")
        let log = session.attemptLogs[0]
        var workspace = StudyWorkspaceState()
        workspace.writingMode = "keep-writing"
        workspace.dictationInput = "unfinished answer"
        workspace.wordInputs = [word.id: "draft"]
        workspace.dictationRoundStartedAt = Date(timeIntervalSince1970: 1_000)
        var snapshot = StudyStoreSnapshot(dictationLogs: [log], stubbornWords: session.sortedStubbornWords,
                                          importedWords: [word], reviewSchedule: [word.id: WordReviewProgress()],
                                          workspace: workspace, dictationSession: session,
                                          dictationSessions: ["keep-deck": session])
        snapshot.meaningUnclearWordIDs = [word.id]
        snapshot.roundMeaningWordIDs = [session.sessionID.uuidString: [word.id]]
        snapshot.suppressedWrongLogIDs = [log.id]
        return (snapshot, log)
    }

    @Test func resetRequiresNewBuildAndVerifiedUniquePrivateBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = fixture().0
        let old = try StudyPersistenceManager(storageDirectory: directory, testBuildNumber: 127)
        try old.save(original)
        let originalBytes = try Data(contentsOf: old.fileURL)
        let unchanged = try old.loadAndMigrateIfNeeded()
        #expect(unchanged.dictationResetEpoch == nil)
        #expect(unchanged.dictationLogs.count == 1)
        #expect(try Data(contentsOf: old.fileURL) == originalBytes)
        let new = try StudyPersistenceManager(storageDirectory: directory, testBuildNumber: 128)
        let reset = try new.loadAndMigrateIfNeeded()
        #expect((reset.dictationResetEpoch ?? 0) > 0)
        #expect(reset.dictationLogs.isEmpty)
        #expect(reset.dictationSession == nil && reset.dictationSessions == nil)
        #expect(reset.stubbornWords.isEmpty && reset.slowReactionWords == nil)
        #expect(reset.reviewSchedule == nil && reset.suppressedWrongLogIDs == nil)
        #expect(reset.meaningUnclearWordIDs == nil && reset.roundMeaningWordIDs == nil && reset.wrongWordMarks == nil)
        #expect(reset.workspace?.dictationInput == "" && reset.workspace?.wordInputs == nil)
        #expect(reset.workspace?.dictationRoundStartedAt == nil)
        #expect(reset.workspace?.writingMode == "keep-writing")
        #expect(reset.importedWords == original.importedWords)
        let backupDir = directory.appendingPathComponent("backups")
        let names = try FileManager.default.contentsOfDirectory(atPath: backupDir.path).filter { $0.hasPrefix("before-dictation-reset-") }
        #expect(names.count == 1)
        guard let backupName = names.first else {
            Issue.record("预期的原始字节备份没有生成")
            return
        }
        let backup = backupDir.appendingPathComponent(backupName)
        #expect(try FileManager.default.attributesOfItem(atPath: backup.path)[.posixPermissions] as? Int == 0o600)
        #expect(try SHA256.hash(data: Data(contentsOf: backup)) == SHA256.hash(data: originalBytes))
        let reloaded = try new.loadAndMigrateIfNeeded()
        #expect(reloaded.dictationResetEpoch == reset.dictationResetEpoch)
        #expect(try FileManager.default.contentsOfDirectory(atPath: backupDir.path).filter { $0.hasPrefix("before-dictation-reset-") }.count == 1)
    }

    @Test func cloudOlderEpochCannotRestoreLogsSessionsOrReview() {
        let (old, _) = fixture()
        var reset = old
        reset.dictationResetEpoch = 1_763_200_000_123
        reset.dictationLogs = []
        reset.dictationSession = nil
        reset.dictationSessions = nil
        reset.stubbornWords = []
        reset.slowReactionWords = nil
        reset.reviewSchedule = nil
        reset.suppressedWrongLogIDs = nil
        reset.meaningUnclearWordIDs = nil
        reset.roundMeaningWordIDs = nil
        reset.workspace?.clearDictationDrafts()
        for merged in [StudyCloudSyncManager.merge(local: reset, remote: old),
                       StudyCloudSyncManager.merge(local: old, remote: reset)] {
            #expect(merged.dictationResetEpoch == reset.dictationResetEpoch)
            #expect(merged.dictationLogs.isEmpty && merged.dictationSessions == nil && merged.dictationSession == nil)
            #expect(merged.stubbornWords.isEmpty && merged.reviewSchedule == nil)
            #expect(merged.meaningUnclearWordIDs == nil && merged.roundMeaningWordIDs == nil)
            #expect(merged.workspace?.dictationInput == "")
            #expect(merged.importedWords == old.importedWords)
        }
        var after = reset
        after.dictationLogs = [fixture().1]
        after.roundMeaningWordIDs = [UUID().uuidString: ["keep-word"]]
        let merged = StudyCloudSyncManager.merge(local: reset, remote: after)
        #expect(merged.dictationLogs.count == 1)
        #expect(merged.roundMeaningWordIDs == after.roundMeaningWordIDs)
    }
}
