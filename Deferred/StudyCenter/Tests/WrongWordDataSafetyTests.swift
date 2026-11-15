import Foundation
import Testing
@testable import LumaReaderStudyKit

struct WrongWordDataSafetyTests {
    private func log(_ wordID: String, deckID: String = "unit-a", correct: Bool = false) -> DictationAttemptLog {
        DictationAttemptLog(
            id: UUID(), sessionID: UUID(), mode: .newTask, wordID: wordID,
            word: wordID, deckID: deckID, userTyped: correct ? wordID : "miss",
            isCorrect: correct, isFirstAttemptInSession: true,
            sessionErrorCountForWord: correct ? 0 : 1,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            dateString: "2023-11-14", durationSeconds: 2.0
        )
    }

    @Test func suppressionTargetsIndividualMistakesWithoutDestroyingHistoryOrMeaning() throws {
        let first = log("word"), second = log("word"), correct = log("word", correct: true)
        var snapshot = StudyStoreSnapshot(dictationLogs: [first, second, correct])
        var progress = WordReviewProgress(dueAt: Date(timeIntervalSince1970: 1_700_000_000))
        progress.record(cleanRecall: false, at: Date(timeIntervalSince1970: 1_700_000_000))
        snapshot.reviewSchedule = ["word": progress]
        snapshot.suppressWrongLogs([first.id, correct.id, UUID()])
        #expect(snapshot.suppressedWrongLogIDs == [first.id])
        #expect(snapshot.dictationLogs == [first, second, correct])
        #expect(snapshot.effectiveWrongLogs == [second])
        #expect(snapshot.effectiveWrongWordIDs == ["word"])
        snapshot.suppressWrongLogs([second.id])
        #expect(snapshot.effectiveWrongLogs.isEmpty)
        #expect(snapshot.effectiveWrongWordIDs.isEmpty)
        snapshot.setMeaningUnclear(true, for: "word")
        #expect(snapshot.effectiveWrongWordIDs == ["word"])
        let restored = try JSONDecoder().decode(StudyStoreSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(restored.suppressedWrongLogIDs == snapshot.suppressedWrongLogIDs)
        #expect(restored.meaningUnclearWordIDs == ["word"])
        #expect(restored.reviewSchedule == ["word": progress])
        var undone = restored
        undone.restoreWrongLogs([first.id])
        #expect(undone.effectiveWrongLogs == [first])
        undone.setMeaningUnclear(false, for: "word")
        #expect(undone.meaningUnclearWordIDs == nil)
    }

    @Test func deckProjectionKeepsMeaningOnlyWordsWithKnownDeckIdentity() {
        let known = log("meaning-only", deckID: "unit-b", correct: true)
        let wrong = log("spelling", deckID: "unit-a")
        var snapshot = StudyStoreSnapshot(dictationLogs: [known, wrong])
        snapshot.setMeaningUnclear(true, for: "meaning-only")
        #expect(snapshot.effectiveWrongWordIDs(inDeck: "unit-a") == ["spelling"])
        #expect(snapshot.effectiveWrongWordIDs(inDeck: "unit-b") == ["meaning-only"])
    }

    @Test func legacyWordMarksMigrateOnlyExistingMistakesAndDoNotSuppressFutureLogs() throws {
        let past = log("typo"), other = log("other")
        let base = StudyStoreSnapshot(dictationLogs: [past, other])
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
        json["wrongWordMarks"] = ["typo": "typo", "understood": "meaning"]
        let migrated = try JSONDecoder().decode(StudyStoreSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(migrated.wrongWordMarks == nil)
        #expect(migrated.suppressedWrongLogIDs == [past.id])
        #expect(migrated.meaningUnclearWordIDs == ["understood"])
        #expect(migrated.effectiveWrongLogs == [other])
        var later = migrated
        let newMiss = log("typo")
        later.dictationLogs.append(newMiss)
        #expect(later.effectiveWrongLogs == [other, newMiss])
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(later)) as? [String: Any])
        #expect(encoded["wrongWordMarks"] == nil)
    }

    @Test func cloudMergeRetainsHistoryAndUnionsIndependentExclusionsAndMeaning() {
        let first = log("a"), second = log("b")
        var local = StudyStoreSnapshot(dictationLogs: [first])
        local.suppressWrongLogs([first.id])
        local.setMeaningUnclear(true, for: "meaning-a")
        var remote = StudyStoreSnapshot(dictationLogs: [first, second])
        remote.suppressWrongLogs([second.id])
        remote.setMeaningUnclear(true, for: "meaning-b")
        let merged = StudyCloudSyncManager.merge(local: local, remote: remote)
        #expect(Set(merged.dictationLogs.map(\.id)) == [first.id, second.id])
        #expect(Set(merged.suppressedWrongLogIDs ?? []) == [first.id, second.id])
        #expect(Set(merged.meaningUnclearWordIDs ?? []) == ["meaning-a", "meaning-b"])
        #expect(merged.effectiveWrongLogs.isEmpty)
        #expect(merged.effectiveWrongWordIDs == ["meaning-a", "meaning-b"])
        #expect(StudyCloudSyncManager.merge(local: remote, remote: local).effectiveWrongWordIDs == merged.effectiveWrongWordIDs)
    }

    /// 每个单词自己的听写记录：两个词互不覆盖，编解码后仍在。
    @Test func perWordDraftsSurviveRoundTripWithoutOverwriting() throws {
        var state = StudyWorkspaceState()
        state.wordInputs = ["new_task|2026-11-14|w1": "branck o", "new_task|2026-11-14|w2": "poultr"]
        state.wordShowMeaning = ["new_task|2026-11-14|w1": true]
        state.wordRevealedWordIDs = ["new_task|2026-11-14|w2": "w2"]
        let decoded = try JSONDecoder().decode(StudyWorkspaceState.self, from: JSONEncoder().encode(state))
        #expect(decoded.wordInputs?["new_task|2026-11-14|w1"] == "branck o")
        #expect(decoded.wordInputs?["new_task|2026-11-14|w2"] == "poultr")
        #expect(decoded.wordShowMeaning?["new_task|2026-11-14|w1"] == true)
        #expect(decoded.wordRevealedWordIDs?["new_task|2026-11-14|w2"] == "w2")
        #expect(decoded.wordInputs?.count == 2)

        // 旧快照（没有这三个字段）仍能解码，且不会凭空生成记录
        let legacy = StudyWorkspaceState()
        let legacyJSON = try JSONSerialization.data(withJSONObject: try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)))
        let legacyDecoded = try JSONDecoder().decode(StudyWorkspaceState.self, from: legacyJSON)
        #expect(legacyDecoded.wordInputs == nil)

        // 换词再回来：取回的是这个词自己的内容，不是别的词的
        var live = decoded
        live.wordInputs?["new_task|2026-11-14|w1"] = "branch o"
        #expect(live.wordInputs?["new_task|2026-11-14|w1"] == "branch o")
        #expect(live.wordInputs?["new_task|2026-11-14|w2"] == "poultr")
    }
}
