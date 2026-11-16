import SwiftUI

/// 命令面板能做的事。
enum LumaPaletteAction: Equatable {
    case home, library, statistics, cloud, settings, importBooks
    case study(String)
    case book(UUID)
}

/// ⌘K 命令面板：搜书名、作者和功能；方向键选择，回车执行，Esc 关闭。全程不用鼠标。
struct LumaCommandPalette: View {
    @Bindable var store: LibraryStore
    let onRun: (LumaPaletteAction) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Item: Identifiable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let action: LumaPaletteAction
    }

    private var commands: [Item] {
        [
            Item(id: "home", title: "主页", detail: "⌘1", symbol: "house", action: .home),
            Item(id: "library", title: "书架", detail: "⌘2", symbol: "books.vertical", action: .library),
            Item(id: "listening", title: "听力", detail: "⌘3", symbol: "headphones", action: .study("学习_听力")),
            Item(id: "ielts", title: "雅思阅读", detail: "⌘4", symbol: "doc.text.magnifyingglass", action: .study("学习_雅思阅读")),
            Item(id: "vocab", title: "阅读词汇", detail: "⌘5", symbol: "text.book.closed", action: .study("学习_阅读词汇")),
            Item(id: "writing", title: "写作", detail: "⌘6", symbol: "pencil", action: .study("学习_写作_Task1题库")),
            Item(id: "stats", title: "统计", detail: "⌘7", symbol: "chart.bar", action: .statistics),
            Item(id: "wrong", title: "错词复习", detail: "听力", symbol: "arrow.counterclockwise", action: .study("学习_听力_错词")),
            Item(id: "continue", title: "继续听写", detail: "听力 · 本轮", symbol: "play.fill", action: .study("学习_听力_今日计划")),
            Item(id: "cloud", title: "云盘", detail: "", symbol: "cloud", action: .cloud),
            Item(id: "import", title: "导入图书…", detail: "⌘O", symbol: "plus", action: .importBooks),
            Item(id: "settings", title: "设置", detail: "⌘,", symbol: "gearshape", action: .settings),
        ]
    }

    private var results: [Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedCommands = q.isEmpty ? commands : commands.filter { $0.title.localizedCaseInsensitiveContains(q) }
        let books = store.shelfBooks
            .filter { q.isEmpty ? false : ($0.title + " " + $0.author).localizedCaseInsensitiveContains(q) }
            .sorted { $0.lastOpened > $1.lastOpened }
            .prefix(8)
            .map { book in
                Item(id: "book-\(book.id.uuidString)", title: book.title,
                     detail: book.progress > 0 ? "读到 \(Int((min(1, max(0, book.progress)) * 100).rounded()))%" : "书",
                     symbol: "book", action: .book(book.id))
            }
        return Array(books) + matchedCommands
    }

    var body: some View {
        let items = results
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索书名、作者或功能", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onSubmit { run(items) }
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            Divider()
            if items.isEmpty {
                VStack(spacing: 6) {
                    Text("没有找到「\(query)」")
                        .font(.callout)
                    Text("可以搜书名、作者，或「听力」「写作」这样的功能名")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                Button { selection = index; run(items) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.symbol)
                                            .frame(width: 20)
                                            .foregroundStyle(index == selection ? AnyShapeStyle(store.accent) : AnyShapeStyle(.secondary))
                                        Text(item.title)
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 38)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(index == selection ? store.accent.opacity(0.14) : Color.clear))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(index)
                                .onHover { inside in if inside { selection = index } }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: selection) { _, value in
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.15)) { proxy.scrollTo(value) }
                    }
                }
            }
        }
        .frame(width: 560)
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in selection = 0 }
        .onKeyPress(.downArrow) {
            selection = min(selection + 1, max(0, items.count - 1)); return .handled
        }
        .onKeyPress(.upArrow) {
            selection = max(selection - 1, 0); return .handled
        }
        .onKeyPress(.escape) {
            onClose(); return .handled
        }
    }

    private func run(_ items: [Item]) {
        guard items.indices.contains(selection) else { return }
        onRun(items[selection].action)
    }
}
