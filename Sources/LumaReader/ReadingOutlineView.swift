import SwiftUI
import AppKit

struct ReadingOutlineView: View {
    @Environment(\.lumaSurface) private var surface
    @Environment(\.lumaMuted) private var muted
    @Environment(\.lumaInk) private var ink
    @Environment(\.lumaAccent) private var envAccent
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    let items: [ReadingOutlineItem]
    let bookID: UUID
    let currentChapter: Int
    var currentHeadingIndex = -1
    var currentHeadingID = ""
    let disabled: Bool
    var themeAccent: Color? = nil
    var themeSelectedFill: Color? = nil
    let onSelect: (ReadingOutlineItem) -> Void
    @State private var collapsed: Set<String> = []
    @State private var revealed: Set<String> = []
    @State private var query = ""
    private var allIDs: Set<String> { ReadingOutlineNavigation.allIDs(items) }
    private var key: String { "outlineCollapsed-"+bookID.uuidString }
    private var activeID: String? { ReadingOutlineNavigation.currentID(items,chapter:currentChapter,headingIndex:currentHeadingIndex,headingID:currentHeadingID) }
    private var rows: [ReadingOutlineRow] {
        ReadingOutlineNavigation.rows(for:items,query:query,collapsed:collapsed,revealed:revealed)
    }
    private var isSearching: Bool {
        !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
    }

    private var resolvedAccent: Color {
        themeAccent ?? envAccent
    }
    private var resolvedSelectedFill: Color {
        themeSelectedFill ?? resolvedAccent.opacity(colorScheme == .dark ? 0.18 : 0.14)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing:0) {
                HStack(spacing:8) {
                    Image(systemName:"magnifyingglass").foregroundStyle(muted)
                    TextField(L10n.text("搜索目录标题"),text:$query).textFieldStyle(.plain).accessibilityLabel(L10n.text("搜索目录标题"))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName:"xmark.circle.fill").foregroundStyle(muted) }
                            .buttonStyle(.plain).accessibilityLabel(L10n.text("清空目录搜索"))
                    }
                }.padding(10).background(surface.opacity(0.7),in:RoundedRectangle(cornerRadius:8)).padding(.horizontal,12).padding(.top,10)
                HStack(spacing: 6) {
                    OutlineChipButton(title:L10n.text("当前位置"),
                                      enabled:activeID != nil,
                                      tint:activeID == nil ? muted.opacity(0.45) : resolvedAccent) {
                        revealCurrent(proxy)
                    }
                    .help(L10n.text("滚动到正在阅读的章节"))
                    Spacer(minLength: 6)
                    OutlineChipButton(title:L10n.text("全部展开"), enabled:true, tint:muted) {
                        expandAll()
                    }
                    .help(L10n.text("展开全部目录层级"))
                    OutlineChipButton(title:L10n.text("全部折叠"), enabled:true, tint:muted) {
                        collapseAll()
                    }
                    .help(L10n.text("折叠全部目录层级"))
                }.padding(.horizontal,10).padding(.vertical,8)
                Divider().opacity(0.18).padding(.horizontal,12)
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:2) {
                        if rows.isEmpty {
                            Text(L10n.text("没有匹配的目录标题")).font(.caption).foregroundStyle(muted).padding(20)
                        }
                        ForEach(rows) { row in
                            ReadingOutlineBranch(
                                row:row,
                                activeID:activeID,
                                disabled:disabled,
                                accentColor:resolvedAccent,
                                selectedFill:resolvedSelectedFill,
                                canToggle:!isSearching,
                                animatesChevron:!reduceMotion && motionLevel != .off,
                                onToggle:{ toggle(row.item) },
                                onSelect:{ onSelect(row.item) }
                            )
                            .id(row.id)
                        }
                    }.padding(8)
                }
            }
            .tint(resolvedAccent)
            .background { OutlineFocusShield().frame(width:1,height:1).allowsHitTesting(false) }
            .onAppear {
                collapsed = Set(UserDefaults.standard.stringArray(forKey:key) ?? []).intersection(allIDs)
                revealCurrent(proxy)
            }
            .onChange(of:collapsed) { _,value in UserDefaults.standard.set(value.sorted(),forKey:key) }
        }
    }

    /// Expand/collapse only changes which rows exist; the panel keeps its frame,
    /// scroll position and chrome, so nothing flashes or jumps.
    private func toggle(_ item: ReadingOutlineItem) {
        let isExpanded = revealed.contains(item.id) || !collapsed.contains(item.id)
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            if isExpanded {
                revealed.remove(item.id)
                collapsed.insert(item.id)
            } else {
                collapsed.remove(item.id)
            }
        }
    }
    private func expandAll() {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { revealed = []; collapsed = [] }
    }
    private func collapseAll() {
        let ids = allIDs
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { revealed = []; collapsed = ids }
    }
    private func revealCurrent(_ proxy: ScrollViewProxy) {
        guard let id = activeID else { return }
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) {
            query = ""; revealed = ReadingOutlineNavigation.ancestors(of:id,in:items)
        }
        // Only this temporary reveal changes; other saved folds remain untouched.
        DispatchQueue.main.async { proxy.scrollTo(id,anchor:.center) }
    }
}

/// Small capsule target for 当前位置 / 全部展开 / 全部折叠. The old caption text
/// had only a hairline hit area, which made these actions feel unresponsive.
private struct OutlineChipButton: View {
    let title: String
    let enabled: Bool
    let tint: Color
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size:11.5,weight:.medium))
                .foregroundStyle(tint)
                .lineLimit(1)
                .padding(.horizontal,9)
                .frame(minHeight:26)
                .background(
                    RoundedRectangle(cornerRadius:6,style:.continuous)
                        .fill(hovered && enabled ? tint.opacity(0.12) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius:6,style:.continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { inside in hovered = enabled && inside }
        .accessibilityLabel(title)
    }
}

private struct ReadingOutlineBranch: View {
    let row: ReadingOutlineRow
    let activeID: String?
    let disabled: Bool
    let accentColor: Color
    let selectedFill: Color
    let canToggle: Bool
    let animatesChevron: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    @Environment(\.lumaInk) private var ink
    @Environment(\.lumaMuted) private var muted
    @State private var isHovered = false
    @State private var chevronHovered = false
    @FocusState private var isFocused: Bool
    private var item: ReadingOutlineItem { row.item }
    private var isActive: Bool { item.id == activeID }

    var body: some View {
        HStack(spacing:2) {
            if row.hasChildren {
                Button(action:onToggle) {
                    Image(systemName:"chevron.right").font(.system(size:10,weight:.semibold))
                        .foregroundStyle(isActive ? accentColor : (chevronHovered ? ink : muted))
                        .rotationEffect(.degrees(row.expanded ? 90:0))
                        .animation(animatesChevron ? .easeOut(duration:0.12) : nil,value:row.expanded)
                        .frame(width:30,height:44)
                        .background(
                            Circle()
                                .fill(chevronHovered ? accentColor.opacity(0.10) : Color.clear)
                                .frame(width:24,height:24)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canToggle)
                .onHover { inside in chevronHovered = inside }
                .accessibilityLabel(L10n.text((row.expanded ? "折叠":"展开")+item.title))
                .accessibilityValue(L10n.text(row.expanded ? "已展开":"已折叠"))
            } else {
                Color.clear.frame(width:30,height:1).accessibilityHidden(true)
            }
            Button { onSelect() } label: {
                HStack(spacing:8) {
                    Text(item.title)
                        .font(.system(size:14,weight:(isActive || row.hasChildren) ? .semibold : .regular))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                        .frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
                    if isActive {
                        Circle()
                            .fill(accentColor)
                            .frame(width:6,height:6)
                            .accessibilityLabel(L10n.text("当前位置"))
                    }
                }.padding(.trailing,10).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .disabled(disabled || item.chapterIndex == nil)
        }
        .padding(.leading, CGFloat(row.depth) * 16)
        .background(
            RoundedRectangle(cornerRadius:8, style:.continuous)
                .fill(isActive ? selectedFill : (isHovered ? accentColor.opacity(0.08) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius:8, style:.continuous)
                .strokeBorder(isFocused ? accentColor.opacity(0.55) : (isActive ? accentColor.opacity(0.24) : Color.clear), lineWidth: isFocused ? 1.1 : 0.7)
        )
        .onHover { isHovered = $0 }
    }
}

/// A popover hands first-responder status to its first text field, which used
/// to put the caret in the search box every time the directory opened. Clear
/// that initial focus once (twice, in case SwiftUI re-applies it) so the list
/// stays the active surface until the reader clicks the field.
private struct OutlineFocusShield: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ShieldView() }
    func updateNSView(_ view: NSView, context: Context) {}

    private final class ShieldView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async {
                Self.clearSearchFocus(in: window)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    Self.clearSearchFocus(in: window)
                }
            }
        }
        private static func clearSearchFocus(in window: NSWindow) {
            guard window.firstResponder is NSTextView || window.firstResponder is NSTextField else { return }
            window.makeFirstResponder(nil)
        }
    }
}
