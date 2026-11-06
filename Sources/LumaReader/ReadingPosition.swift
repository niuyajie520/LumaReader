import Foundation

/// UTF-16 offsets match WebKit text ranges and the existing annotation format.
struct ReaderTextAnchor: Codable, Equatable, Sendable {
    var version = 1
    var start: Int
    var quote: String
    var prefix: String
    init?(message: Any?) {
        guard let value = message as? [String:Any], value["version"] as? Int == 1,
              let start = value["start"] as? Int, start >= 0,
              let quote = value["quote"] as? String, !quote.isEmpty, quote.utf16.count <= 128,
              let prefix = value["prefix"] as? String, prefix.utf16.count <= 64 else { return nil }
        self.start = start; self.quote = quote; self.prefix = prefix
    }
    init(start: Int, quote: String, prefix: String = "") { self.start = start; self.quote = quote; self.prefix = prefix }
    var json: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data:data,encoding:.utf8)
    }
}

enum ReadingProgress {
    static func epub(chapter: Int, chapterCount: Int, offset: Double, canForward: Bool) -> Double {
        guard chapterCount > 0 else { return 0 }
        let local = offset.isFinite ? min(1,max(0,offset)):0
        if chapter == chapterCount-1 && !canForward { return 1 }
        return min(0.999999,max(0,(Double(chapter)+local)/Double(chapterCount)))
    }
}
