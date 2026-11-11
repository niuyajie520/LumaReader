// === PROJECT RED LINE / 项目红线 BEGIN ===
// 听写输入框的字体、自适应字号、长词适配与布局必须保持，不得借重构改变。
// Preserve dictation typography, adaptive sizing, long-word fitting, and layout during all refactoring.
// 完整规则见项目根目录 AGENTS.md；所有开发者与 AI 必须遵守。
// All developers and AI assistants must follow the project-root AGENTS.md.
// === PROJECT RED LINE / 项目红线 END ===
import SwiftUI
import AppKit

/// Presentation only. No answer normalization, session state or timer ownership.
@MainActor
enum DictationAnswerMetrics {
    static let minimumSize: CGFloat = 36
    static let maximumSize: CGFloat = 140
    static let growthThreshold: CGFloat = 3

    private static var fontCache: [CGFloat: NSFont] = [:]
    private static let widthCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 512
        return cache
    }()

    static func font(_ size: CGFloat) -> NSFont {
        let key = (size * 2).rounded() / 2
        if let cached = fontCache[key] { return cached }
        let base = NSFont.systemFont(ofSize: key, weight: .bold)
        let resolved: NSFont
        if let descriptor = base.fontDescriptor.withDesign(.rounded),
           let rounded = NSFont(descriptor: descriptor, size: key) {
            resolved = rounded
        } else {
            resolved = base
        }
        if fontCache.count > 64 { fontCache.removeAll(keepingCapacity: true) }
        fontCache[key] = resolved
        return resolved
    }

    static func width(_ text: String, size: CGFloat) -> CGFloat {
        let key = "\(size)|\(text)" as NSString
        if let cached = widthCache.object(forKey: key) { return CGFloat(truncating: cached) }
        let measured = text.components(separatedBy: .newlines).map {
            ceil(($0 as NSString).size(withAttributes: [.font: font(size)]).width)
        }.max() ?? 0
        widthCache.setObject(NSNumber(value: Double(measured)), forKey: key)
        return measured
    }

    static func fittedSize(text: String, availableWidth: CGFloat, ceiling: CGFloat = maximumSize) -> CGFloat {
        let upper = max(minimumSize, ceiling)
        // Leave room for the caret, native field insets and measurement differences.
        let safeWidth = max(1, availableWidth - 24)
        if width(text, size: upper) <= safeWidth { return upper }
        if width(text, size: minimumSize) > safeWidth { return minimumSize }
        var low = minimumSize
        var high = upper
        for _ in 0..<12 {
            let middle = (low + high) / 2
            if width(text, size: middle) <= safeWidth { low = middle } else { high = middle }
        }
        return floor(low * 2) / 2
    }

    static func settledSize(current: CGFloat, target: CGFloat) -> CGFloat {
        // Shrink immediately for safety; require 3pt of headroom before growing.
        target < current || target - current >= growthThreshold ? target : current
    }

    static func shouldWrap(headroom: CGFloat, wasWrapped: Bool) -> Bool {
        // Enter with 24pt spare, leave only after 48pt spare: a 24pt dead band.
        headroom < (wasWrapped ? 48 : 24)
    }
}

/// Explicitly animatable font size. The surrounding card does not animate its position.
struct DictationAnswerFont: AnimatableModifier {
    nonisolated var size: CGFloat
    nonisolated var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold, design: .rounded))
    }
}

/// Three siblings: quiet context, answer, actions. Equal clearance above/below the
/// answer keeps its center fixed when context or hints change. Short windows scroll
/// the entire canvas instead of compressing or overlaying the text field.
struct DictationPracticeLayout: Layout {
    var minimumHeight: CGFloat
    private let gap: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(1, proposal.width ?? 640)
        guard subviews.count == 4 else { return CGSize(width: width, height: minimumHeight) }
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        let topHeight = sizes[0].height + gap + sizes[1].height
        let bottomHeight = sizes[3].height
        let required = sizes[2].height + 2 * (max(topHeight, bottomHeight) + gap)
        return CGSize(width: width, height: max(minimumHeight, required))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 4 else { return }
        let child = ProposedViewSize(width: bounds.width, height: nil)
        subviews[0].place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top, proposal: child)
        subviews[1].place(at: CGPoint(x: bounds.midX, y: bounds.minY + subviews[0].sizeThatFits(child).height + gap),
                          anchor: .top, proposal: child)
        subviews[2].place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: child)
        subviews[3].place(at: CGPoint(x: bounds.midX, y: bounds.maxY), anchor: .bottom, proposal: child)
    }
}

/// The same four groups stay in the same view tree and reading order during resize.
struct GridLayoutForDictationActions: Layout {
    private let gap: CGFloat = 10

    private func metrics(width: CGFloat, subviews: Subviews) -> (sizes: [CGSize], columns: Int, widths: [CGFloat], rowHeights: [CGFloat]) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let first = sizes.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element.width }.max() ?? 0
        let second = sizes.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element.width }.max() ?? 0
        let columns = first + second + gap <= width ? 2 : 1
        let widths = columns == 2 ? [first, second] : [sizes.map(\.width).max() ?? 0]
        var rows: [CGFloat] = []
        for index in sizes.indices {
            let row = index / columns
            if row == rows.count { rows.append(sizes[index].height) }
            else { rows[row] = max(rows[row], sizes[index].height) }
        }
        return (sizes, columns, widths, rows)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 640
        let m = metrics(width: width, subviews: subviews)
        return CGSize(width: width, height: m.rowHeights.reduce(0, +) + CGFloat(max(0, m.rowHeights.count - 1)) * gap)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let m = metrics(width: bounds.width, subviews: subviews)
        let totalWidth = m.widths.reduce(0, +) + CGFloat(m.columns - 1) * gap
        let start = bounds.midX - totalWidth / 2
        for index in subviews.indices {
            let row = index / m.columns
            let column = index % m.columns
            let x = start + m.widths.prefix(column).reduce(0, +) + CGFloat(column) * gap + m.widths[column] / 2
            let y = bounds.minY + m.rowHeights.prefix(row).reduce(0, +) + CGFloat(row) * gap + m.rowHeights[row] / 2
            subviews[index].place(at: CGPoint(x: x, y: y), anchor: .center, proposal: ProposedViewSize(m.sizes[index]))
        }
    }
}
