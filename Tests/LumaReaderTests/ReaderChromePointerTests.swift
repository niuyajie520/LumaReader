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
    }
    @Test func eventsForAnotherWindowDoNotChangeTheReadingHover() throws {
        _ = NSApplication.shared
        let first = NSWindow(contentRect:NSRect(x:0,y:0,width:940,height:620),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        let second = NSWindow(contentRect:NSRect(x:0,y:0,width:940,height:620),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        first.isReleasedWhenClosed = false; second.isReleasedWhenClosed = false
        let monitor = ReaderChromeMonitor.MonitorView(); monitor.enabled = true
        var transitions:[Bool] = []
        monitor.onTopHover = { transitions.append($0) }
        first.contentView!.addSubview(monitor); monitor.installIfNeeded()
        defer { monitor.stop(); first.close(); second.close() }
        for window in [second,first] {
            let point = NSPoint(x:150,y:window.contentView!.bounds.height-10)
            let event = try #require(NSEvent.mouseEvent(with:.mouseMoved,location:point,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:0,pressure:0))
            NSApp.sendEvent(event)
            #expect(transitions == (window === second ? []:[true]))
        }
    }
    @Test func authoritativeQuietStateSurvivesInterruptedNativeFades() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:940,height:620),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<20 {
            NativeWindowControls.restore(window,controlsVisible:true,animated:true)
            NativeWindowControls.restore(window,controlsVisible:false,animated:true)
        }
        NativeWindowControls.restore(window,controlsVisible:false,animated:false)
        try await Task.sleep(for:.milliseconds(500))
        for type in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] {
            let button = try #require(window.standardWindowButton(type))
            #expect(button.isHidden)
            #expect(button.alphaValue == 0)
        }
    }

}
