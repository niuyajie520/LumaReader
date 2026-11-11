import WebKit

/// Trackpad phases identify a gesture; momentum must never start another page turn.
final class PagedWebView: WKWebView {
    var onWheelTurn: ((Int)->Void)?
    private var gate = PageWheelGate()
    override func scrollWheel(with event:NSEvent) {
        guard !event.modifierFlags.contains(.control), let onWheelTurn else { super.scrollWheel(with:event); return }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX:event.scrollingDeltaY
        let phased = !event.phase.isEmpty || !event.momentumPhase.isEmpty
        if let direction = gate.consume(delta:Double(delta),began:event.phase.contains(.began),
            momentum:!event.momentumPhase.isEmpty,phased:phased,time:event.timestamp) { onWheelTurn(direction) }
        // Consume the event: forwarding it would also trigger the chapter's wheel handler.
    }
}

struct PageWheelGate {
    private var amount:Double = 0
    private var turned = false
    private var lastEvent:TimeInterval?
    mutating func consume(delta:Double,began:Bool,momentum:Bool,phased:Bool,time:TimeInterval)->Int? {
        guard delta.isFinite else { return nil }
        let quiet = lastEvent.map { time-$0 > 0.35 } ?? true
        lastEvent = time
        if momentum { return nil }
        if began || (!phased && quiet) { amount = 0; turned = false }
        guard !turned else { return nil }
        amount += delta
        guard abs(amount) >= 100 else { return nil }
        turned = true
        return amount < 0 ? -1:1
    }
}
