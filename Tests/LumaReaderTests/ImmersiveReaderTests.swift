import AppKit
import SwiftUI
import WebKit
import PDFKit
import QuartzCore
import Testing
import ZIPFoundation
@testable import LumaReader

@MainActor @Suite(.serialized) struct ImmersiveReaderTests {
    @MainActor private final class ApplicationDelegate:NSObject,NSApplicationDelegate {
        func applicationShouldTerminate(_ sender:NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
        func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { false }
    }
    private static let applicationDelegate = ApplicationDelegate()
    private static var preparedApplication = false
    private func prepareApplication() {
        _ = NSApplication.shared
        guard !Self.preparedApplication else { return }
        Self.preparedApplication = true
        NSApp.delegate = Self.applicationDelegate
        NSApp.setActivationPolicy(.regular)
        NSApp.finishLaunching()
    }
    private func pump() {
        // Deliver window/occlusion notifications without consuming runner control,
        // Apple-event or keyboard messages from the application's general queue.
        for _ in 0..<32 {
            guard let event = NSApp.nextEvent(matching:.appKitDefined,until:Date(),inMode:.default,dequeue:true) else { break }
            NSApp.sendEvent(event)
        }
        NSApp.updateWindows()
        _ = RunLoop.current.run(mode:.default,before:Date(timeIntervalSinceNow:0.002))
        CATransaction.flush()
    }
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
        let paragraphs = (0..<1200).map { "<p>Fixture paragraph \($0). This synthetic text tests stable reading layout. 测试文字与阅读布局。</p>" }.joined()
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
        print("ReaderFixture native window=\(web.window != nil) visible=\(web.window?.isVisible == true) hidden=\(web.isHiddenOrHasHiddenAncestor) loading=\(web.isLoading) fileURL=\(web.url?.isFileURL == true) urlPresent=\(web.url != nil) nonemptyVisibleRect=\(!web.visibleRect.isEmpty)")
        print("ReaderFixture windowUnoccluded=\(web.window?.occlusionState.contains(.visible) == true) alphaVisible=\(web.alphaValue > 0.9)")
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
    private func readerSnapshot(_ web:WKWebView,name:String) async throws {
        guard let folder = ProcessInfo.processInfo.environment["LUMA_SYNTHETIC_UI_EVIDENCE"] else { return }
        let image:NSImage = try await withCheckedThrowingContinuation { continuation in
            web.takeSnapshot(with:nil) { image,error in
                if let error { continuation.resume(throwing:error) }
                else if let image { continuation.resume(returning:image) }
                else { continuation.resume(throwing:CocoaError(.fileReadUnknown)) }
            }
        }
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data:tiff))
        let png = try #require(bitmap.representation(using:.png,properties:[:]))
        try png.write(to:URL(fileURLWithPath:folder).appendingPathComponent(name+".png"),options:.atomic)
    }
    private func readerJavaScript(_ web:WKWebView,_ script:String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            web.evaluateJavaScript(script,in:nil,in:WKContentWorld.world(name:"LumaReader")) { result in
                switch result {
                case .success(let value): continuation.resume(returning:value as? String ?? "")
                case .failure(let error): continuation.resume(throwing:error)
                }
            }
        }
    }
    @Test func syntheticEPUBChromeRevealsHidesAndKeepsWebView() async throws {
        prepareApplication()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LumaSyntheticUI-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = LibraryStore(root:root.appendingPathComponent("library"))
        #expect(await store.importFiles([try epub(root)],provider:nil) == 1)
        let book = try #require(store.books.first)
        let controller = ReaderController()
        let hostController = NSHostingController(rootView:ContentView(store:store,controller:controller).frame(minWidth:760,minHeight:620))
        let hosting = hostController.view
        let window = NSWindow(contentRect:NSRect(x:100,y:100,width:1100,height:760),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false; window.contentViewController = hostController
        window.setContentSize(NSSize(width:1100,height:760))
        window.level = .floating
        defer { window.close(); store.reader = nil; store.ai.flushHistory() }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps:true)
        hosting.layoutSubtreeIfNeeded()
        store.open(book)
        try await pause(500)
        try #require(hosting.bounds.width >= 760 && hosting.bounds.height >= 620)
        try screenshot(hosting,name:"reader-mount-synthetic")
        if let web = controller.illustrationWebView { await webState(web) }
        try await pause(2000)
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
        try await readerSnapshot(web,name:"epub-rendered-content-synthetic")
        #expect(window.standardWindowButton(.closeButton)?.isHidden == true)
        try screenshot(hosting,name:"reader-hidden-synthetic")
        try mouse(window,x:150,y:window.contentView!.bounds.height-10)
        try await pause(300)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == false)
        #expect(NativeWindowControls.snapshot(window).values.allSatisfy { $0 })
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
        for _ in 0..<20 {
            let before = store.selectedBook?.readerOffset
            #expect(controller.canGoForward)
            controller.move(1)
            try await until { !controller.isTurning && store.selectedBook?.readerOffset != before }
            #expect(controller.illustrationWebView === web)
            #expect(store.error == nil)
        }
        let saved = try #require(store.selectedBook?.readerAnchor)
        for _ in 0..<10 {
            store.aiPanelVisible = true
            try await pause(70)
            store.aiPanelVisible = false
        }
        try await pause(1600)
        #expect(controller.illustrationWebView === web)
        #expect(store.selectedBook?.readerAnchor == saved)
        #expect(store.error == nil)
        window.setContentSize(NSSize(width:760,height:620))
        store.aiPanelVisible = true
        store.aiPanelExpanded = true
        try await pause(1600)
        #expect(web.bounds.width >= 300)
        #expect(controller.illustrationWebView === web)
        #expect(store.error == nil)
        try await readerSnapshot(web,name:"epub-narrow-ai-content-synthetic")
        store.aiPanelVisible = false
        try await pause(1600)
        let selected = try await readerJavaScript(web,"var r=document.caretRangeFromPoint(innerWidth/2,100);if(r&&r.startContainer.nodeType===3){r.setEnd(r.startContainer,Math.min(r.startContainer.length,r.startOffset+5));getSelection().removeAllRanges();getSelection().addRange(r);document.dispatchEvent(new Event('selectionchange'));}String(getSelection())")
        try #require(!selected.isEmpty)
        try await until { controller.hasSelection }
        #expect(controller.selectedQuote == selected)
        let selectionSize = web.bounds.size
        try mouse(window,x:150,y:window.contentView!.bounds.height-10)
        try await pause(300)
        #expect(controller.hasSelection)
        #expect(web.bounds.size == selectionSize)
        #expect(try await readerJavaScript(web,"String(getSelection())") == selected)
        controller.highlight(.purple)
        try await until { !controller.hasSelection && store.selectedBook?.notes.count == 1 }
        #expect(store.selectedBook?.notes.first?.quote == selected)
        store.showInspector = false
        controller.addBookmark()
        store.flush()
        let restored = LibraryStore(root:store.root)
        #expect(restored.books.first?.notes.first?.quote == selected)
        #expect(restored.books.first?.bookmarks == store.selectedBook?.bookmarks)
        try mouse(window,x:150,y:300)
        NotificationCenter.default.post(name:.lumaShowReaderChrome,object:nil)
        try await pause(300)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == false)
        _ = try await readerJavaScript(web,"var p=document.querySelector('#luma-content p');p.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,button:0,clientX:100,clientY:100}));p.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,button:0,clientX:100,clientY:100}));'ok'")
        try await pause(1600)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == true)
        let monetEnabled = store.monetEnabled
        store.monetEnabled = false
        for theme in [ReaderTheme.black,.rose,.paper] {
            store.theme = theme
            controller.updateSettings()
            try await pause(300)
            #expect(controller.illustrationWebView === web)
            #expect(store.error == nil)
            if theme == .black {
                #expect(try await readerJavaScript(web,"String(getComputedStyle(document.body).backgroundColor.match(/[0-9]+/g).slice(0,3).every(n=>Number(n)<80))") == "true")
            }
            try await readerSnapshot(web,name:"epub-theme-"+theme.rawValue+"-synthetic")
        }
        store.monetEnabled = monetEnabled
        controller.updateSettings()
        window.level = .normal
        window.makeKeyAndOrderFront(nil)
        window.toggleFullScreen(nil)
        try await until { window.styleMask.contains(.fullScreen) }
        try await pause(1200)
        #expect(controller.illustrationWebView === web)
        #expect(store.error == nil)
        #expect(try await readerJavaScript(web,"String(window.Luma.readingContext().visibleText.length > 0)") == "true")
        try await readerSnapshot(web,name:"epub-fullscreen-content-synthetic")
        window.toggleFullScreen(nil)
        try await until { !window.styleMask.contains(.fullScreen) }
        try await pause(1200)
        #expect(controller.illustrationWebView === web)
        #expect(store.error == nil)
        print("ReaderFixture keyboardChrome=true themedReading=true loadedFullscreen=true")
        print("ReaderFixture selectionPreserved=true highlightPersisted=true bookmarksPersisted=true")
        print("ReaderFixture twentyPageTurns=true rapidAIToggles=true narrowAI=true sameWebView=true")
    }
    @Test func syntheticPDFChromeKeepsViewportAndReadingPosition() async throws {
        prepareApplication()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LumaSyntheticPDF-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let document = PDFDocument()
        for index in 0..<48 {
            let image = NSImage(size:NSSize(width:600,height:800),flipped:false) { rect in
                NSColor.white.setFill(); rect.fill()
                ("Synthetic PDF page \(index+1)" as NSString).draw(at:NSPoint(x:40,y:700),withAttributes:[.font:NSFont.systemFont(ofSize:22),.foregroundColor:NSColor.black])
                return true
            }
            document.insert(try #require(PDFPage(image:image)),at:index)
        }
        let file = root.appendingPathComponent("fixture.pdf")
        try #require(document.write(to:file))
        let store = LibraryStore(root:root.appendingPathComponent("library"))
        #expect(await store.importFiles([file],provider:nil) == 1)
        let controller = ReaderController()
        let hostController = NSHostingController(rootView:ContentView(store:store,controller:controller).frame(minWidth:760,minHeight:620))
        let hosting = hostController.view
        let window = NSWindow(contentRect:NSRect(x:100,y:100,width:1100,height:760),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false; window.contentViewController = hostController
        window.setContentSize(NSSize(width:1100,height:760))
        window.level = .floating
        defer { window.close(); store.reader = nil; store.ai.flushHistory() }
        window.makeKeyAndOrderFront(nil)
        store.open(try #require(store.books.first))
        try await until { controller.presentationReady && controller.currentPDFPage != nil }
        try await pause(1000)
        let page = try #require(controller.currentPDFPage)
        let bounds = page.bounds(for:.mediaBox)
        let view = try #require(hosting.subviews.recursivePDFView)
        let size = view.bounds.size
        for _ in 0..<20 {
            try mouse(window,x:150,y:window.contentView!.bounds.height-10)
            try await pause(25)
            try mouse(window,x:150,y:10)
            try await pause(25)
            #expect(controller.currentPDFPage === page)
            #expect(view.bounds.size == size)
            #expect(page.bounds(for:.mediaBox) == bounds)
        }
        try mouse(window,x:150,y:300)
        try await pause(1700)
        #expect(window.standardWindowButton(.closeButton)?.isHidden == true)
        #expect(store.error == nil)
        print("ReaderFixture pdfEdgeCrossings=true viewportStable=true pagePreserved=true")
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

private extension Array where Element == NSView {
    @MainActor var recursivePDFView:PDFView? {
        for view in self {
            if let pdf = view as? PDFView { return pdf }
            if let pdf = view.subviews.recursivePDFView { return pdf }
        }
        return nil
    }
}

