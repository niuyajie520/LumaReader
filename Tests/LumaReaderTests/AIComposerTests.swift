import Foundation
import Testing
@testable import LumaReader

@MainActor struct AIComposerTests {
    @Test func selectingTextOnlyUpdatesReferenceAndLeavesComposerEmpty() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AIComposerFixture-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = AIChatStore(historyDirectory:root)
        let context = AIReadingContext(bookID:nil,title:"Book",author:"Author",chapter:"Chapter",selectedText:"选中文字")
        store.prepare(context)
        #expect(store.draft.isEmpty)
        #expect(store.pendingQuote == "选中文字")
        #expect(store.context?.title == "Book")
    }
    @Test func selectingImagePreservesTypedQuestionAndNewConversationClearsIt() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AIComposerFixture-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = AIChatStore(historyDirectory:root)
        let image = AIImageAttachment(data:Data([1]),mimeType:"image/png",filename:"figure.png")
        store.prepare(nil,image:image)
        #expect(store.draft.isEmpty)
        store.draft = "我自己输入的问题"
        store.prepare(nil,image:image)
        #expect(store.draft == "我自己输入的问题")
        #expect(store.pendingImage == image)
        store.clearConversation()
        #expect(store.draft.isEmpty)
        #expect(store.pendingImage == nil)
    }
}
