import SwiftUI
import AppKit
import Testing
@testable import LumaReaderStudyKit

@Suite("Independent study workspaces",.serialized)
struct NativeWorkspaceTests {
    @MainActor private func editor(_ view:NSView)->ExamNSTextView? {
        if let input=view as? ExamNSTextView{return input}
        for child in view.subviews{if let input=editor(child){return input}}
        return nil
    }
    @MainActor @Test func writingHostCanBeRemovedForListeningAndRestoredWithoutResetting()async throws {
        _ = NSApplication.shared
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        let session=LumaStudySession(storageDirectory:dir)
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:800),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;defer{window.close()}
        @MainActor func mount(_ mode:String)->NSHostingView<LumaStudyCenterHostView> {
            let view=NSHostingView(rootView:LumaStudyCenterHostView(mode:.constant(mode),session:session))
            window.contentView=view;window.makeKeyAndOrderFront(nil);view.layoutSubtreeIfNeeded();return view
        }
        let first=mount("学习_写作_模拟机考")
        var deadline=ContinuousClock.now.advanced(by:.seconds(8))
        while editor(first)==nil && ContinuousClock.now<deadline{first.layoutSubtreeIfNeeded();try await Task.sleep(for:.milliseconds(30))}
        let text=try #require(editor(first));window.makeFirstResponder(text)
        text.insertText("teh saved essay",replacementRange:NSRange(location:NSNotFound,length:0))
        _ = mount("学习_听力_今日计划")
        try await Task.sleep(for:.milliseconds(150))
        let remaining=session.model.currentDraft.remainingSeconds
        session.model.dictationInput="unfinished spelling";session.model.save()
        try await Task.sleep(for:.milliseconds(1150))
        #expect(session.model.currentDraft.remainingSeconds<remaining)
        let second=mount(session.destination(for:"学习_写作_Task1题库"))
        deadline=ContinuousClock.now.advanced(by:.seconds(8))
        while editor(second)==nil && ContinuousClock.now<deadline{second.layoutSubtreeIfNeeded();try await Task.sleep(for:.milliseconds(30))}
        #expect(try #require(editor(second)).string=="teh saved essay")
        #expect(session.model.dictationInput=="unfinished spelling")
    }
}

