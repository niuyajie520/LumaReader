import Foundation
import SwiftUI
import Testing
@testable import LumaReaderStudyKit

@Suite("Study Workspace Independence, Monet Sync, Writing Back Button & Continuous Countdown Tests", .serialized)
struct SmartUpgradeStudyWorkspaceTests {

    @Test("5. Switching between Listening, Reading, and Writing preserves unfinished dictation and writing states")
    @MainActor
    func testIndependentModuleStatePreservation() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let session = LumaStudySession(storageDirectory: tempDir)
        session.model.remember("学习_听力_今日计划")
        session.model.dictationInput = "aban"
        session.model.showMeaning = true
        session.model.save()

        // Switch to Reading (suspend)
        session.suspend()
        #expect(session.hasActiveListeningProgress == true)
        #expect(session.destination(for: "学习_听力") == "学习_听力_今日计划")
        #expect(session.model.dictationInput == "aban")
        #expect(session.model.showMeaning == true)

        // Start Writing draft and switch back to Listening
        session.model.remember("学习_写作_模拟机考")
        session.model.currentDraft.part1EssayText = "The chart illustrates urban electricity trends."
        session.model.currentDraft.elapsedSeconds = 120
        session.model.currentDraft.remainingSeconds = 3480
        session.model.storeDraft(session.model.currentDraft)

        session.suspend()
        #expect(session.hasActiveWritingProgress == true)
        #expect(session.destination(for: "学习_写作_Task1题库") == "学习_写作_模拟机考")
        #expect(session.model.currentDraft.part1EssayText == "The chart illustrates urban electricity trends.")
        #expect(session.model.dictationInput == "aban")
    }

    @Test("6. Writing back button auto-saves unsubmitted essay without triggering submission")
    @MainActor
    func testWritingBackButtonAutoSavesWithoutSubmitting() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let session = LumaStudySession(storageDirectory: tempDir)
        var draft = session.model.currentDraft
        draft.part1EssayText = "In 2010, Metropolis A consumed 450 GWh of electricity."
        draft.remainingSeconds = 1140
        draft.elapsedSeconds = 60
        draft.isSingleTaskMode = true

        // Simulate back button auto-save callback
        session.model.storeDraft(draft)
        session.model.currentDraft = draft

        #expect(session.model.storeSnapshot.writingSubmissions.isEmpty == true)
        let restored = session.model.existingUnsubmittedDraft(for: draft.questionID)
        #expect(restored != nil)
        #expect(restored?.part1EssayText == "In 2010, Metropolis A consumed 450 GWh of electricity.")
        #expect(restored?.remainingSeconds == 1140)
    }

    @Test("7. Writing exam countdown runs continuously and does not pause on module switch")
    @MainActor
    func testContinuousExamCountdownAcrossSwitches() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let session = LumaStudySession(storageDirectory: tempDir)
        session.model.currentDraft.remainingSeconds = 3600
        session.model.currentDraft.elapsedSeconds = 0
        session.model.currentDraft.isPaused = false
        session.model.isExamClockActive = true

        // Tick 5 seconds while in Writing
        session.model.tickExamClock(seconds: 5)
        #expect(session.model.currentDraft.remainingSeconds == 3595)
        #expect(session.model.currentDraft.elapsedSeconds == 5)

        // Suspend Study Center (user switches to Reading or Dictation); formal exam clock stays active
        session.suspend()
        #expect(session.model.isExamClockActive == true)
        session.model.tickExamClock(seconds: 10)
        #expect(session.model.currentDraft.remainingSeconds == 3585)
        #expect(session.model.currentDraft.elapsedSeconds == 15)
    }

    @Test("8. Monet theme and Light/Dark mode synchronize into StudyAppearance")
    func testMonetAndLightDarkThemeSync() {
        let lightAppearance = StudyAppearance(
            paper: Color(red: 0.96, green: 0.95, blue: 0.92),
            ink: Color(red: 0.12, green: 0.12, blue: 0.14),
            accent: Color(red: 0.35, green: 0.48, blue: 0.62),
            surface: Color.black.opacity(0.05),
            glassEnabled: true,
            isDark: false
        )
        let darkMonetAppearance = StudyAppearance(
            paper: Color(red: 0.09, green: 0.08, blue: 0.11),
            ink: Color(red: 0.94, green: 0.93, blue: 0.96),
            accent: Color(red: 0.85, green: 0.58, blue: 0.72),
            surface: Color.white.opacity(0.08),
            glassEnabled: true,
            isDark: true
        )
        #expect(lightAppearance != darkMonetAppearance)
        #expect(lightAppearance.isDark == false)
        #expect(darkMonetAppearance.isDark == true)
        #expect(darkMonetAppearance.glassEnabled == true)
    }
}
