import Foundation
import SwiftUI
import AppKit

/// 题干高亮与笔记区间（UTF-16 偏移）。解码时兼容旧版本可能使用的不同字段名，
/// 任何无法识别的旧数据都会安全地解码为空区间，绝不会导致草稿读取失败。
public struct StudyTextHighlight: Codable, Equatable, Hashable, Sendable {
    public var location: Int
    public var length: Int
    public var note: String?

    public init(location: Int, length: Int, note: String? = nil) {
        self.location = max(0, location)
        self.length = max(0, length)
        self.note = note
    }

    public init(range: NSRange, note: String? = nil) {
        self.init(location: range.location, length: range.length, note: note)
    }

    public var nsRange: NSRange { NSRange(location: location, length: length) }

    private struct AnyKey: CodingKey {
        var stringValue: String; var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
    }

    public init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: AnyKey.self) else {
            self.init(location: 0, length: 0, note: nil)
            return
        }
        func int(_ names: [String]) -> Int? {
            for n in names {
                if let k = AnyKey(stringValue: n), let v = try? c.decode(Int.self, forKey: k) {
                    return v
                }
            }
            return nil
        }
        let noteVal: String? = {
            if let k = AnyKey(stringValue: "note"), let v = try? c.decodeIfPresent(String.self, forKey: k) {
                return v
            }
            return nil
        }()
        let start = int(["location", "start", "lowerBound", "from", "offset"]) ?? 0
        if let len = int(["length", "count"]) {
            self.init(location: start, length: len, note: noteVal)
            return
        }
        let end = int(["end", "upperBound", "to"]) ?? start
        self.init(location: start, length: end - start, note: noteVal)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encode(location, forKey: AnyKey(stringValue: "location")!)
        try c.encode(length, forKey: AnyKey(stringValue: "length")!)
        if let note, !note.isEmpty {
            try c.encode(note, forKey: AnyKey(stringValue: "note")!)
        }
    }
}

// MARK: - 雅思机考风格题干选中浮窗 (Notes | Highlight) · 完美融合莫奈取色与液态玻璃特效

public struct StudyPromptView: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.lumaTextScale) private var textScale
    @AppStorage("luma.writing.promptFontSize.v1") private var promptFontSize = 15.5
    public let text: String
    @Binding public var highlights: [StudyTextHighlight]

    public init(text: String, highlights: Binding<[StudyTextHighlight]>) {
        self.text = text
        self._highlights = highlights
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 11.5))
                    Slider(value: $promptFontSize, in: 12...30, step: 1)
                        .frame(width: 120)
                        .controlSize(.mini)
                    Text("\(Int(promptFontSize)) pt")
                        .lumaFont(size: 11, weight: .medium, monospacedDigits: true)
                        .frame(width: 38, alignment: .trailing)
                    Button {
                        promptFontSize = 15.5
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("恢复默认字号")
                }
                .foregroundStyle(appearance.ink.opacity(0.7))
                .accessibilityLabel("调整题目字号，当前 \(Int(promptFontSize))")
            }
            LumaInteractivePromptRepresentable(
                text: text,
                highlights: $highlights,
                appearance: appearance,
                fontSize: CGFloat(min(30, max(12, promptFontSize))) * textScale
            )
        }
    }
}

/// Native popovers live outside the scroll view, so the question/chart cannot clip them.
@MainActor
final class LumaPromptInteractiveTextView: NSTextView, NSPopoverDelegate {
    var positionsActionsBelowSelection = false
    var onHighlightsChanged: (([StudyTextHighlight]) -> Void)?
    var currentHighlights: [StudyTextHighlight] = []
    var promptAppearance = StudyAppearance.current
    var promptFontSize: CGFloat = 15.5
    private var actionPopover: NSPopover?
    private var presentationTask: Task<Void, Never>?

    func render(text: String, highlights: [StudyTextHighlight], appearance: StudyAppearance, fontSize: CGFloat) {
        let contentChanged = string != text
        let changed = contentChanged || currentHighlights != highlights || promptFontSize != fontSize || promptAppearance != appearance
        guard changed else { return }
        if contentChanged || promptFontSize != fontSize { closeActions() }
        let selection = selectedRange()
        if contentChanged { string = text }
        currentHighlights = highlights
        promptAppearance = appearance
        promptFontSize = fontSize
        selectedTextAttributes = [
            .backgroundColor: NSColor(appearance.accent).withAlphaComponent(appearance.isDark ? 0.42 : 0.28),
            .foregroundColor: NSColor(appearance.ink)
        ]
        guard let storage = textStorage else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = max(4, fontSize * 0.3)
        storage.beginEditing()
        storage.setAttributes([
            .font: NSFont(name: "Georgia", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor(appearance.ink),
            .paragraphStyle: paragraph
        ], range: NSRange(location: 0, length: storage.length))
        for item in highlights {
            guard let range = validRange(item.nsRange) else { continue }
            storage.addAttribute(.backgroundColor, value: NSColor(appearance.accent).withAlphaComponent(appearance.isDark ? 0.42 : 0.26), range: range)
            if !(item.note ?? "").isEmpty {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        storage.endEditing()
        if !contentChanged, NSMaxRange(selection) <= (string as NSString).length { setSelectedRange(selection) }
        invalidateIntrinsicContentSize()
    }

    override func mouseDown(with event: NSEvent) {
        closeActions()
        // NSTextView completes its selection tracking before returning from mouseDown.
        super.mouseDown(with: event)
        scheduleActions(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        scheduleActions(at: convert(event.locationInWindow, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { closeActions(); return }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.charactersIgnoringModifiers?.lowercased() == "h",
           !modifiers.contains(.command), !modifiers.contains(.control), !modifiers.contains(.option),
           let range = validRange(selectedRange()) {
            addHighlight(range, note: nil)
            return
        }
        super.keyDown(with: event)
        scheduleActions(at: nil)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { closeActions() }
    }

    private func scheduleActions(at point: NSPoint?) {
        presentationTask?.cancel()
        presentationTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, self.window != nil else { return }
            if let range = self.validRange(self.selectedRange()) {
                self.showSelectionActions(range)
            } else if let point, let item = self.highlight(at: point) {
                self.showDeleteAction(item)
            } else { self.closeActions() }
        }
    }

    private func validRange(_ range: NSRange) -> NSRange? {
        let count = (string as NSString).length
        guard range.location != NSNotFound, range.location >= 0, range.location < count,
              range.length > 0, range.length <= count - range.location else { return nil }
        return range
    }

    private func highlight(at point: NSPoint) -> StudyTextHighlight? {
        guard let layout = layoutManager, let container = textContainer, layout.numberOfGlyphs > 0 else { return nil }
        let local = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layout.glyphIndex(for: local, in: container)
        guard glyph < layout.numberOfGlyphs else { return nil }
        let rect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard rect.insetBy(dx: -1, dy: -1).contains(local) else { return nil }
        let character = layout.characterIndexForGlyph(at: glyph)
        return currentHighlights.first { validRange($0.nsRange) != nil && NSLocationInRange(character, $0.nsRange) }
    }

    private func anchor(for range: NSRange) -> NSRect? {
        guard let range = validRange(range), let layout = layoutManager, let container = textContainer else { return nil }
        let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var result = NSRect.zero
        layout.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { rect, _ in
            result = rect
        }
        if result.isEmpty { result = layout.boundingRect(forGlyphRange: glyphs, in: container) }
        result.origin.x += textContainerOrigin.x
        result.origin.y += textContainerOrigin.y
        let visible = result.intersection(visibleRect)
        return visible.isEmpty ? nil : visible
    }

    private func showSelectionActions(_ range: NSRange) {
        let appearance = promptAppearance
        show(PromptSelectionActions(appearance: appearance, notes: { [weak self] in
            self?.showNoteEditor(range)
        }, highlight: { [weak self] in
            self?.addHighlight(range, note: nil)
        }), for: range)
    }

    private func showDeleteAction(_ item: StudyTextHighlight) {
        show(PromptDeleteAction(appearance: promptAppearance) { [weak self] in
            guard let self else { return }
            let updated = self.currentHighlights.filter { $0 != item }
            self.onHighlightsChanged?(updated)
            self.closeActions()
        }, for: item.nsRange)
    }

    private func showNoteEditor(_ range: NSRange) {
        let note = currentHighlights.first { NSIntersectionRange($0.nsRange, range).length > 0 }?.note ?? ""
        show(PromptNoteEditor(appearance: promptAppearance, initialText: note, save: { [weak self] text in
            self?.addHighlight(range, note: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }, cancel: { [weak self] in self?.closeActions() }), for: range)
        actionPopover?.contentViewController?.view.window?.makeKey()
    }

    private func show<Content: View>(_ content: Content, for range: NSRange) {
        guard let rect = anchor(for: range) else { closeActions(); return }
        closeActions()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: content)
        popover.appearance = NSAppearance(named: promptAppearance.isDark ? .darkAqua : .aqua)
        actionPopover = popover
        if positionsActionsBelowSelection, let host = window?.contentView {
            // Convert to the host coordinate system before choosing its physical bottom edge.
            var anchor = convert(rect, to: host)
            anchor.origin.y += host.isFlipped ? 5 : -5
            popover.show(relativeTo: anchor, of: host, preferredEdge: host.isFlipped ? .maxY : .minY)
        } else {
            popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        }
    }

    private func addHighlight(_ range: NSRange, note: String?) {
        guard let range = validRange(range) else { return }
        var merged = range
        var remaining = currentHighlights
        var retainedNotes: [String] = []
        // Repeat to include transitive overlaps, retaining notes from every merged segment.
        var changed = true
        while changed {
            changed = false
            remaining.removeAll { item in
                guard let valid = validRange(item.nsRange), NSIntersectionRange(valid, merged).length > 0 else { return false }
                merged = NSUnionRange(merged, valid)
                if let text = item.note, !text.isEmpty, !retainedNotes.contains(text) { retainedNotes.append(text) }
                changed = true
                return true
            }
        }
        if let note { retainedNotes = note.isEmpty ? [] : [note] }
        remaining.append(StudyTextHighlight(range: merged, note: retainedNotes.isEmpty ? nil : retainedNotes.joined(separator: "\n")))
        remaining.sort { $0.location < $1.location }
        onHighlightsChanged?(remaining)
        setSelectedRange(NSRange(location: NSMaxRange(range), length: 0))
        closeActions()
    }

    func closeActions() {
        presentationTask?.cancel()
        presentationTask = nil
        let old = actionPopover
        actionPopover = nil
        old?.delegate = nil
        old?.close()
    }

    func popoverDidClose(_ notification: Notification) { actionPopover = nil }
}

private struct PromptSelectionActions: View {
    let appearance: StudyAppearance
    let notes: () -> Void
    let highlight: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            action("Notes", icon: "text.bubble", perform: notes)
            Divider().frame(height: 36)
            action("Highlight", icon: "highlighter", perform: highlight)
        }
        .padding(6)
        .background(appearance.paper)
    }
    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).lumaFont(size: 12)
            }.frame(width: 84, height: 56).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(appearance.ink)
    }
}

private struct PromptDeleteAction: View {
    let appearance: StudyAppearance
    let remove: () -> Void
    var body: some View {
        Button(action: remove) {
            VStack(spacing: 5) {
                Image(systemName: "trash").font(.system(size: 18))
                Text("Delete Highlight").lumaFont(size: 12)
            }.frame(width: 150, height: 56).contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(6)
        .foregroundStyle(appearance.ink).background(appearance.paper)
        .accessibilityLabel("删除这处标记及其笔记")
    }
}

private struct PromptNoteEditor: View {
    let appearance: StudyAppearance
    @State private var text: String
    let save: (String) -> Void
    let cancel: () -> Void
    @FocusState private var focused: Bool
    init(appearance: StudyAppearance, initialText: String, save: @escaping (String) -> Void, cancel: @escaping () -> Void) {
        self.appearance = appearance; _text = State(initialValue: initialText)
        self.save = save; self.cancel = cancel
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes").font(.headline)
            TextField("输入审题笔记…", text: $text, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.plain).focused($focused)
                .padding(8).background(appearance.surface, in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("取消", action: cancel)
                Spacer()
                Button("保存") { save(text) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(14).frame(width: 280)
        .foregroundStyle(appearance.ink).background(appearance.paper)
        .onAppear { focused = true }
    }
}

struct LumaInteractivePromptRepresentable: NSViewRepresentable {
    let text: String
    @Binding var highlights: [StudyTextHighlight]
    let appearance: StudyAppearance
    let fontSize: CGFloat

    func makeNSView(context: Context) -> LumaPromptInteractiveTextView {
        let view = LumaPromptInteractiveTextView(usingTextLayoutManager: false)
        view.isEditable = false; view.isSelectable = true; view.isRichText = false
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 0, height: 4)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = false; view.isHorizontallyResizable = false
        return view
    }

    func updateNSView(_ view: LumaPromptInteractiveTextView, context: Context) {
        view.onHighlightsChanged = { highlights = $0 }
        view.render(text: text, highlights: highlights, appearance: appearance, fontSize: fontSize)
    }

    static func dismantleNSView(_ view: LumaPromptInteractiveTextView, coordinator: ()) { view.closeActions() }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LumaPromptInteractiveTextView, context: Context) -> CGSize? {
        let width = max(160, proposal.width ?? 480)
        guard let container = nsView.textContainer, let layout = nsView.layoutManager else { return nil }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        return CGSize(width: width, height: max(28, ceil(layout.usedRect(for: container).height + nsView.textContainerInset.height * 2 + 8)))
    }
}


public struct StudyMapDiagram: View {
    @Environment(\.studyAppearance) private var appearance
    public let title: String
    public let features: [MapStageFeature]

    public init(title: String, features: [MapStageFeature]) {
        self.title = title
        self.features = features
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .lumaFont(size: 13, weight: .semibold)
                .foregroundStyle(appearance.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(features, id: \.label) { feature in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.region)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(appearance.accent)
                        Text(feature.label)
                            .font(.caption)
                            .foregroundStyle(appearance.ink)
                        Text(feature.status)
                            .font(.caption2)
                            .foregroundStyle(appearance.ink.opacity(0.65))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(appearance.surface))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).stroke(appearance.line, lineWidth: 1))
    }
}
