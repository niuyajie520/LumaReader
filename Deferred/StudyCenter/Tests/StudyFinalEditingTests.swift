import Foundation
import AppKit
import SwiftUI
import Testing
@testable import LumaReaderStudyKit

@MainActor @Suite(.serialized)
struct StudyFinalEditingTests {
    private func model(_ directory:URL) -> LumaStudyCenterHostView.HostStateModel {
        LumaStudyCenterHostView.HostStateModel(storageDirectory:directory)
    }
    @Test func discardNewAutosavedDraftCannotResurrectOnDisappear() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let m=model(dir); m.beginWritingEdit(isNew:true)
        m.currentDraft.part1EssayText="teh new draft"
        m.storeDraft(m.currentDraft)
        let edited=m.currentDraft
        #expect(m.finishWritingEdit(discard:true))
        m.storeDraft(edited); m.save()
        #expect(try StudyPersistenceManager(storageDirectory:dir).loadAndMigrateIfNeeded().activeWritingDrafts.isEmpty)
    }
    @Test func discardRestoresEntryVersionAndSaveRetainsChanges() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let m=model(dir);m.currentDraft.part1EssayText="Original unchanged draft."
        m.storeDraft(m.currentDraft);m.beginWritingEdit()
        m.currentDraft.part1EssayText="Discard these changes.";m.storeDraft(m.currentDraft)
        #expect(m.finishWritingEdit(discard:true));m.save()
        let restored=try StudyPersistenceManager(storageDirectory:dir).loadAndMigrateIfNeeded()
        #expect(restored.activeWritingDrafts.values.first?.part1EssayText=="Original unchanged draft.")
        m.beginWritingEdit();m.currentDraft.part1EssayText="Saved revised draft."
        #expect(m.finishWritingEdit(discard:false))
        #expect(try StudyPersistenceManager(storageDirectory:dir).loadAndMigrateIfNeeded().activeWritingDrafts.values.first?.part1EssayText=="Saved revised draft.")
    }
    @Test func deletingCurrentDraftSurvivesLaterAutosave() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let m=model(dir);m.currentDraft.part2EssayText="Draft to remove.";m.storeDraft(m.currentDraft)
        let before=m.currentDraft
        #expect(m.deleteWritingDraft(before.id));m.storeDraft(before);m.save()
        #expect(try StudyPersistenceManager(storageDirectory:dir).loadAndMigrateIfNeeded().activeWritingDrafts.isEmpty)
    }
    @Test func wrongAnswerRevealsMeaningUntilTheWordIsCorrected() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let m=model(dir);let word=try #require(m.dictationMachine.currentWord)
        m.dictationInput="incorrect spelling";_ = m.submitDictationInput()
        #expect(m.showMeaning);#expect(m.dictationMachine.currentWord?.id==word.id)
        m.dictationInput=word.word;_ = m.submitDictationInput()
        #expect(!m.showMeaning)
    }
    @Test func legacyWorkspaceWithoutNewFieldsPreservesDraftAndOriginalBackup() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let m=model(dir);m.currentDraft.part1EssayText="Legacy original text.";m.storeDraft(m.currentDraft)
        let path=dir.appendingPathComponent("luma_study_store.json")
        var json=try #require(JSONSerialization.jsonObject(with:Data(contentsOf:path)) as? [String:Any])
        var workspace=try #require(json["workspace"] as? [String:Any]);workspace.removeValue(forKey:"dictationInput");workspace.removeValue(forKey:"showMeaning");json["workspace"]=workspace
        try JSONSerialization.data(withJSONObject:json).write(to:path)
        let reloaded=model(dir)
        #expect(reloaded.storageError==nil)
        #expect(reloaded.storeSnapshot.activeWritingDrafts.values.first?.part1EssayText=="Legacy original text.")
        #expect(try FileManager.default.contentsOfDirectory(atPath:dir.appendingPathComponent("backups").path).contains { $0.hasPrefix("legacy-") })
    }
    private func answer(in view:NSView) -> NSTextField? {
        if let field=view as? NSTextField,field.placeholderString=="输入听到的英文词汇" {return field}
        for child in view.subviews {if let field=answer(in:child) {return field}}
        return nil
    }
    @Test func nativeDictationInputUsesLargeCenteredTypography() async throws {
        _ = NSApplication.shared
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let host=NSHostingView(rootView:LumaStudyCenterHostView(mode:.constant("学习_听力_今日计划"),session:LumaStudySession(storageDirectory:dir)))
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:850),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;defer {window.close()}
        window.contentView=host;window.makeKeyAndOrderFront(nil)
        let deadline=ContinuousClock.now.advanced(by:.seconds(8))
        while answer(in:host)==nil && ContinuousClock.now<deadline {host.layoutSubtreeIfNeeded();try await Task.sleep(for:.milliseconds(30))}
        let field=try #require(answer(in:host))
        #expect((field.font?.pointSize ?? 0)>=36);#expect(field.alignment == .center);#expect(field.frame.width>=350)
    }
}
