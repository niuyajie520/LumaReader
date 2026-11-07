import AppKit

@MainActor enum NativeWindowControls {
    static func restore(_ window: NSWindow, controlsVisible:Bool = true, animated:Bool = false) {
        // Let macOS own fullscreen chrome; restore only ordinary window controls.
        guard !window.styleMask.contains(.fullScreen), !window.isMiniaturized else { return }
        let required: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        if !window.styleMask.isSuperset(of: required) { window.styleMask.formUnion(required) }
        if !window.collectionBehavior.contains(.fullScreenPrimary) {
            window.collectionBehavior.insert(.fullScreenPrimary)
        }
        window.isMovable = true
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(type) else { continue }
            let target:CGFloat = controlsVisible ? 1:0
            if controlsVisible && button.isHidden { button.alphaValue = animated ? 0:1; button.isHidden = false }
            if window.attachedSheet == nil { button.isEnabled = controlsVisible }
            if animated && button.alphaValue != target {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = controlsVisible ? 0.20:0.16
                    button.animator().alphaValue = target
                } completionHandler: { [weak button] in
                    MainActor.assumeIsolated {
                        // A reversed transition has a different model alpha: never apply a stale hide.
                        if let button, button.alphaValue == 0 { button.isHidden = true }
                    }
                }
            } else if !animated {
                button.alphaValue = target; button.isHidden = !controlsVisible
            }

        }
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
