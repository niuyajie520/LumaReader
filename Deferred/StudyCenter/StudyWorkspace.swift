import Foundation

public struct StudyWorkspaceState: Codable, Equatable, Sendable {
    public var listeningMode: String?
    public var activePracticeListeningMode: String?
    public var selectedDeckID: String?
    public var writingMode: String?
    public var activePracticeWritingMode: String?
    public var writingDraftID: UUID?
    public var dictationInput: String = ""
    public var inputWordID: String?
    public var showMeaning: Bool = false
    public var revealedWordID: String?
    public var deckInputs: [String: String]? = nil
    public var deckInputWordIDs: [String: String]? = nil
    public var deckShowMeaning: [String: Bool]? = nil
    public var deckRevealedWordIDs: [String: String]? = nil
    public init() {}
}

/// Lifetime belongs to the application window, not a particular study page.
/// Preserves independent state across Reading, Listening/Dictation, and Writing modules,
/// and keeps formal exam countdowns running continuously in real time across view switches.
@MainActor public final class LumaStudySession {
    let model: LumaStudyCenterHostView.HostStateModel
    public init(storageDirectory: URL? = nil) {
        model = LumaStudyCenterHostView.HostStateModel(storageDirectory: storageDirectory)
    }
    public func suspend() {
        // Stop speech synthesis when leaving Study Center, while keeping the continuous exam clock alive
        model.speech.stop()
        model.save()
    }
    public var hasActiveListeningProgress: Bool {
        !model.dictationMachine.isSessionFinished &&
        (!model.dictationMachine.completedWordIDs.isEmpty ||
         !model.dictationMachine.attemptLogs.isEmpty ||
         !model.dictationInput.isEmpty ||
         model.dictationMachine.requiresCorrection)
    }
    public var hasActiveWritingProgress: Bool {
        let draft = model.currentDraft
        let isSubmitted = model.storeSnapshot.writingSubmissions.contains { $0.draftSessionID == draft.id }
        guard !isSubmitted else { return false }
        return !draft.part1EssayText.isEmpty ||
               !draft.part2EssayText.isEmpty ||
               draft.elapsedSeconds > 0 ||
               model.storeSnapshot.activeWritingDrafts.values.contains(where: { $0.id == draft.id })
    }
    public func destination(for root: String) -> String {
        let state = model.storeSnapshot.workspace
        if root == "学习_听力" {
            if let mode = state?.listeningMode, mode != "学习_听力" {
                return mode
            }
            if hasActiveListeningProgress {
                return state?.activePracticeListeningMode ?? (model.dictationMachine.mode == .wrongWordReview ? "学习_听力_错词复习" : "学习_听力_今日计划")
            }
            return state?.listeningMode ?? root
        }
        if root == "学习_写作_Task1题库" {
            let saved = state?.writingMode ?? root
            if saved.contains("模拟机考") {
                if state?.writingDraftID != model.currentDraft.id { return root }
                return saved
            }
            if let activeWriting = state?.activePracticeWritingMode,
               activeWriting.contains("模拟机考"),
               state?.writingDraftID == model.currentDraft.id,
               hasActiveWritingProgress {
                return activeWriting
            }
            return saved
        }
        return root
    }
}
