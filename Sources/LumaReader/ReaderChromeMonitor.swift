import SwiftUI
import AppKit


/// The same delivered window coordinates drive hover and idle expiration.
/// Synthetic native events do not move AppKit's global hardware cursor.
@MainActor enum ReaderChromePointer {
    private static weak var recordedWindow: NSWindow?
    private static var recordedPoint: NSPoint?
    static func record(_ point: NSPoint, in window: NSWindow) {
        recordedWindow = window; recordedPoint = point
    }
    static func location(in window: NSWindow) -> NSPoint {
        if recordedWindow === window, let recordedPoint { return recordedPoint }
        return window.mouseLocationOutsideOfEventStream
    }
    static func clear(in window: NSWindow?) {
        guard recordedWindow === window else { return }
        recordedWindow = nil; recordedPoint = nil
    }
}

struct ReaderChromeMonitor: NSViewRepresentable {
    var enabled: Bool
    var trailingInset: CGFloat
    var onTopHover: (Bool) -> Void
    func makeNSView(context:Context) -> MonitorView { MonitorView() }
    func updateNSView(_ view:MonitorView, context:Context) {
        let insetChanged = view.trailingInset != trailingInset
        view.enabled = enabled; view.trailingInset = trailingInset; view.onTopHover = onTopHover; view.installIfNeeded()
        if insetChanged && enabled { view.evaluateCurrentMouseLocation() }
    }
    static func dismantleNSView(_ view:MonitorView, coordinator:()) { view.stop() }
    final class MonitorView: NSView {
        var enabled = false
        var trailingInset: CGFloat = 0
        var onTopHover: (Bool) -> Void = { _ in }
        private var focusObserver: NSObjectProtocol?
        private var monitor: Any?
        private var tracking: NSTrackingArea?
        private weak var host: NSView?
        private weak var observedWindow: NSWindow?
        private var previousMouseMoved = false
        private var lastInside: Bool?
        deinit {
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        override func hitTest(_ point:NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); stop(); installIfNeeded() }
        func evaluateCurrentMouseLocation() {
            guard enabled, let window = observedWindow, let content = host else { return }
            let location = window.mouseLocationOutsideOfEventStream
            ReaderChromePointer.record(location, in: window)
            let point = content.convert(location, from: nil)
            let fromTop = content.isFlipped ? point.y : content.bounds.height - point.y
            let withinX = point.x >= 0 && point.x <= content.bounds.width - trailingInset
            updateInside(fromTop >= 0 && fromTop <= 56 && withinX)
        }
        func installIfNeeded() {
            guard enabled, let window, let content = window.contentView else { stop(); return }
            guard monitor == nil else { return }
            observedWindow = window; previousMouseMoved = window.acceptsMouseMovedEvents; window.acceptsMouseMovedEvents = true
            focusObserver = NotificationCenter.default.addObserver(forName:NSWindow.didBecomeKeyNotification,object:window,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lastInside = nil; self?.evaluateCurrentMouseLocation() }
            }
            host = content
            let tracking = NSTrackingArea(rect:.zero,options:[.activeAlways,.mouseEnteredAndExited,.inVisibleRect],owner:self,userInfo:nil)
            content.addTrackingArea(tracking); self.tracking = tracking
            monitor = NSEvent.addLocalMonitorForEvents(matching:[.mouseMoved,.mouseEntered,.mouseExited,.leftMouseDragged]) { [weak self] event in
                guard let self, self.enabled, let window = self.observedWindow, event.window === window, let content = self.host else { return event }
                ReaderChromePointer.record(event.locationInWindow, in: window)
                let point = content.convert(event.locationInWindow, from: nil)
                let fromTop = content.isFlipped ? point.y : content.bounds.height - point.y
                self.updateInside(fromTop >= 0 && fromTop <= 56 && point.x >= 0 && point.x <= content.bounds.width - self.trailingInset)
                return event
            }
        }
        override func mouseExited(with event: NSEvent) { updateInside(false) }
        private func updateInside(_ inside: Bool) {
            guard lastInside != inside else { return }; lastInside = inside; onTopHover(inside)
        }
        func stop() {
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }; focusObserver = nil
            if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
            if let tracking { host?.removeTrackingArea(tracking) }; tracking = nil
            ReaderChromePointer.clear(in: observedWindow)
            observedWindow?.acceptsMouseMovedEvents = previousMouseMoved; observedWindow = nil; lastInside = nil
        }
    }
}
