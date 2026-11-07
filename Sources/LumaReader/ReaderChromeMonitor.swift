import SwiftUI
import AppKit

/// Observe mouse movement without installing a hit-testable overlay on the book.
struct ReaderChromeMonitor: NSViewRepresentable {
    var enabled: Bool
    var trailingInset: CGFloat
    var onTopHover: (Bool) -> Void
    var onBottomHover: (Bool) -> Void
    func makeNSView(context:Context) -> MonitorView { MonitorView() }
    func updateNSView(_ view:MonitorView,context:Context) {
        view.enabled = enabled; view.trailingInset = trailingInset; view.onTopHover = onTopHover; view.onBottomHover = onBottomHover; view.installIfNeeded()
    }
    static func dismantleNSView(_ view:MonitorView,coordinator:()) { view.stop() }
    final class MonitorView: NSView {
        var enabled = false
        var trailingInset: CGFloat = 0
        var onTopHover: (Bool) -> Void = { _ in }
        var onBottomHover: (Bool) -> Void = { _ in }
        private var focusObserver: NSObjectProtocol?
        private var monitor: Any?
        private var tracking: NSTrackingArea?
        private weak var host: NSView?
        private weak var observedWindow: NSWindow?
        private var previousMouseMoved = false
        private var lastInside: Bool?
        private var lastBottomInside: Bool?
        override func hitTest(_ point:NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); stop(); installIfNeeded() }
        func installIfNeeded() {
            guard enabled, let window, let content = window.contentView else { stop(); return }
            guard monitor == nil else { return }
            observedWindow = window; previousMouseMoved = window.acceptsMouseMovedEvents; window.acceptsMouseMovedEvents = true
            focusObserver = NotificationCenter.default.addObserver(forName:NSWindow.didBecomeKeyNotification,object:window,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lastInside = nil; self?.lastBottomInside = nil }
            }
            host = content
            let tracking = NSTrackingArea(rect:.zero,options:[.activeAlways,.mouseEnteredAndExited,.inVisibleRect],owner:self,userInfo:nil)
            content.addTrackingArea(tracking); self.tracking = tracking
            monitor = NSEvent.addLocalMonitorForEvents(matching:[.mouseMoved,.leftMouseDragged]) { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self, let window = self.observedWindow, event.window === window, let content = window.contentView else { return }
                    let point = content.convert(event.locationInWindow,from:nil)
                    let fromTop = content.isFlipped ? point.y:content.bounds.height-point.y
                    self.updateInside(fromTop >= 0 && fromTop <= 56 && point.x >= 0 && point.x <= content.bounds.width-self.trailingInset)
                    let fromBottom = content.bounds.height - fromTop
                    self.updateBottomInside(fromBottom >= 0 && fromBottom <= 48 && point.x >= 0 && point.x <= content.bounds.width-self.trailingInset)
                }
                return event
            }
        }
        override func mouseExited(with event:NSEvent) { updateInside(false); updateBottomInside(false) }
        private func updateInside(_ inside:Bool) {
            guard lastInside != inside else { return }; lastInside = inside; onTopHover(inside)
        }
        private func updateBottomInside(_ inside:Bool) {
            guard lastBottomInside != inside else { return }; lastBottomInside = inside; onBottomHover(inside)
        }
        func stop() {
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }; focusObserver = nil
            if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
            if let tracking { host?.removeTrackingArea(tracking) }; tracking = nil; host = nil
            observedWindow?.acceptsMouseMovedEvents = previousMouseMoved; observedWindow = nil; lastInside = nil; lastBottomInside = nil
        }
    }
}
