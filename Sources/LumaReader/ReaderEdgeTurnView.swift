import AppKit

/// Interactive edge-drag gesture view for page turning.
///
/// Open-source provenance & design references:
/// - **Readest** (`https://github.com/readest/readest`, Issue #5288):
///   Low-slop edge gesture claim (`24pt` edge corridor outside the text column) with
///   exponential moving average (EMA) release velocity tracking so short deliberate flicks
///   commit reliably and mid-drag reversals cancel cleanly.
/// - **StPageFlip** (`https://github.com/Nodlik/StPageFlip`, v2.0.7, MIT License):
///   Pointer-driven fold progress normalization (`[0, 0.98]`) and click-vs-drag disambiguation.
///
/// Narrow edge targets (`24pt`) leave text selection, links, and annotation hit-testing
/// in the live document completely untouched.
@MainActor
final class ReaderEdgeTurnView: NSView {
    var onBegin: ((Bool) -> Void)?
    var onChange: ((Double) -> Void)?
    var onEnd: ((Double, Double) -> Void)?

    private let edgeWidth: CGFloat = 24
    private var start: CGPoint?
    private var forward = true
    private var lastX: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var velocity: Double = 0

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden,
              bounds.contains(point),
              point.x < edgeWidth || point.x > bounds.width - edgeWidth else {
            return nil
        }
        return self
    }

    override func resetCursorRects() {
        addCursorRect(NSRect(x: 0, y: 0, width: edgeWidth, height: bounds.height), cursor: .openHand)
        addCursorRect(NSRect(x: max(0, bounds.width - edgeWidth), y: 0, width: edgeWidth, height: bounds.height), cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        start = point
        forward = point.x > bounds.width / 2
        lastX = point.x
        lastTime = event.timestamp
        velocity = 0
        onBegin?(forward)
    }

    private func progress(_ x: CGFloat) -> Double {
        guard let start else { return 0 }
        let distance = (x - start.x) * (forward ? -1 : 1)
        let span = max(220, bounds.width * 0.76)
        return min(0.98, max(0, Double(distance / span)))
    }

    override func mouseDragged(with event: NSEvent) {
        guard start != nil else { return }
        let x = convert(event.locationInWindow, from: nil).x
        let elapsed = max(0.001, event.timestamp - lastTime)
        let instantVelocity = Double((x - lastX) * (forward ? -1 : 1)) / elapsed
        // Smooth velocity with EMA (Readest #5288) so a single jitter sample does not flip sign.
        velocity = velocity == 0 ? instantVelocity : (velocity * 0.35 + instantVelocity * 0.65)
        lastX = x
        lastTime = event.timestamp
        onChange?(progress(x))
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint = start else { return }
        let x = convert(event.locationInWindow, from: nil).x
        // A stationary hold (> 120ms) must not retain an earlier flick velocity.
        if event.timestamp - lastTime > 0.12 {
            velocity = 0
        }
        let value = progress(x)
        let click = abs(x - startPoint.x) < 5
        onEnd?(click ? 1.0 : value, click ? 0 : velocity)
        start = nil
    }

    override func cancelOperation(_ sender: Any?) {
        onEnd?(0, -1000)
        start = nil
    }
}
