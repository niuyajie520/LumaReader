#if DEBUG
import AppKit
import WebKit
import ZIPFoundation

/// Explicit Debug-only native acceptance. A fresh UUID selects an isolated,
/// synthetic library; normal launches and Release builds never enter this path.
@MainActor enum DebugReaderAcceptance {
    private static let prefix = "--luma-reader-acceptance="
    private static var token:UUID? {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return UUID(uuidString:String(arg.dropFirst(prefix.count)))
    }
    private static var started = false
    private static var phase = "startup"
    private static var failedLine:UInt = 0
    private static var windowState:[String:Any] = [:]
    private static var evidenceFolder:String? {
        let prefix = "--luma-reader-evidence="
        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix(prefix) }) { return String(argument.dropFirst(prefix.count)) }
        return ProcessInfo.processInfo.environment["LUMA_SYNTHETIC_UI_EVIDENCE"]
    }
    private enum Failure:Error { case check, timeout }
    private static func root(_ token:UUID) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LumaReader-ReaderProbe-"+token.uuidString)
    }
    static func makeStore() -> LibraryStore {
        guard let token else { return LibraryStore() }
        return LibraryStore(root:root(token).appendingPathComponent("library"))
    }
    static func startIfRequested(store:LibraryStore,controller:ReaderController) {
        guard !started, let token,
              store.root.standardizedFileURL.path == root(token).appendingPathComponent("library").standardizedFileURL.path else { return }
        started = true
        Task { @MainActor in
            var report:[String:Any] = ["status":"FAIL", "method":"Debug app process with native SwiftUI lifecycle", "physicalInput":"NOT RUN"]
            do {
                try await run(store:store,controller:controller,root:root(token))
                report["status"] = "PASS"
            } catch {
                report["errorCode"] = (error as NSError).code
                report["failedLine"] = failedLine
            }
            report["phase"] = phase
            report["windowState"] = windowState
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("luma-reader-acceptance-"+token.uuidString+".json")
            if let data = try? JSONSerialization.data(withJSONObject:report,options:.sortedKeys) {
                try? data.write(to:file,options:.atomic)
            }
            NSApp.terminate(nil)
        }
    }
    private static func check(_ condition:Bool,line:UInt = #line) throws {
        guard condition else { failedLine = line; throw Failure.check }
    }
    private static func require<T>(_ value:T?,line:UInt = #line) throws -> T {
        guard let value else { failedLine = line; throw Failure.check }
        return value
    }
    private static func require(_ condition:Bool,line:UInt = #line) throws {
        try check(condition,line:line)
    }
    private static func pause(_ ms:Int) async throws {
        try await Task.sleep(for:.milliseconds(ms))
    }
    private static func until(_ condition:()->Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if condition() { return }
            try await pause(20)
        }
        throw Failure.timeout
    }
    private static func epub(_ root:URL) throws -> URL {
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
    private static func mouse(_ window:NSWindow,x:CGFloat,y:CGFloat) throws {
        let event = try require(NSEvent.mouseEvent(with:.mouseMoved,location:NSPoint(x:x,y:y),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:0,pressure:0))
        NSApp.sendEvent(event)
    }
    private static func screenshot(_ view:NSView,name:String) throws {
        guard let folder = evidenceFolder else { return }
        let root = URL(fileURLWithPath:folder,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        view.layoutSubtreeIfNeeded()
        let bitmap = try require(view.bitmapImageRepForCachingDisplay(in:view.bounds))
        view.cacheDisplay(in:view.bounds,to:bitmap)
        let data = try require(bitmap.representation(using:.png,properties:[:]))
        try data.write(to:root.appendingPathComponent(name+".png"),options:.atomic)
    }
    private static func webState(_ web:WKWebView) async {
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
    private static func readerSnapshot(_ web:WKWebView,name:String) async throws {
        guard let folder = evidenceFolder else { return }
        let image:NSImage = try await withCheckedThrowingContinuation { continuation in
            web.takeSnapshot(with:nil) { image,error in
                if let error { continuation.resume(throwing:error) }
                else if let image { continuation.resume(returning:image) }
                else { continuation.resume(throwing:CocoaError(.fileReadUnknown)) }
            }
        }
        let tiff = try require(image.tiffRepresentation)
        let bitmap = try require(NSBitmapImageRep(data:tiff))
        let png = try require(bitmap.representation(using:.png,properties:[:]))
        try png.write(to:URL(fileURLWithPath:folder).appendingPathComponent(name+".png"),options:.atomic)
    }
    private static func webViews(in view:NSView) -> [WKWebView] {
        if let web = view as? WKWebView { return [web] }
        return view.subviews.flatMap { webViews(in:$0) }
    }
    private static func readerJavaScript(_ web:WKWebView,_ script:String,world:WKContentWorld? = nil) async throws -> String {
        let contentWorld = world ?? WKContentWorld.world(name:"LumaReader")
        return try await withCheckedThrowingContinuation { continuation in
            web.evaluateJavaScript(script,in:nil,in:contentWorld) { result in
                switch result {
                case .success(let value): continuation.resume(returning:value as? String ?? "")
                case .failure(let error): continuation.resume(throwing:error)
                }
            }
        }
    }
    private static func run(store:LibraryStore,controller:ReaderController,root:URL) async throws {
        phase = "mount"
        try await until { NSApp.windows.contains { $0.canBecomeMain && $0.isVisible } }
        let window = try require(NSApp.windows.first { $0.canBecomeMain && $0.isVisible })
        let hosting = try require(window.contentView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
        try check(await store.importFiles([try epub(root)],provider:nil) == 1)
        let book = try require(store.books.first)
        store.open(book)
        try await pause(500)
        try require(hosting.bounds.width >= 760 && hosting.bounds.height >= 620)
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
        phase = "chrome"
        let web = try require(controller.illustrationWebView)
        let size = web.bounds.size
        try await readerSnapshot(web,name:"epub-rendered-content-synthetic")
        // The entry hint has expired. Quiet reading must not retain native
        // buttons or invisible click targets over the actual book.
        try await pause(550)
        try check(window.standardWindowButton(.closeButton)?.isHidden == true)
        try check(window.standardWindowButton(.miniaturizeButton)?.isHidden == true)
        try check(window.standardWindowButton(.zoomButton)?.isHidden == true)
        try screenshot(hosting,name:"reader-hidden-synthetic")
        try mouse(window,x:150,y:window.contentView!.bounds.height-10)
        try await pause(300)
        try check(window.standardWindowButton(.closeButton)?.isHidden == false)
        try check(NativeWindowControls.snapshot(window).values.allSatisfy { $0 })
        try screenshot(hosting,name:"reader-top-synthetic")
        try mouse(window,x:150,y:300)
        try await pause(1700)
        try check(window.standardWindowButton(.closeButton)?.isHidden == true)
        try mouse(window,x:150,y:10)
        try await pause(300)
        try check(window.standardWindowButton(.closeButton)?.isHidden == false)
        try check(controller.illustrationWebView === web)
        try check(web.bounds.size == size)
        try screenshot(hosting,name:"reader-bottom-synthetic")
        for _ in 0..<20 {
            try mouse(window,x:150,y:window.contentView!.bounds.height-10)
            try mouse(window,x:150,y:300)
        }
        try await pause(1700)
        try check(window.standardWindowButton(.closeButton)?.isHidden == true)
        try check(controller.illustrationWebView === web)
        phase = "twenty-page-turns"
        for _ in 0..<20 {
            let before = store.selectedBook?.readerOffset
            try check(controller.canGoForward)
            controller.move(1)
            try await until { !controller.isTurning && store.selectedBook?.readerOffset != before }
            try check(controller.illustrationWebView === web)
            try check(store.error == nil)
        }
        phase = "AI-interruptions"
        let saved = try require(store.selectedBook?.readerAnchor)
        for _ in 0..<10 {
            store.aiPanelVisible = true
            try await pause(70)
            store.aiPanelVisible = false
        }
        try await pause(1600)
        try check(controller.illustrationWebView === web)
        print("ReaderFixture anchorBefore=\(saved.start) anchorAfter=\(store.selectedBook?.readerAnchor?.start ?? -1)")
        try check(store.selectedBook?.readerAnchor == saved)
        try check(store.error == nil)
        window.setContentSize(NSSize(width:760,height:620))
        store.aiPanelVisible = true
        store.aiPanelExpanded = true
        try await pause(1600)
        try check(web.bounds.width >= 300)
        try check(controller.illustrationWebView === web)
        try check(store.error == nil)
        try await readerSnapshot(web,name:"epub-narrow-ai-content-synthetic")
        phase = "embedded-AI"
        try screenshot(hosting,name:"reader-narrow-ai-synthetic")
        let aiWeb = try require(webViews(in:hosting).first { $0 !== web })
        try check(try await readerJavaScript(aiWeb,"String(!!window.LumaAI&&!!document.getElementById('draft'))",world:.page) == "true")
        let readerPaper = try await readerJavaScript(web,"getComputedStyle(document.body).backgroundColor")
        let aiPaper = try await readerJavaScript(aiWeb,"getComputedStyle(document.body).backgroundColor",world:.page)
        try check(readerPaper == aiPaper)
        store.aiPanelVisible = false
        try await pause(1600)
        phase = "selection-and-persistence"
        let selected = try await readerJavaScript(web,"""
        (()=>{
          const root=document.getElementById('luma-content');
          const viewport=document.getElementById('luma-viewport').getBoundingClientRect();
          for(let y=viewport.top+12;y<viewport.bottom-12;y+=18){
            for(let x=viewport.left+6;x<viewport.right-6;x+=24){
              const r=document.caretRangeFromPoint(x,y),node=r?.startContainer;
              if(!node||node.nodeType!==3||node.length<5||!root.contains(node))continue;
              const at=Math.max(0,Math.min(r.startOffset,node.length-5));
              r.setStart(node,at);r.setEnd(node,at+5);
              const rects=[...r.getClientRects()];
              if(!r.toString().trim()||!rects.length||!rects.every(b=>b.width>0&&b.left>=viewport.left&&b.right<=viewport.right&&b.top>=viewport.top&&b.bottom<=viewport.bottom))continue;
              getSelection().removeAllRanges();getSelection().addRange(r);
              document.dispatchEvent(new Event('selectionchange'));
              return String(getSelection());
            }
          }
          return '';
        })()
        """)
        try require(!selected.isEmpty)
        try await until { controller.hasSelection }
        try check(controller.selectedQuote == selected)
        let selectionSize = web.bounds.size
        try mouse(window,x:150,y:window.contentView!.bounds.height-10)
        try await pause(300)
        try check(controller.hasSelection)
        try check(web.bounds.size == selectionSize)
        try check(try await readerJavaScript(web,"String(getSelection())") == selected)
        controller.highlight(.purple)
        try await until { !controller.hasSelection && store.selectedBook?.notes.count == 1 }
        try check(store.selectedBook?.notes.first?.quote == selected)
        store.showInspector = false
        controller.addBookmark()
        try check(store.selectedBook?.bookmarks?.count == 1)
        store.flush()
        let restored = LibraryStore(root:store.root)
        try check(restored.books.first?.notes.first?.quote == selected)
        try check(restored.books.first?.bookmarks == store.selectedBook?.bookmarks)
        try mouse(window,x:150,y:300)
        NotificationCenter.default.post(name:.lumaShowReaderChrome,object:nil)
        try await pause(300)
        try check(window.standardWindowButton(.closeButton)?.isHidden == false)
        // Regression: keyboard-revealed chrome must expire while the mouse is
        // idle over book text, without requiring an extra click to unpin it.
        try await pause(1700)
        try check(window.standardWindowButton(.closeButton)?.isHidden == true)
        NotificationCenter.default.post(name:.lumaShowReaderChrome,object:nil)
        try await pause(250)
        try check(window.standardWindowButton(.closeButton)?.isHidden == false)
        _ = try await readerJavaScript(web,"var p=document.querySelector('#luma-content p');p.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,button:0,clientX:100,clientY:100}));p.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,button:0,clientX:100,clientY:100}));'ok'")
        try await pause(1600)
        try check(window.standardWindowButton(.closeButton)?.isHidden == true)
        phase = "themes-and-keyboard"
        let monetEnabled = store.monetEnabled
        store.monetEnabled = false
        for theme in [ReaderTheme.black,.rose,.paper] {
            store.theme = theme
            controller.updateSettings()
            try await pause(300)
            try check(controller.illustrationWebView === web)
            try check(store.error == nil)
            if theme == .black {
                try check(try await readerJavaScript(web,"String(getComputedStyle(document.body).backgroundColor.match(/[0-9]+/g).slice(0,3).every(n=>Number(n)<80))") == "true")
            }
            try await readerSnapshot(web,name:"epub-theme-"+theme.rawValue+"-synthetic")
        }
        store.monetEnabled = monetEnabled
        controller.updateSettings()
        phase = "fullscreen-entry"
        window.level = .normal
        NSApp.activate(ignoringOtherApps:true)
        window.makeKeyAndOrderFront(nil)
        try await pause(700)
        windowState = ["active":NSApp.isActive,"key":window.isKeyWindow,"level":window.level.rawValue,
                       "collectionBehavior":window.collectionBehavior.rawValue,"styleMask":window.styleMask.rawValue,
                       "attachedSheet":window.attachedSheet != nil,"zoomEnabled":window.standardWindowButton(.zoomButton)?.isEnabled == true]
        try await until { NSApp.isActive && window.isKeyWindow }
        // The zoom button can be disabled by AppKit while immersive chrome is hidden.
        // Test NSWindow's fullscreen action itself, including in that hidden state.
        try check(window.styleMask.contains(.resizable))
        window.toggleFullScreen(nil)
        do { try await until { window.styleMask.contains(.fullScreen) } }
        catch {
            windowState["afterToggleStyleMask"] = window.styleMask.rawValue
            windowState["afterToggleZoomEnabled"] = window.standardWindowButton(.zoomButton)?.isEnabled == true
            windowState["afterToggleWindowKey"] = window.isKeyWindow
            throw error
        }
        try await pause(1200)
        try check(controller.illustrationWebView === web)
        try check(store.error == nil)
        try check(try await readerJavaScript(web,"String(window.Luma.readingContext().visibleText.length > 0)") == "true")
        try await readerSnapshot(web,name:"epub-fullscreen-content-synthetic")
        phase = "fullscreen-exit"
        window.toggleFullScreen(nil)
        try await until { !window.styleMask.contains(.fullScreen) }
        try await pause(1200)
        try mouse(window,x:150,y:window.contentView!.bounds.height-10)
        try await pause(350)
        try check(NativeWindowControls.snapshot(window).values.allSatisfy { $0 })
        try check(controller.illustrationWebView === web)
        try check(store.error == nil)
        print("ReaderFixture keyboardChrome=true themedReading=true loadedFullscreen=true")
        print("ReaderFixture selectionPreserved=true highlightPersisted=true bookmarksPersisted=true")
        print("ReaderFixture twentyPageTurns=true rapidAIToggles=true narrowAI=true sameWebView=true")
        phase = "complete"
    }
}
#endif
