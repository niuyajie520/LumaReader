// === PROJECT RED LINE / 项目红线 BEGIN ===
// 顶部悬停只控制显隐，不得改变正文、分页或窗口几何；窗口与全屏行为受保护。
// Hover controls visibility only; preserve text layout, pagination, window geometry, and full-screen behavior.
// 完整规则见项目根目录 AGENTS.md；所有开发者与 AI 必须遵守。
// All developers and AI assistants must follow the project-root AGENTS.md.
// === PROJECT RED LINE / 项目红线 END ===
import SwiftUI
import AppKit

// An inert native marker follows the actual SwiftUI header after safe-area layout.
// It does not intercept clicks and remains mounted when the buttons are hidden.
struct ReaderHeaderHoverRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> RegionView {
        let view = RegionView()
        view.identifier = NSUserInterfaceItemIdentifier("luma.reader.header.hover.region")
        return view
    }
    func updateNSView(_ view: RegionView, context: Context) {}
    final class RegionView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

struct ReaderChromeMonitor: NSViewRepresentable {
    var enabled: Bool
    var trailingInset: CGFloat
    var pageTurnPulse: Int = 0
    var onTopHover: (Bool) -> Void
    var onBottomHover: (Bool) -> Void = { _ in }
    var onSafeTopInset: (CGFloat) -> Void = { _ in }

    func makeNSView(context: Context) -> MonitorView { MonitorView() }
    func updateNSView(_ view: MonitorView, context: Context) {
        view.enabled = enabled
        view.trailingInset = trailingInset
        view.onTopHover = onTopHover
        view.onBottomHover = onBottomHover
        view.onSafeTopInset = onSafeTopInset
        view.installIfNeeded()
    }
    static func dismantleNSView(_ view: MonitorView, coordinator: ()) { view.stop() }

    final class MonitorView: NSView {
        var enabled = false
        var trailingInset: CGFloat = 0
        var onTopHover: (Bool) -> Void = { _ in }
        var onBottomHover: (Bool) -> Void = { _ in }
        var onSafeTopInset: (CGFloat) -> Void = { _ in }
        private var timer: Timer?
        private var eventMonitor: Any?
        private weak var observedWindow: NSWindow?
        private var previousMouseMoved = false
        private var lastInside: Bool?
        private var lastBottomInside: Bool?
        private var lastInset: CGFloat?
        private var transitioning = false
        private var nativeState: (visible: Bool, size: NSSize, inset: CGFloat, fullScreen: Bool)?
        private var windowObservers: [NSObjectProtocol] = []

        deinit {
            if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
            for observer in windowObservers { NotificationCenter.default.removeObserver(observer) }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            installIfNeeded()
        }

        func installIfNeeded() {
            guard enabled, let window else { stop(); return }
            if eventMonitor == nil {
                observedWindow = window
                for name in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification,
                             NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                    let observer = NotificationCenter.default.addObserver(forName:name, object:window, queue:.main) { [weak self] _ in
                        MainActor.assumeIsolated {
                            guard let self else { return }
                            self.transitioning = name == NSWindow.willEnterFullScreenNotification || name == NSWindow.willExitFullScreenNotification
                            if !self.transitioning { self.evaluateCurrentMouseLocation() }
                        }
                    }
                    windowObservers.append(observer)
                }
                for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                             NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                             NSWindow.didDeminiaturizeNotification, .lumaAppDidResignActive, .lumaRuntimeDidResume] {
                    windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated { self?.updatePolling() }
                    })
                }
                previousMouseMoved = window.acceptsMouseMovedEvents
                window.acceptsMouseMovedEvents = true
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDragged]) { [weak self] event in
                    guard let self, self.enabled, let window = self.observedWindow, event.window === window else { return event }
                    self.evaluateCurrentMouseLocation()
                    return event
                }
            }
            updatePolling()
        }

        private func updatePolling() {
            guard enabled, let window, NSApp.isActive, !LumaAppDelegate.displaySuspended,
                  window.isVisible, !window.isMiniaturized, window.occlusionState.contains(.visible) else {
                timer?.invalidate(); timer = nil; nativeState = nil
                updateInside(false); updateBottomInside(false)
                return
            }
            guard timer == nil else { return }
            // WKWebView and native titlebar can consume mouse-move events.
            // Read the actual screen pointer independently of their event routing.
            let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluateCurrentMouseLocation() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        func evaluateCurrentMouseLocation() {
            guard enabled, let window, !transitioning, NSApp.isActive, !LumaAppDelegate.displaySuspended,
                  window.isVisible, !window.isMiniaturized, window.occlusionState.contains(.visible) else { return }
            // Fixed geometry: revealing chrome must never repaginate the book.
            let inset: CGFloat = window.styleMask.contains(.fullScreen)
                ? max(NSStatusBar.system.thickness, window.screen?.safeAreaInsets.top ?? 0) : 0
            if lastInset != inset { lastInset = inset; onSafeTopInset(inset) }
            var top = false
            var bottom = false
            if NSApp.isActive, window.isKeyWindow, !window.isMiniaturized {
                let point = window.convertPoint(fromScreen:NSEvent.mouseLocation)
                let fromTop = window.frame.height - point.y
                let withinX = point.x >= 0 && point.x <= window.frame.width - trailingInset
                top = withinX && fromTop >= 0 && fromTop <= inset + 68
                bottom = withinX && point.y >= 0 && point.y <= 64
            }
            updateInside(top)
            updateBottomInside(bottom)
            let fullScreen = window.styleMask.contains(.fullScreen)
            if nativeState?.visible != top || nativeState?.size != window.frame.size || nativeState?.inset != inset || nativeState?.fullScreen != fullScreen {
                NativeWindowControls.restore(window, controlsVisible:top, animated:false,
                                             targetCenterFromTop:30, readerToolbar:true)
                nativeState = (top, window.frame.size, inset, fullScreen)
            }
        }

        private func updateInside(_ inside: Bool) {
            guard lastInside != inside else { return }
            lastInside = inside
            onTopHover(inside)
        }
        private func updateBottomInside(_ inside: Bool) {
            guard lastBottomInside != inside else { return }
            lastBottomInside = inside
            onBottomHover(inside)
        }
        func stop() {
            timer?.invalidate()
            timer = nil
            if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
            eventMonitor = nil
            observedWindow?.acceptsMouseMovedEvents = previousMouseMoved
            observedWindow = nil
            for observer in windowObservers { NotificationCenter.default.removeObserver(observer) }
            windowObservers.removeAll()
            transitioning = false
            nativeState = nil
            lastInside = nil
            lastBottomInside = nil
            lastInset = nil
        }
    }
}
