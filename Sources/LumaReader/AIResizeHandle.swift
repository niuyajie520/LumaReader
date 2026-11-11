import SwiftUI
import AppKit

/// Native mouse tracking stays in window coordinates while the divider itself moves.
struct AIResizeHandle: NSViewRepresentable {
    var width: Double
    var onStart: () -> Void
    var onResize: (Double) -> Void
    var onEnd: () -> Void
    func makeNSView(context: Context) -> Handle { Handle() }
    func updateNSView(_ view: Handle, context: Context) {
        view.width = width; view.onStart = onStart; view.onResize = onResize; view.onEnd = onEnd
    }
    final class Handle: NSView {
        var width = 340.0
        var onStart: (() -> Void)?
        var onResize: ((Double) -> Void)?
        var onEnd: (() -> Void)?
        private var origin: (x: CGFloat, width: Double)?
        override func resetCursorRects() { addCursorRect(bounds,cursor:.resizeLeftRight) }
        override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) { origin = (event.locationInWindow.x,width); onStart?() }
        override func mouseDragged(with event: NSEvent) {
            guard let origin else { return }
            onResize?(origin.width + Double(origin.x - event.locationInWindow.x))
        }
        override func mouseUp(with event: NSEvent) { origin = nil; onEnd?() }
    }
}
