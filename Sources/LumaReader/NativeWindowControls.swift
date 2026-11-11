import AppKit
import ObjectiveC
import os

@MainActor
enum NativeWindowControls {
    private static var stateKey: UInt8 = 0
    private final class VisibilityState: NSObject {
        var visible: Bool?
        var revision = 0
        var readerHost: ReaderControlsHost?
    }
    private final class ReaderControlsHost: NSView {
        @MainActor final class Placement {
            let button: NSButton
            weak var parent: NSView?
            let frame: NSRect
            let parentWasHidden: Bool
            init(_ button: NSButton) {
                self.button = button; self.parent = button.superview; self.frame = button.frame
                self.parentWasHidden = button.superview?.isHidden ?? false
            }
        }
        var placements: [Placement] = []
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from:superview)
            for button in subviews where !button.isHidden && button.alphaValue > 0.01 {
                if button.frame.contains(local) { return button.hitTest(local) }
            }
            return nil
        }
        func install(in window: NSWindow, buttons: [NSButton], center: CGFloat) {
            guard let root = window.contentView?.superview else { return }
            if superview !== root { removeFromSuperview(); root.addSubview(self, positioned:.above, relativeTo:nil) }
            let topInset: CGFloat = window.styleMask.contains(.fullScreen)
                ? max(NSStatusBar.system.thickness, window.screen?.safeAreaInsets.top ?? 0) : 0
            let height: CGFloat = 60
            frame = NSRect(x:0, y:root.isFlipped ? topInset : root.bounds.height - topInset - height,
                           width:100, height:height)
            for (index, button) in buttons.enumerated() {
                if button.superview !== self {
                    if !placements.contains(where:{ $0.button === button }) { placements.append(Placement(button)) }
                    button.removeFromSuperview()
                    addSubview(button)
                }
                // Match the existing left capsule's 60pt lane, without moving
                // AppKit's private titlebar host or scheduling delayed frame writes.
                button.setFrameOrigin(NSPoint(x:10 + CGFloat(index) * 22, y:center - button.frame.height / 2))
            }
            // The original native titlebar is a second row in full screen.
            // Its real buttons now live beside the existing capsules above it;
            // suppress only its visual host, without changing window geometry.
            for placement in placements {
                placement.parent?.isHidden = window.styleMask.contains(.fullScreen) ? true : placement.parentWasHidden
            }
        }
        func restore() {
            for placement in placements {
                placement.parent?.isHidden = placement.parentWasHidden
                guard placement.button.superview === self, let parent = placement.parent else { continue }
                placement.button.removeFromSuperview()
                parent.addSubview(placement.button)
                placement.button.frame = placement.frame
                placement.button.isHidden = false
                placement.button.alphaValue = 1
                placement.button.isEnabled = true
            }
            placements.removeAll()
            removeFromSuperview()
        }
    }
    static func restore(_ window: NSWindow, controlsVisible: Bool = true, animated: Bool = false, targetCenterFromTop: CGFloat = 22, readerToolbar: Bool = false) {
        if !window.styleMask.contains(.fullScreen) {
            if !window.collectionBehavior.contains(.fullScreenPrimary) {
                window.collectionBehavior.insert(.fullScreenPrimary)
            }
        }
        if !window.isMovable {
            window.isMovable = true
        }
        let effectiveVisible = controlsVisible
        let state: VisibilityState
        if let existing = objc_getAssociatedObject(window, &stateKey) as? VisibilityState { state = existing }
        else { state = VisibilityState(); objc_setAssociatedObject(window, &stateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }

        alignTrafficLights(window, targetCenterFromTop:targetCenterFromTop, readerToolbar:readerToolbar)
        let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window.standardWindowButton($0) }
        let targetAlpha: CGFloat = effectiveVisible ? 1 : 0
        let alreadyInTargetState = (state.visible == effectiveVisible) && buttons.allSatisfy { btn in
            btn.isHidden == !effectiveVisible && abs(btn.alphaValue - targetAlpha) < 0.01 && (!effectiveVisible || window.attachedSheet != nil || btn.isEnabled)
        }
        if alreadyInTargetState {
            return
        }

        state.visible = effectiveVisible
        state.revision += 1
        let revision = state.revision
        for button in buttons {
            if effectiveVisible {
                if button.isHidden { button.isHidden = false }
                if window.attachedSheet == nil && !button.isEnabled { button.isEnabled = true }
            }
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = effectiveVisible ? 0.20 : 0.16
                for button in buttons { button.animator().alphaValue = targetAlpha }
            } completionHandler: { [weak window] in
                MainActor.assumeIsolated {
                    guard let window,
                          let current = objc_getAssociatedObject(window, &stateKey) as? VisibilityState,
                          current.revision == revision else { return }
                    let vis = (current.visible == true)
                    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                        guard let btn = window.standardWindowButton(type) else { continue }
                        let desiredAlpha: CGFloat = vis ? 1 : 0
                        if abs(btn.alphaValue - desiredAlpha) > 0.01 { btn.alphaValue = desiredAlpha }
                        if btn.isHidden != !vis { btn.isHidden = !vis }
                    }
                }
            }
        } else {
            for button in buttons {
                if abs(button.alphaValue - targetAlpha) > 0.01 { button.alphaValue = targetAlpha }
                if button.isHidden != !effectiveVisible { button.isHidden = !effectiveVisible }
            }
        }
    }

    ///Debug/verification: (target, measured) after the latest alignment, in points from the window top.
    private(set) static var lastMeasurement: [ObjectIdentifier: (target: CGFloat, measured: CGFloat)] = [:]

    /// Shifts the three native traffic light buttons slightly left (x = 10, 29, 48) inside their native NSTitlebarView
    /// so they stay compactly tucked in the top-left corner away from functional toolbar buttons, without mutating
    /// NSTitlebarContainerView.frame or vertical y coordinates (which previously caused AppKit relayout flicker).
    static func alignTrafficLights(_ window: NSWindow, targetCenterFromTop: CGFloat = 22.0, readerToolbar: Bool = false) {
        let state: VisibilityState
        if let existing = objc_getAssociatedObject(window, &stateKey) as? VisibilityState { state = existing }
        else { state = VisibilityState(); objc_setAssociatedObject(window, &stateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
        if readerToolbar {
            let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window.standardWindowButton($0) }
            let host = state.readerHost ?? ReaderControlsHost()
            state.readerHost = host
            host.install(in:window, buttons:buttons, center:targetCenterFromTop)
            if let measured = measuredCenterFromTop(window) {
                lastMeasurement[ObjectIdentifier(window)] = (targetCenterFromTop, measured)
            }
            return
        }
        if let host = state.readerHost { host.restore(); state.readerHost = nil; state.visible = nil }
        guard !window.styleMask.contains(.fullScreen) else { return }
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = types.compactMap { window.standardWindowButton($0) }
        let startX: CGFloat = 10.0
        let spacingX: CGFloat = 19.0
        var didMove = false
        for (idx, button) in buttons.enumerated() {
            var bFrame = button.frame
            let targetX = startX + CGFloat(idx) * spacingX
            if abs(bFrame.origin.x - targetX) > 0.5 {
                bFrame.origin.x = targetX
                button.frame = bFrame
                didMove = true
            }
        }
        if didMove, let tb = buttons.first?.superview {
            tb.updateTrackingAreas()
        }
        let winID = ObjectIdentifier(window)
        if let measured = measuredCenterFromTop(window) {
            lastMeasurement[winID] = (targetCenterFromTop, measured)
        }
    }

    /// Average vertical center of the three buttons, measured from the window's top edge.
    static func measuredCenterFromTop(_ window: NSWindow) -> CGFloat? {
        guard let frameView = window.contentView?.superview else { return nil }
        let centers: [CGFloat] = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { type in
            guard let button = window.standardWindowButton(type), button.superview != nil else { return nil }
            let rect = button.convert(button.bounds, to: frameView)
            return frameView.isFlipped ? rect.midY : frameView.bounds.height - rect.midY
        }
        guard !centers.isEmpty else { return nil }
        return centers.reduce(0, +) / CGFloat(centers.count)
    }

    static func snapshot(_ window: NSWindow) -> [String: Bool] {
        var result: [String: Bool] = ["visible":window.isVisible, "resizable":window.styleMask.contains(.resizable), "movable":window.isMovable]
        for (name, type) in [("close",NSWindow.ButtonType.closeButton), ("minimize",.miniaturizeButton), ("zoom",.zoomButton)] {
            guard let button = window.standardWindowButton(type) else { result[name] = false; continue }
            result[name] = button.window === window && !button.isHiddenOrHasHiddenAncestor && button.alphaValue > 0.9 && button.isEnabled
            if let frame = window.contentView?.superview {
                let center = NSPoint(x:button.bounds.midX,y:button.bounds.midY)
                let point = button.convert(center,to:frame.superview)
                let hit = frame.hitTest(point)
                result[name+"HitTarget"] = hit === button || hit?.isDescendant(of:button) == true
            } else { result[name+"HitTarget"] = false }
        }
        return result
    }
}

/// Explicit CI-only invocation. Uses real AppKit window actions, no screenshots,
/// Accessibility permissions, book content, window titles or customer data.
@MainActor enum WindowControlsProbe {
    private static var started = false
    static func startIfRequested(_ window: NSWindow) {
        let prefix = "--luma-window-controls-probe="
        guard !started, let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
              let token = UUID(uuidString: String(argument.dropFirst(prefix.count))) else { return }
        started = true
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("luma-window-controls-\(token.uuidString).json")
        let inspect = ProcessInfo.processInfo.arguments.contains("--luma-window-inspect-only")
        Task { @MainActor in
            let report = Report(file:file)
            guard await waitUntil({ window.isVisible && !NSScreen.screens.isEmpty }) else {
                report.save("BLOCKED"); NSApp.terminate(nil); return
            }
            NSApp.activate(ignoringOtherApps:true)
            window.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for:.milliseconds(700))
            report.checks = NativeWindowControls.snapshot(window)
            if inspect { report.save(report.checks.values.allSatisfy { $0 } ? "PASS":"FAIL"); NSApp.terminate(nil); return }
            let original = window.frame
            var small = original
            small.size.width = max(window.minSize.width,original.width-80)
            small.size.height = max(window.minSize.height,original.height-60)
            window.setFrame(small,display:true)
            report.checks["resize"] = window.frame.size != original.size
            let origin = window.frame.origin
            window.setFrameOrigin(NSPoint(x:origin.x+12,y:origin.y-12))
            report.checks["move"] = window.frame.origin != origin
            window.standardWindowButton(.miniaturizeButton)?.performClick(nil)
            report.checks["minimized"] = await waitUntil { window.isMiniaturized }
            try? await Task.sleep(for:.milliseconds(700))
            window.deminiaturize(nil)
            report.checks["restored"] = await waitUntil { window.isVisible && !window.isMiniaturized }
            try? await Task.sleep(for:.milliseconds(700))
            let beforeZoom = window.frame
            let zoomed = window.isZoomed
            window.standardWindowButton(.zoomButton)?.performClick(nil)
            report.checks["greenAction"] = await waitUntil { window.isZoomed != zoomed || window.frame != beforeZoom || window.styleMask.contains(.fullScreen) }
            try? await Task.sleep(for:.milliseconds(700))
            if window.styleMask.contains(.fullScreen) {
                try? await Task.sleep(for:.seconds(1))
                window.toggleFullScreen(nil)
                _ = await waitUntil { !window.styleMask.contains(.fullScreen) }
                try? await Task.sleep(for:.seconds(1))
            }
            window.setFrame(original,display:true)
            window.toggleFullScreen(nil)
            report.checks["enteredFullScreen"] = await waitUntil { window.styleMask.contains(.fullScreen) }
            try? await Task.sleep(for:.seconds(1))
            if window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
            report.checks["exitedFullScreen"] = await waitUntil { !window.styleMask.contains(.fullScreen) }
            try? await Task.sleep(for:.seconds(1))
            let observer = NotificationCenter.default.addObserver(forName:NSWindow.willCloseNotification,object:window,queue:.main) { _ in
                MainActor.assumeIsolated {
                    report.checks["closed"] = true
                    report.save(report.checks.values.allSatisfy { $0 } ? "PASS":"FAIL")
                }
            }
            window.standardWindowButton(.closeButton)?.performClick(nil)
            if report.checks["closed"] != true { report.checks["closed"] = false; report.save("FAIL") }
            NotificationCenter.default.removeObserver(observer)
            NSApp.terminate(nil)
        }
    }
    @MainActor private final class Report {
        let file: URL
        var checks: [String:Bool] = [:]
        init(file:URL) { self.file = file }
        func save(_ status:String) {
            let value:[String:Any] = ["status":status,"checks":checks,"method":"real NSWindow/NSButton actions", "physicalMouseTest":"NOT RUN", "readingStateTest":"NOT RUN"]
            if let data = try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) {
                try? data.write(to:file,options:.atomic)
                try? FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
            }
        }
    }
    private static func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<120 {
            if condition() { return true }
            do { try await Task.sleep(for:.milliseconds(100)) } catch { return false }
        }
        return condition()
    }
}
