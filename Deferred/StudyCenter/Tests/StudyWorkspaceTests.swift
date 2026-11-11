import Foundation
import Testing
@testable import LumaReaderStudyKit

@MainActor struct StudyWorkspaceTests {
    @Test func switchingAndReopeningPreserveIndependentDestinationsAndUnsubmittedInput()throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        let session=LumaStudySession(storageDirectory:dir)
        let model=session.model
        model.dictationMachine.submitAnswer("wrong")
        model.dictationInput="Unsubmitted, CaSe!"
        model.remember("学习_听力_今日计划")
        let queue=model.dictationMachine
        model.currentDraft.part1EssayText="teh original typing stays unchanged."
        model.currentDraft.remainingSeconds=2456
        model.currentDraft.lastSavedAt=Date(timeIntervalSince1970:1700000000)
        let draft=model.currentDraft
        model.storeDraft(draft);model.remember("学习_写作_模拟机考")
        #expect(session.destination(for:"学习_听力")=="学习_听力_今日计划")
        #expect(session.destination(for:"学习_写作_Task1题库")=="学习_写作_Task1题库")
        #expect(session.destination(for:"学习_写作_Task1题库",directResume:true)=="学习_写作_模拟机考")
        model.remember("学习_听力_今日计划")
        #expect(model.currentDraft==draft)
        #expect(model.dictationMachine==queue)
        let restored=LumaStudySession(storageDirectory:dir)
        #expect(restored.model.dictationInput=="Unsubmitted, CaSe!")
        #expect(restored.model.dictationMachine.pendingQueue==queue.pendingQueue)
        #expect(restored.model.dictationMachine.sessionErrorCounts==queue.sessionErrorCounts)
        #expect(restored.model.dictationMachine.requiresCorrection)
        #expect(restored.model.currentDraft==draft)
        #expect(restored.destination(for:"学习_写作_Task1题库")=="学习_写作_Task1题库")
        #expect(restored.destination(for:"学习_写作_Task1题库",directResume:true)=="学习_写作_模拟机考")
        #expect(restored.destination(for:"学习_听力")=="学习_听力_今日计划")
    }
    @Test func staleWritingDestinationCannotResumeAnUnrelatedQuestion()throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        var snapshot=StudyStoreSnapshot();var workspace=StudyWorkspaceState()
        workspace.writingMode="学习_写作_模拟机考";workspace.writingDraftID=UUID()
        workspace.dictationInput="belongs to another word";workspace.inputWordID="missing"
        snapshot.workspace=workspace
        try StudyPersistenceManager(storageDirectory:dir).save(snapshot)
        let session=LumaStudySession(storageDirectory:dir)
        #expect(session.destination(for:"学习_写作_Task1题库")=="学习_写作_Task1题库")
        #expect(session.model.dictationInput.isEmpty)
    }
}
