import Foundation
import Testing
@testable import LumaReader

@MainActor @Suite(.serialized) struct AIHistoryTests {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("LumaHistoryFixture-"+UUID().uuidString,isDirectory:true) }
    private func waitFor(_ store:AIChatStore,id:UUID) async throws {
        for _ in 0..<100 {
            if store.currentConversationID == id && !store.isLoadingConversation { return }
            try await Task.sleep(for:.milliseconds(20))
        }
        Issue.record("Synthetic history restore did not complete")
    }
    @Test func sessionsSurviveNewConversationRestoreAndRestart() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at:root) }
        let store = AIChatStore(historyDirectory:root)
        store.messages = [AIChatMessage(role:"user",text:"Synthetic question"),AIChatMessage(role:"assistant",text:"Synthetic answer")]
        store.draft = "Unsent fixture draft"; store.flushHistory()
        let first = store.currentConversationID, originalIDs = store.messages.map(\.id)
        let revision = store.historyWriteRevision
        store.flushHistory()
        #expect(store.historyWriteRevision == revision, "Unchanged library flushes must not rewrite conversations")
        store.clearConversation(); store.draft = "Second synthetic conversation"; store.flushHistory()
        let second = store.currentConversationID
        #expect(first != second)
        #expect(Set(store.historyEntries.map(\.id)) == Set([first,second]))
        store.restoreConversation(first); try await waitFor(store,id:first)
        #expect(store.draft == "Unsent fixture draft")
        #expect(store.messages.map(\.id) == originalIDs)
        store.messages.append(AIChatMessage(role:"user",text:"Synthetic follow-up")); store.flushHistory()
        let reopened = AIChatStore(historyDirectory:root)
        #expect(reopened.currentConversationID == first)
        #expect(reopened.messages.count == 3)
        #expect(reopened.messages.last?.text == "Synthetic follow-up")
        #expect(reopened.historyEntries.count == 2)
        let indexMode = try FileManager.default.attributesOfItem(atPath:root.appendingPathComponent("history.json").path)[.posixPermissions] as? NSNumber
        #expect(indexMode?.intValue == 0o600)
    }
    @Test func modelsAndBookContextRestoreWithoutAttachingAnotherBook() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at:root) }
        let provider = AIProvider(rawValue:UserDefaults.standard.string(forKey:"aiProvider") ?? "") ?? .deepseek
        let oldProvider = UserDefaults.standard.object(forKey:"aiProvider")
        let oldInclude = UserDefaults.standard.object(forKey:"aiIncludeReading")
        defer {
            if let oldProvider { UserDefaults.standard.set(oldProvider,forKey:"aiProvider") } else { UserDefaults.standard.removeObject(forKey:"aiProvider") }
            if let oldInclude { UserDefaults.standard.set(oldInclude,forKey:"aiIncludeReading") } else { UserDefaults.standard.removeObject(forKey:"aiIncludeReading") }
        }
        let context = AIReadingContext(bookID:UUID(),title:"Synthetic book",author:"Fixture",chapter:"Fixture chapter")
        let record = AIConversationRecord(id:UUID(),updatedAt:Date(),provider:provider,model:"fixture-model-v1",visionModel:"fixture-vision-v1",messages:[AIChatMessage(role:"user",text:"Synthetic question",context:context)],draft:"",context:context,pendingQuote:"",pendingImage:nil,includeReading:true)
        #expect(AIConversationDisk.write(record,index:AIHistoryIndex(activeID:record.id,conversations:[record.summary]),to:root))
        let store = AIChatStore(historyDirectory:root)
        #expect(store.model == "fixture-model-v1")
        #expect(store.visionModel == "fixture-vision-v1")
        #expect(store.messages.first?.context == context)
        let another = AIReadingContext(bookID:UUID(),title:"Other synthetic book",author:"Fixture",chapter:"Other chapter")
        #expect(store.incomingHistoryContext(another) == context)
        #expect(store.incomingHistoryContext(nil) == context)
        #expect(store.incomingHistoryContext(context) == context)
        store.prepare(another)
        #expect(store.incomingHistoryContext(another) == another, "An explicit new reading reference remains allowed")
        store.flushHistory()
        let data = try Data(contentsOf:root.appendingPathComponent(record.id.uuidString+".json"))
        let keys = Set((try JSONSerialization.jsonObject(with:data) as! [String:Any]).keys)
        #expect(!keys.contains("key") && !keys.contains("baseURL"))
    }
    @Test func corruptHistoryIsPreservedInsteadOfOverwritten() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at:root) }
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let file = root.appendingPathComponent("history.json"), original = Data("invalid synthetic archive".utf8)
        try original.write(to:file)
        let store = AIChatStore(historyDirectory:root)
        store.draft = "New synthetic draft"; store.flushHistory()
        let active = store.currentConversationID
        store.clearConversation()
        #expect(store.historyWritable == false)
        #expect(store.currentConversationID == active && store.draft == "New synthetic draft")
        #expect(try Data(contentsOf:file) == original)
    }
    @Test func failedWriteDoesNotDiscardActiveDraft() throws {
        let file = directory(); try Data("synthetic file, not a folder".utf8).write(to:file)
        defer { try? FileManager.default.removeItem(at:file) }
        let store = AIChatStore(historyDirectory:file)
        store.draft = "Synthetic unsaved draft"; let active = store.currentConversationID
        store.flushHistory(); store.clearConversation()
        #expect(store.currentConversationID == active)
        #expect(store.draft == "Synthetic unsaved draft")
    }
}
