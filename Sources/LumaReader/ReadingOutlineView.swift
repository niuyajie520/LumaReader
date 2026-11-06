import SwiftUI

struct ReadingOutlineView: View {
    @Environment(\.lumaSurface) private var surface
    @Environment(\.lumaMuted) private var muted
    let items: [ReadingOutlineItem]
    let bookID: UUID
    let currentChapter: Int
    var currentHeadingIndex = -1
    var currentHeadingID = ""
    let disabled: Bool
    let onSelect: (ReadingOutlineItem) -> Void
    @State private var collapsed: Set<String> = []
    @State private var revealed: Set<String> = []
    @State private var query = ""
    private var allIDs: Set<String> { Set(items.flatMap { $0.descendantIDs }) }
    private var key: String { "outlineCollapsed-"+bookID.uuidString }
    private var activeID: String? { ReadingOutlineNavigation.currentID(items,chapter:currentChapter,headingIndex:currentHeadingIndex,headingID:currentHeadingID) }
    private var visibleItems: [ReadingOutlineItem] { ReadingOutlineNavigation.filter(items,query:query) }
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing:0) {
                HStack(spacing:8) {
                    Image(systemName:"magnifyingglass").foregroundStyle(muted)
                    TextField(L10n.text("搜索目录标题"),text:$query).textFieldStyle(.plain).accessibilityLabel(L10n.text("搜索目录标题"))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName:"xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel(L10n.text("清空目录搜索"))
                    }
                }.padding(10).background(surface.opacity(0.7),in:RoundedRectangle(cornerRadius:8)).padding(.horizontal,12).padding(.top,10)
                HStack {
                    Button(L10n.text("当前位置")) { revealCurrent(proxy) }.disabled(activeID == nil)
                    Spacer()
                    Button(L10n.text("展开")) { revealed = []; collapsed = [] }.help(L10n.text("全部展开"))
                    Button(L10n.text("折叠")) { revealed = []; collapsed = allIDs }.help(L10n.text("全部折叠"))
                }.font(.caption).buttonStyle(.borderless).padding(.horizontal,14).padding(.vertical,10)
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:2) {
                        if visibleItems.isEmpty { Text(L10n.text("没有匹配的目录标题")).font(.caption).foregroundStyle(muted).padding(20) }
                        ForEach(visibleItems) { item in
                            ReadingOutlineBranch(item:item,collapsed:$collapsed,revealed:$revealed,activeID:activeID,forceExpanded:!query.isEmpty,disabled:disabled,onSelect:onSelect)
                        }
                    }.padding(8)
                }
            }
            .onAppear {
                collapsed = Set(UserDefaults.standard.stringArray(forKey:key) ?? []).intersection(allIDs)
                revealCurrent(proxy)
            }
            .onChange(of:collapsed) { _,value in UserDefaults.standard.set(value.sorted(),forKey:key) }
        }
    }
    private func revealCurrent(_ proxy: ScrollViewProxy) {
        guard let id = activeID else { return }
        query = ""; revealed = ReadingOutlineNavigation.ancestors(of:id,in:items)
        // Only this temporary reveal changes; other saved folds remain untouched.
        DispatchQueue.main.async { proxy.scrollTo(id,anchor:.center) }
    }
}
private struct ReadingOutlineBranch: View {
    let item: ReadingOutlineItem
    @Binding var collapsed: Set<String>
    @Binding var revealed: Set<String>
    let activeID: String?
    let forceExpanded: Bool
    let disabled: Bool
    let onSelect: (ReadingOutlineItem) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaMotionLevel) private var motionLevel
    private var expanded: Bool { forceExpanded || revealed.contains(item.id) || !collapsed.contains(item.id) }
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:2) {
                if !item.children.isEmpty {
                    Button {
                        if expanded { revealed.remove(item.id); collapsed.insert(item.id) }
                        else { collapsed.remove(item.id) }
                    } label: {
                        Image(systemName:"chevron.right").font(.system(size:10,weight:.semibold))
                            .rotationEffect(.degrees(expanded ? 90:0)).frame(width:30,height:40)
                    }.buttonStyle(.plain).disabled(forceExpanded)
                        .accessibilityLabel(L10n.text((expanded ? "折叠":"展开")+item.title))
                        .accessibilityValue(L10n.text(expanded ? "已展开":"已折叠"))
                } else { Color.clear.frame(width:30,height:1).accessibilityHidden(true) }
                Button { onSelect(item) } label: {
                    HStack(spacing:6) {
                        Text(item.title).font(.system(size:13,weight:item.children.isEmpty ? .regular:.medium))
                            .multilineTextAlignment(.leading).frame(maxWidth:.infinity,minHeight:40,alignment:.leading)
                        if item.id == activeID { Circle().fill(Color.accentColor).frame(width:5,height:5).accessibilityLabel(L10n.text("当前位置")) }
                    }.padding(.trailing,8).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(disabled || item.chapterIndex == nil)
            }
            .background(item.id == activeID ? Color.accentColor.opacity(0.1):.clear,in:RoundedRectangle(cornerRadius:8))
            .id(item.id)
            if !item.children.isEmpty && expanded {
                ForEach(item.children) { child in
                    ReadingOutlineBranch(item:child,collapsed:$collapsed,revealed:$revealed,activeID:activeID,forceExpanded:forceExpanded,disabled:disabled,onSelect:onSelect)
                }.padding(.leading,16)
            }
        }
        .animation(LumaMotion.adjusted(.easeOut(duration:0.16),level:motionLevel,reduceMotion:reduceMotion),value:expanded)
    }
}
