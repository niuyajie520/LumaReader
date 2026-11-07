import AppKit
import SwiftUI
import WebKit
import Testing
import ZIPFoundation
@testable import LumaReader

@MainActor @Suite(.serialized) struct ImmersiveReaderTests {
    private func pump() { _ = RunLoop.current.run(mode:.default,before:Date(timeIntervalSinceNow:0.002)) }
    private func pause(_ ms:Int) async throws {
        let deadline = Date().addingTimeInterval(Double(ms)/1000)
        while Date() < deadline { pump(); try await Task.sleep(for:.milliseconds(10)) }
    }
    private func until(_ condition:()->Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if condition() { return }
            try await pause(20)
        }
        Issue.record("Synthetic reader condition timed out")
        throw CocoaError(.fileReadUnknown)
    }
    private func epub(_ root:URL) throws -> URL {
        let source = root.appendingPathComponent("fixture")
        try FileManager.default.createDirectory(at:source.appendingPathComponent("META-INF"),withIntermediateDirectories:true)
        try "<container xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"book.opf\"/></rootfiles></container>".write(to:source.appendingPathComponent("META-INF/container.xml"),atomically:true,encoding:.utf8)
        try "<package xmlns=\"http://www.idpf.org/2007/opf\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>Synthetic Reader Fixture</dc:title><dc:creator>Luma Test</dc:creator></metadata><manifest><item id=\"c\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/></manifest><spine><itemref idref=\"c\"/></spine></package>".write(to:source.appendingPathComponent("book.opf"),atomically:true,encoding:.utf8)
        let paragraphs = (0..<400).map { "<p>Fixture paragraph \($0). This synthetic text tests stable reading layout. 测试文字与阅读布局。</p>" }.joined()
        try ("<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h1>Synthetic Reader</h1>"+paragraphs+"</body></html>").write(to:source.appendingPathComponent("chapter.xhtml"),atomically:true,encoding:.utf8)
        let file = root.appendingPathComponent("fixture.epub")
        try FileManager.default.zipItem(at:source,to:file,shouldKeepParent:false)
        return file
    }
    private func mouse(_ window:NSWindow,x:CGFloat,y:CGFloat) throws {
        let event = try #require(NSEvent.mouseEvent(with:.mouseMoved,location:NSPoint(x:x,y:y),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:0,pressure:0))
        NSApp.sendEvent(event)
    }
    private func screenshot(_ view:NSView,name:String) throws {
        guard let folder = ProcessInfo.processInfo.environment["LUMA_SYNTHETIC_UI_EVIDENCE"] else { return }
        let root = URL(fileURLWithPath:folder,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        view.layoutSubtreeIfNeeded()
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in:view.bounds))
        view.cacheDisplay(in:view.bounds,to:bitmap)
        let data = try #require(bitmap.representation(using:.png,properties:[:]))
        try data.write(to:root.appendingPathComponent(name+".png"),options:.atomic)
    }
    private func webState(_ web:WKWebView) async {
        let script = "JSON.stringify({ready:document.readyState,hidden:document.hidden,engine:!!window.Luma,width:innerWidth,height:innerHeight,content:!!document.getElementById('luma-content')})"
        await withCheckedContinuation { (continuation:CheckedContinuation<Void,Never>) in
            web.evaluateJavaScript(script,in:nil,in:WKContentWorld.world(name:"LumaReader")) { result in
                switch result {
                case .success(let value): print("ReaderFixture webState=\(value)")
                case .failure(let error): print("ReaderFixture javascriptErrorCode=\((error as NSError).code)")
                }
                continuation.resume()
            }
        }
    }
    @Test func syntheticEPUBChromeRevealsHidesAndKeepsWebView() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LumaSyntheticUI-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = LibraryStore(root:root.appendingPathComponent("library"))
        #expect(await store.importFiles([try epub(root)],provider:nil) == 1)
        let book = try #require(store.books.first)
        let controller = ReaderController()
        let hosting = NSHostingView(rootView:ContentView(store:store,controller:controller))
        let window = NSWindow(contentRect:NSRect(x:100,y:100,width:1100,height:760),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false; window.contentView = hosting
        defer { window.close(); store.reader = nil; store.ai.flushHistory() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
        hosting.layoutSubtreeIfNeeded()
        store.open(book)
        try await pause(500)
        try screenshot(hosting,name:"reader-mount-synthetic")
        if let web = controller.illustrationWebView { await webState(web) }
        var waits = 0
        try await until {
            hosting.layoutSubtreeIfNeeded(); waits += 1
            if waits % 100 == 0 {
                print("ReaderFixture selected=\(store.selectedBook != nil) sameController=\(store.reader === controller) web=\(controller.illustrationWebView != nil) error=\(store.error != nil) chapters=\(controller.chapters.count) hostSizeValid=\(hosting.bounds.width > 300 && hosting.bounds.height > 300)")
            }
            return controller.presentationReady && controller.illustrationWebView != nil
        }
        try await pause(1000)
        let web = try #require(controller.illustrationWebView)
        let size = web.bounds.size
        #expect(window.standardWindowButton(.closeButton)?.isHidden == true)
        try screenshot(hosting,name:"reader-hidden-synthetic")
        try mouse(window,x:150,y:window.contentView!.bounds.height-10)
        try await pause(300)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == false)
        try screenshot(hosting,name:"reader-top-synthetic")
        try mouse(window,x:150,y:300)
        try await pause(1700)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == true)
        try mouse(window,x:150,y:10)
        try await pause(300)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == false)
        #expect(controller.illustrationWebView === web)
        #expect(web.bounds.size == size)
        try screenshot(hosting,name:"reader-bottom-synthetic")
        for _ in 0..<20 {
            try mouse(window,x:150,y:window.contentView!.bounds.height-10)
            try mouse(window,x:150,y:300)
        }
        try await pause(1700)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == true)
        #expect(controller.illustrationWebView === web)
    }
    @Test func nativeFadeReversalsDoNotApplyStaleHiddenState() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:940,height:620),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false; defer { window.close() }
        NativeWindowControls.restore(window)
        for _ in 0..<20 {
            NativeWindowControls.restore(window,controlsVisible:false,animated:true)
            NativeWindowControls.restore(window,controlsVisible:true,animated:true)
        }
        try await pause(400)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == false)
        #expect(window.standardWindowButton(.closeButton)?.alphaValue == 1)
        NativeWindowControls.restore(window,controlsVisible:false,animated:true)
        try await pause(400)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == true)
    }
}

