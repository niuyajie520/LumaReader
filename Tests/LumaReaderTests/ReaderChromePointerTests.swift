import AppKit
import Testing
@testable import LumaReader

@MainActor @Suite(.serialized)
struct ReaderChromePointerTests {
    @Test func rapidDeliveredEdgeCrossingsEndAtTheLastEventPosition() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:940,height:620),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        let monitor = ReaderChromeMonitor.MonitorView()
        monitor.enabled = true
        var transitions:[Bool] = []
        monitor.onTopHover = { transitions.append($0) }
        window.contentView!.addSubview(monitor)
        monitor.installIfNeeded()
        defer { monitor.stop(); window.close() }
        let top = NSPoint(x:150,y:window.contentView!.bounds.height-10)
        let center = NSPoint(x:150,y:300)
        for _ in 0..<20 {
            for point in [top,center] {
                let event = try #require(NSEvent.mouseEvent(with:.mouseMoved,location:point,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:0,pressure:0))
                NSApp.sendEvent(event)
            }
        }
        #expect(transitions.count == 40)
        #expect(transitions.last == false)
        #expect(ReaderChromePointer.location(in:window) == center)
    }
    @Test func recordedLocationsNeverLeakToAnotherWindow() {
        _ = NSApplication.shared
        let first = NSWindow(), second = NSWindow()
        let point = NSPoint(x:17,y:23)
        ReaderChromePointer.record(point,in:first)
        #expect(ReaderChromePointer.location(in:first) == point)
        #expect(ReaderChromePointer.location(in:second) == second.mouseLocationOutsideOfEventStream)
        ReaderChromePointer.clear(in:second)
        #expect(ReaderChromePointer.location(in:first) == point)
        ReaderChromePointer.clear(in:first)
        #expect(ReaderChromePointer.location(in:first) == first.mouseLocationOutsideOfEventStream)
    }
}
