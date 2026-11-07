import Foundation

public struct StudyWorkspaceState:Codable,Equatable,Sendable {
    public var listeningMode:String?
    public var writingMode:String?
    public var writingDraftID:UUID?
    public var dictationInput:String=""
    public var inputWordID:String?
    public init(){}
}

/// Lifetime belongs to the application window, not a particular study page.
@MainActor public final class LumaStudySession {
    let model:LumaStudyCenterHostView.HostStateModel
    public init(storageDirectory:URL?=nil){model=LumaStudyCenterHostView.HostStateModel(storageDirectory:storageDirectory)}
    public func suspend(){model.clockOwner=nil;model.speech.stop();model.save()}
    public func destination(for root:String)->String {
        let state=model.storeSnapshot.workspace
        if root=="学习_听力" {return state?.listeningMode ?? root}
        if root=="学习_写作_Task1题库" {
            let saved=state?.writingMode ?? root
            if saved.contains("模拟机考"),state?.writingDraftID != model.currentDraft.id{return root}
            return saved
        }
        return root
    }
}
