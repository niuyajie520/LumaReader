import Foundation

/// Session-only navigation history; never serialized into bookmarks or cloud data.
enum ReadingJumpPosition: Equatable {
    case epub(chapter: Int, offset: Double, anchor: ReaderTextAnchor?)
    case pdf(page: Int, x: Double, y: Double, zoom: Double)
}
struct ReadingJumpHistory {
    private(set) var positions: [ReadingJumpPosition] = []
    var isEmpty: Bool { positions.isEmpty }
    mutating func remember(_ position: ReadingJumpPosition) {
        guard positions.last != position else { return }
        positions.append(position)
        if positions.count > 32 { positions.removeFirst(positions.count - 32) }
    }
    mutating func pop() -> ReadingJumpPosition? { positions.popLast() }
}

/// Read-only description of the displayed spread, independent of font-dependent page numbers.
struct ReaderBookmarkPage {
    var index = 0
    var count = 1
    var columns = 1
    var textStart: Int?
    var textEnd: Int?

    func contains(_ mark: ReadingBookmark, currentAnchor: ReaderTextAnchor?, offset: Double) -> Bool {
        if let anchor = mark.anchor {
            if let start = textStart, let end = textEnd, end > start {
                return anchor.start >= start && anchor.start < end
            }
            if let currentAnchor { return anchor.start == currentAnchor.start && anchor.quote == currentAnchor.quote }
        }
        // Compatibility for old bookmarks without a text anchor. Match the same spread
        // that Reader.js restore() would choose, instead of a fixed 1% tolerance.
        let last = ((max(1, count) - 1) / max(1, columns)) * max(1, columns)
        if last == 0 { return true }
        if let saved = mark.offset, saved.isFinite {
            let spread = Int((min(1, max(0, saved)) * Double(last) / Double(max(1, columns))).rounded()) * max(1, columns)
            return min(last, spread) == index
        }
        return abs((mark.offset ?? 0) - offset) < 0.01
    }
}
