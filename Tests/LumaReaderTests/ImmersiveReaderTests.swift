import AppKit
import SwiftUI
import PDFKit
import QuartzCore
import Testing
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
    private func mouse(_ window:NSWindow,x:CGFloat,y:CGFloat) throws {
        let event = try #require(NSEvent.mouseEvent(with:.mouseMoved,location:NSPoint(x:x,y:y),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:0,pressure:0))
        NSApp.sendEvent(event)
    }
    @Test func syntheticEPUBChromeRevealsHidesAndKeepsWebView() async throws {
        let token = UUID()
        let report = FileManager.default.temporaryDirectory.appendingPathComponent("luma-reader-acceptance-"+token.uuidString+".json")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LumaReader-ReaderProbe-"+token.uuidString)
        let process = Process()
        defer {
            if process.isRunning { process.terminate() }
            try? FileManager.default.removeItem(at:report)
            try? FileManager.default.removeItem(at:root)
        }
        var directory = URL(fileURLWithPath:CommandLine.arguments[0]).deletingLastPathComponent()
        var executable:URL?
        if let path = ProcessInfo.processInfo.environment["LUMA_NATIVE_PROBE_EXECUTABLE"], FileManager.default.isExecutableFile(atPath:path) {
            executable = URL(fileURLWithPath:path)
        }
        for _ in 0..<8 {
            if executable != nil { break }
            let candidate = directory.appendingPathComponent("LumaReader")
            if FileManager.default.isExecutableFile(atPath:candidate.path) { executable = candidate; break }
            directory.deleteLastPathComponent()
        }
        process.executableURL = try #require(executable)
        process.arguments = ["--luma-reader-acceptance="+token.uuidString]
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let logURL = root.appendingPathComponent("process.log")
        FileManager.default.createFile(atPath:logURL.path,contents:nil)
        let log = try FileHandle(forWritingTo:logURL)
        defer { try? log.close() }
        process.standardOutput = log
        process.standardError = log
        try process.run()
        let deadline = Date().addingTimeInterval(180)
        while process.isRunning && Date() < deadline { try await Task.sleep(for:.milliseconds(50)) }
        try #require(!process.isRunning, "Native reader application probe did not finish")
        #expect(process.terminationStatus == 0)
        if !FileManager.default.fileExists(atPath:report.path) {
            print("ReaderFixture processLog="+String((try? String(contentsOf:logURL,encoding:.utf8))?.suffix(3000) ?? ""))
        }
        let data = try Data(contentsOf:report)
        let value = try #require(JSONSerialization.jsonObject(with:data) as? [String:Any])
        print("ReaderFixture applicationProbe="+String(decoding:data,as:UTF8.self))
        if value["status"] as? String != "PASS" {
            print("ReaderFixture processLog="+String((try? String(contentsOf:logURL,encoding:.utf8))?.suffix(3000) ?? ""))
        }
        #expect(value["status"] as? String == "PASS")
        #expect(value["phase"] as? String == "complete")
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

