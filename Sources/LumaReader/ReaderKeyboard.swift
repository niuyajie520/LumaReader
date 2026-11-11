import SwiftUI
import AppKit
import WebKit

/// Adds plain arrow navigation when native reader chrome has focus.
/// WebKit keeps its own key handling, so editing and text selection remain intact.
struct ReaderKeyboardBridge: NSViewRepresentable {
    let controller: ReaderController
    let enabled: Bool
    func makeNSView(context: Context) -> MonitorView { MonitorView() }
    func updateNSView(_ view: MonitorView, context: Context) { view.controller = controller; view.enabled = enabled }
    static func dismantleNSView(_ view: MonitorView, coordinator: ()) { view.stop() }
    final class MonitorView: NSView {
        weak var controller: ReaderController?
        var enabled = false
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow(); stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
                let consumed = MainActor.assumeIsolated { () -> Bool in
                    guard let self, self.enabled, let window = self.window,
                          event.window === window, window.isKeyWindow, window.attachedSheet == nil,
                          event.modifierFlags.intersection([.command,.control,.option,.shift]).isEmpty,
                          event.keyCode == 123 || event.keyCode == 124 else { return false }
                    var candidate = window.firstResponder as? NSView
                    while let view = candidate {
                        if view is NSTextView || view is NSTextField || view is NSComboBox || view is WKWebView { return false }
                        candidate = view.superview
                    }
                    self.controller?.move(event.keyCode == 123 ? -1:1)
                    return true
                }
                return consumed ? nil:event
            }
        }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }
}
