import Foundation
import Testing
@testable import LumaReaderStudyKit

@Suite("Study integration persistence and dictation")
struct StudyIntegrationTests {
    @MainActor @Test func reopeningPreservesQueueHistoryAndVerbatimDraft() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        var snapshot = StudyStoreSnapshot()
        var session = DictationSessionStateMachine(dateString:"2026-11-07",initialWords:LumaStudyCenterHostView.builtInVocabularyWords)
        session.submitAnswer("wrong")
        snapshot.dictationSession = session; snapshot.dictationLogs = session.attemptLogs
        let draft = WritingExamDraftState(id:UUID(),questionID:"fixture",examTitle:"Fixture",activePart:.part2,part1EssayText:"teh enviroment, unchanged!",part2EssayText:"Don't fix -- my spelling.",remainingSeconds:3500,elapsedSeconds:100,isPaused:false,isSingleTaskMode:false,lastSavedAt:Date(timeIntervalSince1970:100),containsLegacyNonEnglishNotice:false)
        snapshot.activeWritingDrafts[draft.questionID] = draft
        try StudyPersistenceManager(storageDirectory:dir).save(snapshot)
        let loaded = try StudyPersistenceManager(storageDirectory:dir).loadAndMigrateIfNeeded()
        #expect(loaded.activeWritingDrafts == snapshot.activeWritingDrafts)
        #expect(loaded.dictationSession?.pendingQueue == session.pendingQueue)
        #expect(loaded.dictationSession?.sessionErrorCounts == session.sessionErrorCounts)
        #expect(loaded.dictationLogs.first?.userTyped == "wrong")
        #expect(loaded.writingSubmissions.isEmpty)
    }
    @MainActor @Test func dailyErrorsSurviveNewSessionAndReviewStaysIndependent() {
        let words = [LumaStudyCenterHostView.builtInVocabularyWords[0]]
        var first = DictationSessionStateMachine(dateString:"2026-11-07",initialWords:words)
        for _ in 0..<4 { first.submitAnswer("wrong") }
        var resumed = DictationSessionStateMachine(dateString:"2026-11-07",initialWords:words,previousLogs:first.attemptLogs)
        resumed.submitAnswer("wrong")
        #expect(resumed.sortedStubbornWords.first?.errorCount == 5)
        #expect(resumed.isSessionFinished)
        let review = DictationSessionStateMachine(mode:.wrongWordReview,dateString:"2026-11-07",initialWords:words,previousLogs:first.attemptLogs)
        #expect(review.sessionErrorCounts.isEmpty)
    }
    @Test func corruptStoreRecoversLastGoodAndRetainsDamagedBytes() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let manager = try StudyPersistenceManager(storageDirectory:dir)
        var state = StudyStoreSnapshot(); state.preferredAccent = "en-US"
        try manager.save(state); try manager.save(state)
        try Data("broken".utf8).write(to:dir.appendingPathComponent("luma_study_store.json"))
        let recovered = try StudyPersistenceManager(storageDirectory:dir).loadAndMigrateIfNeeded()
        #expect(recovered.preferredAccent == "en-US")
        #expect(try FileManager.default.contentsOfDirectory(atPath:dir.appendingPathComponent("backups").path).contains { $0.hasPrefix("damaged-") })
    }
}
