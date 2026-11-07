import AppKit
import SwiftUI
import Testing
@testable import LumaReaderStudyKit

@Suite("Native writing revision",.serialized)
struct NativeWritingReviewTests {
    @MainActor private func editor(in view:NSView)->ExamNSTextView? {
        if let text=view as? ExamNSTextView{return text}
        for child in view.subviews{if let text=editor(in:child){return text}}
        return nil
    }
    @MainActor @Test func nativeRewriteInputSavesAndReopensWithoutChangingOriginal()async throws {
        _ = NSApplication.shared
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        let model=LumaStudyCenterHostView.HostStateModel(storageDirectory:dir)
        let original=WritingSubmissionRecord(id:UUID(),draftSessionID:UUID(),questionID:"fixture",examTitle:"Fixture",part1EssayText:"Original essay stays unchanged.",part2EssayText:"",part1WordCount:4,part2WordCount:0,durationSeconds:1200,submittedAt:Date(timeIntervalSince1970:1700000000),dateString:"2026-11-07")
        model.storeSnapshot.writingSubmissions=[original];model.save()
        let revision=WritingRevision(submissionID:original.id)
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1000,height:700),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;defer{window.close()}
        @MainActor func host(_ revision:WritingRevision)->NSHostingView<WritingReviewPanel> {
            NSHostingView(rootView:WritingReviewPanel(session:WritingReviewSession(original:original,revision:revision),onSave:{updated in
                model.storeSnapshot.writingRevisions=[updated]
                return model.save() ? nil:"Save failed"
            }))
        }
        let first=host(revision);window.contentView=first;window.makeKeyAndOrderFront(nil)
        let deadline=ContinuousClock.now.advanced(by:.seconds(8))
        while editor(in:first)==nil && ContinuousClock.now<deadline{first.layoutSubtreeIfNeeded();try await Task.sleep(for:.milliseconds(30))}
        let input=try #require(editor(in:first));window.makeFirstResponder(input)
        input.insertText("teh rewritten essay, unchanged!",replacementRange:NSRange(location:NSNotFound,length:0))
        try await Task.sleep(for:.milliseconds(100))
        let reopened=LumaStudyCenterHostView.HostStateModel(storageDirectory:dir)
        let saved=try #require(reopened.storeSnapshot.writingRevisions?.first)
        #expect(saved.part1=="teh rewritten essay, unchanged!")
        #expect(reopened.storeSnapshot.writingSubmissions.first==original)
        let second=host(saved);window.contentView=second;second.layoutSubtreeIfNeeded()
        #expect(try #require(editor(in:second)).string==saved.part1)
    }
}
