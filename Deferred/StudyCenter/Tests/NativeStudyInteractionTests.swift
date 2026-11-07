import AppKit
import SwiftUI
import Testing
@testable import LumaReaderStudyKit

@Suite("Native study interactions",.serialized)
struct NativeStudyInteractionTests {
    @MainActor private func find<T:NSView>(_ type:T.Type,in view:NSView)->T? {
        if let match=view as? T{return match}
        for child in view.subviews {if let found=find(type,in:child){return found}}
        return nil
    }
    @MainActor @Test func promptHighlightEditsAndPersistenceKeepOriginalText()throws {
        let view=StudyPromptView.PromptTextView(frame:NSRect(x:0,y:0,width:400,height:240))
        view.string="Example question 📖 with immutable text."
        let original=view.string
        view.setSelectedRange(NSRange(location:0,length:16));view.highlightSelection()
        #expect(view.highlights==[StudyTextHighlight(start:0,length:16)])
        view.setSelectedRange(NSRange(location:4,length:4));view.clearHighlight()
        #expect(view.highlights==[StudyTextHighlight(start:0,length:4),StudyTextHighlight(start:8,length:8)])
        #expect(view.string==original)
        let data=try JSONEncoder().encode(view.highlights)
        #expect(try JSONDecoder().decode([StudyTextHighlight].self,from:data)==view.highlights)
    }
    @MainActor @Test func continuousNativeTypingDoesNotPauseExamAndDividerRetainsInput()async throws {
        _ = NSApplication.shared
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:directory)}
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:800),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false
        defer{window.close()}
        let host=NSHostingView(rootView:LumaStudyCenterHostView(mode:.constant("学习_写作_模拟机考"),storageDirectory:directory))
        window.contentView=host;window.makeKeyAndOrderFront(nil)
        let deadline=ContinuousClock.now.advanced(by:.seconds(10))
        while find(ExamNSTextView.self,in:host)==nil && ContinuousClock.now<deadline {
            host.layoutSubtreeIfNeeded();try await Task.sleep(for:.milliseconds(50))
        }
        let editor=try #require(find(ExamNSTextView.self,in:host))
        let split=try #require(find(NSSplitView.self,in:host))
        window.makeFirstResponder(editor)
        let began=ContinuousClock.now
        while began.duration(to:.now) < .seconds(3) {
            editor.insertText("teh ",replacementRange:NSRange(location:NSNotFound,length:0))
            try await Task.sleep(for:.milliseconds(40))
        }
        let typed=editor.string
        #expect(!typed.isEmpty)
        editor.insertText("中文",replacementRange:NSRange(location:NSNotFound,length:0))
        #expect(editor.string==typed)
        let before=split.subviews.first!.frame.width
        split.setPosition(before>450 ? 300:600,ofDividerAt:0);split.layoutSubtreeIfNeeded()
        #expect(abs(split.subviews.first!.frame.width-before)>20)
        #expect(editor.string==typed)
        let saved=try StudyPersistenceManager(storageDirectory:directory).loadAndMigrateIfNeeded()
        let draft=try #require(saved.activeWritingDrafts.values.first)
        #expect(draft.remainingSeconds<=3598)
        #expect(draft.elapsedSeconds>=2)
        #expect(draft.part1EssayText==typed)
        print("StudyNativeInteraction continuousTyping=true elapsedSeconds=\(draft.elapsedSeconds) nativeSplit=true originalEnglish=true")
    }
}
