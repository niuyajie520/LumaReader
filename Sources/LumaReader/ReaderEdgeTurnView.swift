import AppKit

/// Narrow edge targets leave selection, links and annotation hit testing in the live document.
@MainActor
final class ReaderEdgeTurnView: NSView {
    var onBegin: ((Bool) -> Void)?
    var onChange: ((Double) -> Void)?
    var onEnd: ((Double, Double) -> Void)?
    private var start: CGPoint?
    private var forward = true
    private var lastX: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var velocity: Double = 0
    override func hitTest(_ point:NSPoint) -> NSView? {
        guard !isHidden, bounds.contains(point), point.x < 20 || point.x > bounds.width - 20 else { return nil }
        return self
    }
    override func resetCursorRects() {
        addCursorRect(NSRect(x:0,y:0,width:20,height:bounds.height),cursor:.openHand)
        addCursorRect(NSRect(x:max(0,bounds.width-20),y:0,width:20,height:bounds.height),cursor:.openHand)
    }
    override func mouseDown(with event:NSEvent) {
        let point = convert(event.locationInWindow,from:nil)
        start = point; forward = point.x > bounds.width/2
        lastX = point.x; lastTime = event.timestamp; velocity = 0
        onBegin?(forward)
    }
    private func progress(_ x:CGFloat) -> Double {
        guard let start else { return 0 }
        let distance = (x - start.x) * (forward ? -1:1)
        return min(0.96,max(0,Double(distance / max(240,bounds.width * 0.8))))
    }
    override func mouseDragged(with event:NSEvent) {
        guard start != nil else { return }
        let x = convert(event.locationInWindow,from:nil).x
        let elapsed = max(0.001,event.timestamp - lastTime)
        velocity = Double((x-lastX) * (forward ? -1:1)) / elapsed
        lastX = x; lastTime = event.timestamp
        onChange?(progress(x))
    }
    override func mouseUp(with event:NSEvent) {
        guard start != nil else { return }
        let x = convert(event.locationInWindow,from:nil).x
        // A stationary hold must not retain an earlier flick velocity.
        if event.timestamp - lastTime > 0.12 { velocity = 0 }
        let value = progress(x)
        let click = abs(x - (start?.x ?? x)) < 5
        onEnd?(click ? 1:value,click ? 0:velocity)
        start = nil
    }
    override func cancelOperation(_ sender:Any?) { onEnd?(0,-1000); start = nil }
}
