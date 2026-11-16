import SwiftUI
import UIKit
import WebKit
import UniformTypeIdentifiers
import Foundation

// MARK: - 书架

struct BookShelfView: View {
    var onAddWord: (String, String) -> Void

    @State private var library = BookLibrary()
    @State private var isImporting = false
    @State private var banner: ShelfBanner?

    init(onAddWord: @escaping (String, String) -> Void = { _, _ in }) {
        self.onAddWord = onAddWord
    }

    var body: some View {
        NavigationStack {
            Group {
                if library.books.isEmpty {
                    emptyState
                } else {
                    bookList
                }
            }
            .navigationTitle("阅读")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(LumaIconButtonStyle())
                    .accessibilityLabel("导入书籍")
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: importTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .navigationDestination(for: Book.self) { book in
                ReaderView(book: book, onAddWord: onAddWord)
                    .environment(library)
            }
            .overlay(alignment: .bottom) {
                bannerView
            }
            .onAppear { seedSampleBookIfRequested() }
        }
    }

    /// 每次启动只种一次；否则每次回到书架都会把书删掉重导，阅读进度会被清零。
    private static var didSeedSampleBook = false

    /// 仅供 UI 测试：`-seed-sample-book` 启动时把包内的 sample.epub 导进书架，
    /// 免得自动化去驱动系统「文件」选择器。Release 构建里这段代码不存在。
    private func seedSampleBookIfRequested() {
        #if DEBUG
        guard !Self.didSeedSampleBook,
              ProcessInfo.processInfo.arguments.contains("-seed-sample-book"),
              let url = Bundle.main.url(forResource: "sample", withExtension: "epub") else {
            return
        }
        // 包里的示例书换了内容也要重新种一遍，否则打开的是上一次留下的旧章节。
        for book in library.books { library.delete(book) }
        try? library.importBook(from: url)
        Self.didSeedSampleBook = true
        #endif
    }

    private var importTypes: [UTType] {
        var types: [UTType] = []
        if let epub = UTType(filenameExtension: "epub") {
            types.append(epub)
        }
        types.append(.zip)
        types.append(.plainText)
        types.append(.html)
        if let markdown = UTType(filenameExtension: "md") {
            types.append(markdown)
        }
        return types
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("书架还是空的", systemImage: "books.vertical")
        } description: {
            Text("导入 EPUB、ZIP、TXT、Markdown 或 HTML 文件，开始阅读。")
        } actions: {
            Button("导入书籍") {
                isImporting = true
            }
            .buttonStyle(LumaPrimaryButtonStyle())
        }
    }

    private var bookList: some View {
        List {
            Section {
                ForEach(library.books) { book in
                    NavigationLink(value: book) {
                        BookRow(book: book)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(book)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(book)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("共 \(library.books.count) 本")
            } footer: {
                Text("左滑或长按可以删除书籍。")
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner {
            Label(banner.text, systemImage: banner.systemImage)
                .font(.footnote)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.lumaSurface, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.08))
                }
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: banner.id) {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy(duration: 0.14)) {
                        self.banner = nil
                    }
                }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            banner = ShelfBanner(text: "无法选择文件：\(error.localizedDescription)",
                                 systemImage: "exclamationmark.triangle")
        case .success(let urls):
            guard !urls.isEmpty else { return }
            var imported = 0
            var attempted = 0
            var firstFailure: String?
            for url in urls {
                for candidate in Self.expandForImport(url) {
                    attempted += 1
                    do {
                        _ = try library.importBook(from: candidate)
                        imported += 1
                    } catch {
                        if firstFailure == nil {
                            firstFailure = error.localizedDescription
                        }
                    }
                }
            }

            if imported > 0 {
                let failedCount = max(0, attempted - imported)
                let suffix = failedCount > 0 ? "，\(failedCount) 本失败" : ""
                banner = ShelfBanner(text: "已导入 \(imported) 本\(suffix)",
                                     systemImage: "books.vertical")
            } else if let firstFailure {
                banner = ShelfBanner(text: "导入失败：\(firstFailure)",
                                     systemImage: "exclamationmark.triangle")
            }
        }
    }

    /// 用户在文档选择器里可能选中的是整个文件夹（iOS 26/27 的「文件」允许把文件夹当作选中项），
    /// 这时把夹里能读的电子书一次导入，比报「导入失败」有用。
    private static let importableExtensions: Set<String> = [
        "epub", "zip", "txt", "text", "md", "markdown", "html", "htm"
    ]

    private static func expandForImport(_ url: URL) -> [URL] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return [url]
        }

        let entries = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let books = entries.filter { importableExtensions.contains($0.pathExtension.lowercased()) }
        // 夹里没有能读的书时仍然试着导入，让错误信息落到用户眼前
        return books.isEmpty ? [url] : books.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func delete(_ book: Book) {
        let title = book.title
        library.delete(book)
        banner = ShelfBanner(text: "已删除《\(title)》", systemImage: "trash")
    }
}

private struct ShelfBanner: Identifiable {
    let id = UUID()
    let text: String
    let systemImage: String
}

private struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            BookCoverView(title: book.title, seed: book.id)

            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(book.author.isEmpty ? "未知作者" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ProgressView(value: min(max(book.progress, 0), 1))
                        .tint(Color.lumaAccent)
                        .frame(width: 72)

                    Text("\(Int((book.progress * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Text("\(book.chapters.count) 章")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct BookCoverView: View {
    let title: String
    let seed: String

    private static let palette: [Color] = [
        Color(red: 0.36, green: 0.44, blue: 0.52),
        Color(red: 0.47, green: 0.37, blue: 0.31),
        Color(red: 0.31, green: 0.47, blue: 0.43),
        Color(red: 0.51, green: 0.42, blue: 0.34),
        Color(red: 0.38, green: 0.40, blue: 0.52),
        Color(red: 0.50, green: 0.35, blue: 0.40),
        Color(red: 0.34, green: 0.46, blue: 0.57),
        Color(red: 0.43, green: 0.43, blue: 0.36)
    ]

    private var initial: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map(String.init) ?? "书"
    }

    private var color: Color {
        var hash = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0x7FFF_FFFF
        }
        return Self.palette[hash % Self.palette.count]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(width: 54, height: 74)
            .overlay {
                Text(initial)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.94))
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 3)
                    .padding(.vertical, 7)
                    .padding(.trailing, 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 阅读页

struct ReaderView: View {
    let onAddWord: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(BookLibrary.self) private var library: BookLibrary?

    @State private var book: Book
    @State private var chapterIndex: Int
    @State private var chapterFraction: Double = 0
    @State private var pageIndex = 0
    @State private var pageCount = 0
    @State private var lookupTarget: LookupTarget?
    @State private var notice: ReaderNotice?
    @State private var loadError: String?
    @State private var lastLookupKey = ""
    @State private var lastLookupTime = Date.distantPast
    @State private var progressSaveTask: Task<Void, Never>?
    @State private var pageTurn = PageTurnHandle()
    @State private var pendingRestoreFraction: Double?
    @State private var didRestorePage = false
    @AppStorage("readerFontLevel") private var fontLevel = 1

    private let fontSizes = [16, 19, 22]

    init(book: Book, onAddWord: @escaping (String, String) -> Void = { _, _ in }) {
        self.onAddWord = onAddWord
        _book = State(initialValue: book)
        let count = max(book.chapters.count, 1)
        let initialChapter = min(max(Int(book.progress * Double(count)), 0), count - 1)
        _chapterIndex = State(initialValue: initialChapter)
        let fraction = book.progress * Double(count) - Double(initialChapter)
        _pendingRestoreFraction = State(initialValue: fraction > 0.001 ? min(fraction, 1) : nil)
    }

    var body: some View {
        Group {
            if let chapter = currentChapter {
                VStack(spacing: 0) {
                    ZStack {
                        ChapterWebView(
                        chapter: chapter,
                        chapterIndex: chapterIndex,
                        bookDirectory: bookDirectory,
                        fontSize: fontSize,
                        pageTurn: pageTurn,
                        onSelection: handleSelection,
                        onChapterTurn: turnChapter,
                        onPagination: handlePagination,
                        onFailure: { message in
                            loadError = message
                        }
                        )

                        pageTurnZones
                    }

                    bottomBar
                }
            } else {
                ContentUnavailableView("这本书没有可阅读的章节", systemImage: "book.closed")
            }
        }
        .background(Color.lumaPaper.ignoresSafeArea())
        .navigationTitle(currentChapter?.title ?? book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            fontToolbar
        }
        .sheet(item: $lookupTarget) { target in
            WordLookupSheet(word: target.word) { word in
                let meaning = ReaderVocabulary.lookup(word)?.meaning ?? ""
                onAddWord(word, meaning)
                showNotice("已加入生词本")
            }
        }
        .alert("无法打开这一章", isPresented: Binding(
            get: { loadError != nil },
            set: { newValue in
                if !newValue { loadError = nil }
            }
        )) {
            Button("好", role: .cancel) {
                loadError = nil
            }
        } message: {
            Text(loadError ?? "")
        }
        .overlay(alignment: .top) {
            noticeView
        }
        .onChange(of: fontLevel) { _, _ in
            chapterFraction = 0
            pageIndex = 0
            pageCount = 0
        }
        .onDisappear {
            progressSaveTask?.cancel()
            persistProgress()
        }
    }

    private var currentChapter: Chapter? {
        guard book.chapters.indices.contains(chapterIndex) else { return nil }
        return book.chapters[chapterIndex]
    }

    private var bookDirectory: URL {
        library?.bookDirectory(for: book.id)
            ?? BookLibrary.defaultBooksRoot().appendingPathComponent(book.id, isDirectory: true)
    }

    private var fontSize: Int {
        fontSizes[min(max(fontLevel, 0), fontSizes.count - 1)]
    }

    private var overallProgress: Double {
        guard !book.chapters.isEmpty else { return 0 }
        let value = (Double(chapterIndex) + chapterFraction) / Double(book.chapters.count)
        return min(max(value, 0), 1)
    }

    @ToolbarContentBuilder
    private var fontToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(fontSizes.indices, id: \.self) { index in
                    Button {
                        fontLevel = index
                    } label: {
                        if index == fontLevel {
                            Label(fontLabel(index), systemImage: "checkmark")
                        } else {
                            Text(fontLabel(index))
                        }
                    }
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel("字号")
        }
    }

    private func fontLabel(_ index: Int) -> String {
        switch index {
        case 0:
            return "小"
        case 2:
            return "大"
        default:
            return "中"
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            chapterButton(direction: -1, title: "上一章", systemImage: "chevron.left")

            VStack(spacing: 6) {
                Text(currentChapter?.title ?? book.title)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)

                ProgressView(value: overallProgress)
                    .tint(Color.lumaAccent)

                HStack(spacing: 6) {
                    Text("第 \(chapterIndex + 1) / \(max(book.chapters.count, 1)) 章")
                        .accessibilityIdentifier("reader.chapter")
                    if pageCount > 1 {
                        Text("· \(min(pageIndex + 1, pageCount)) / \(pageCount) 页")
                            .accessibilityIdentifier("reader.page")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .layoutPriority(1)

            chapterButton(direction: 1, title: "下一章", systemImage: "chevron.right")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func chapterButton(direction: Int, title: String, systemImage: String) -> some View {
        Button {
            turnChapter(direction)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 54, height: 44)
        }
        .buttonStyle(ReaderPressStyle())
        .disabled(!canTurn(direction))
        .opacity(canTurn(direction) ? 1 : 0.3)
        .accessibilityLabel(title)
    }

    // 左右两侧各留一条 48pt 的翻页带：先翻页，翻到底再交给章节切换。
    private var pageTurnZones: some View {
        HStack(spacing: 0) {
            turnZone(direction: -1, title: "上一页", systemImage: "chevron.backward")
            Spacer(minLength: 0)
            turnZone(direction: 1, title: "下一页", systemImage: "chevron.forward")
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func turnZone(direction: Int, title: String, systemImage: String) -> some View {
        Color.clear
            .frame(width: 48)
            .contentShape(Rectangle())
            .onTapGesture { pageTurn.turn(direction) }
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var noticeView: some View {
        if let notice {
            Text(notice.text)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.lumaSurface, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.08))
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: notice.id) {
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy(duration: 0.14)) {
                        self.notice = nil
                    }
                }
        }
    }

    private func canTurn(_ direction: Int) -> Bool {
        book.chapters.indices.contains(chapterIndex + direction)
    }

    private func turnChapter(_ direction: Int) {
        let target = chapterIndex + direction
        guard book.chapters.indices.contains(target) else { return }
        chapterIndex = target
        chapterFraction = 0
        pageIndex = 0
        pageCount = 0
        didRestorePage = true
        loadError = nil
        persistProgress()
    }

    private func handlePagination(offset: Double, index: Int, count: Int) {
        chapterFraction = offset.isFinite ? min(max(offset, 0), 1) : 0
        pageIndex = max(index, 0)
        pageCount = max(count, 0)
        if !didRestorePage, pageCount > 1 {
            didRestorePage = true
            // 书架传进来的 Book 可能是上一步的快照，优先向书库要磁盘上的最新进度。
            let saved = library?.books.first(where: { $0.id == book.id })?.progress ?? book.progress
            let chapters = max(book.chapters.count, 1)
            let fraction = saved * Double(chapters) - Double(chapterIndex)
            if fraction > 0.001, fraction < 0.999 {
                let target = Int((fraction * Double(pageCount - 1)).rounded())
                if target > 0 {
                    pageTurn.jump(to: target)
                    return
                }
            }
        }
        scheduleProgressSave()
    }

    private func handleSelection(_ raw: String) {
        guard let word = ReaderWordSelection.normalized(raw) else { return }
        let key = word.lowercased()
        let now = Date()
        if key == lastLookupKey, now.timeIntervalSince(lastLookupTime) < 1.2 {
            return
        }
        lastLookupKey = key
        lastLookupTime = now
        lookupTarget = LookupTarget(word: word)
    }

    private func showNotice(_ text: String) {
        withAnimation(.snappy(duration: 0.14)) {
            notice = ReaderNotice(text: text)
        }
    }

    private func scheduleProgressSave() {
        progressSaveTask?.cancel()
        progressSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            persistProgress()
        }
    }

    private func persistProgress() {
        let value = overallProgress
        book.progress = value
        library?.updateProgress(bookID: book.id, value: value)
    }
}

private struct LookupTarget: Identifiable {
    let id = UUID()
    let word: String
}

private struct ReaderNotice: Identifiable {
    let id = UUID()
    let text: String
}

private struct ReaderPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - 翻页把手

/// 把 SwiftUI 的点击转发给 WKWebView 里的 Reader.js；翻到本章头尾时由 Coordinator 交给章节切换。
@MainActor
final class PageTurnHandle {
    var handler: ((Int) -> Void)?
    var jumper: ((Int) -> Void)?

    func turn(_ delta: Int) {
        handler?(delta)
    }

    /// 直接跳到某一页（用于「接着上次读到的那一页」）。
    func jump(to page: Int) {
        jumper?(page)
    }
}

// MARK: - 网页章节视图

private struct ChapterWebView: UIViewRepresentable {
    let chapter: Chapter
    let chapterIndex: Int
    let bookDirectory: URL
    let fontSize: Int
    let pageTurn: PageTurnHandle
    let onSelection: (String) -> Void
    let onChapterTurn: (Int) -> Void
    let onPagination: (_ offset: Double, _ index: Int, _ count: Int) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "selection")
        contentController.add(context.coordinator, name: "reader")
        contentController.addUserScript(WKUserScript(source: Coordinator.selectionScript,
                                                     injectionTime: .atDocumentEnd,
                                                     forMainFrameOnly: true))
        contentController.addUserScript(WKUserScript(source: Coordinator.wordTapScript,
                                                     injectionTime: .atDocumentEnd,
                                                     forMainFrameOnly: true))
        contentController.addUserScript(WKUserScript(source: Coordinator.iosPagerScript,
                                                     injectionTime: .atDocumentEnd,
                                                     forMainFrameOnly: true))
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.attach(webView)
        pageTurn.handler = { [weak coordinator = context.coordinator] delta in
            coordinator?.turnPage(delta: delta)
        }
        pageTurn.jumper = { [weak coordinator = context.coordinator] page in
            coordinator?.jumpToPage(page)
        }
        context.coordinator.loadIfNeeded()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.pageTurn = pageTurn
        context.coordinator.loadIfNeeded()
        context.coordinator.refreshLayoutIfNeeded(in: uiView)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "selection")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "reader")
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ChapterWebView
        var pageTurn: PageTurnHandle?

        private weak var webView: WKWebView?
        private var signature: String?
        private var appliedWidth: CGFloat = 0

        init(parent: ChapterWebView) {
            self.parent = parent
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        func loadIfNeeded() {
            let newSignature = "\(parent.chapter.id)|\(parent.chapterIndex)|\(parent.fontSize)"
            guard newSignature != signature else { return }
            signature = newSignature
            guard let webView else { return }

            let html = ReaderHTML.compose(content: parent.chapter.html, fontSize: parent.fontSize)
            let directory = parent.bookDirectory
            let fileURL = directory.appendingPathComponent(".render-\(parent.chapterIndex).html")
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try html.write(to: fileURL, atomically: true, encoding: .utf8)
                webView.loadFileURL(fileURL, allowingReadAccessTo: directory)
            } catch {
                parent.onFailure("章节渲染文件写入失败，请检查存储空间后重试。")
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applySettings()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }
            parent.onFailure("章节加载失败：\(error.localizedDescription)")
        }

        private func applySettings() {
            guard let webView else { return }
            let options: [String: Any] = [
                "language": "zh-Hans",
                "lineHeight": 1.75,
                "paragraphSpacing": 1.35,
                "indent": false
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: options),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }
            // Reader.js 的 settings 使用位置参数：size、width、dark、theme、font、options。
            // 宽度按 WebView 实际宽度减左右留白算，竖屏约 350pt，旋转后 updateUIView 会重算。
            let bounds = webView.bounds.width > 0 ? webView.bounds.width : UIScreen.main.bounds.width
            appliedWidth = bounds
            let width = max(240, Int(bounds.rounded()) - 36)
            let script = "window.Luma && window.Luma.settings ? window.Luma.settings(\(parent.fontSize), \(width), false, 'paper', 'serif', \(json)) : false"
            webView.evaluateJavaScript(script) { _, _ in
                webView.evaluateJavaScript("window.__lumaPagerReport ? window.__lumaPagerReport() : 0",
                                           completionHandler: nil)
            }
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "selection":
                if let text = message.body as? String {
                    parent.onSelection(text)
                }
            case "reader":
                handleReaderMessage(message.body)
            default:
                break
            }
        }

        private func handleReaderMessage(_ rawBody: Any) {
            guard let body = rawBody as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }

            switch type {
            case "selection":
                if let quote = body["quote"] as? String {
                    parent.onSelection(quote)
                }
            case "pagination":
                parent.onPagination(doubleValue(body["offset"]),
                                    intValue(body["index"]),
                                    intValue(body["count"]))
            case "wordTap":
                if let word = body["word"] as? String {
                    parent.onSelection(word)
                }
            case "turn":
                let delta = intValue(body["delta"]) >= 0 ? 1 : -1
                turnPage(delta: delta)
            default:
                break
            }
        }

        func refreshLayoutIfNeeded(in webView: WKWebView) {
            let width = webView.bounds.width
            guard width > 0, abs(width - appliedWidth) > 2 else { return }
            applySettings()
        }

        func jumpToPage(_ page: Int) {
            guard let webView else { return }
            webView.evaluateJavaScript("window.__lumaPagerJump ? window.__lumaPagerJump(\(max(page, 0))) : 0",
                                       completionHandler: nil)
        }

        func turnPage(delta: Int) {
            guard let webView else { return }
            let script = "window.Luma && window.Luma.turn ? window.Luma.turn(\(delta)) : false"
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self else { return }
                if let handled = result as? Bool, handled {
                    return
                }
                if let handled = result as? NSNumber, handled.boolValue {
                    return
                }
                self.parent.onChapterTurn(delta)
            }
        }

        private func doubleValue(_ value: Any?) -> Double {
            if let number = value as? NSNumber { return number.doubleValue }
            if let double = value as? Double { return double }
            if let int = value as? Int { return Double(int) }
            return 0
        }

        private func intValue(_ value: Any?) -> Int {
            if let number = value as? NSNumber { return number.intValue }
            if let int = value as? Int { return int }
            if let double = value as? Double { return Int(double) }
            return 0
        }

        /// iOS 不套 `#luma-viewport`（Reader.js 见到它就进横向分栏模式，窄屏只有一列、
        /// 超出部分被裁掉）。这里自己按屏幕高度切页：整行对齐，一页就是一屏。
        static let iosPagerScript = """
        (function () {
          if (window.__lumaPagerInstalled) { return; }
          window.__lumaPagerInstalled = true;
          var pageIndex = 0;

          function content() { return document.getElementById('luma-content'); }

          function layout() {
            var root = content();
            if (!root) { return; }
            var viewportWidth = window.innerWidth || 360;
            var width = Math.max(240, viewportWidth - 36);
            var side = Math.max(10, Math.round((viewportWidth - width) / 2));
            root.style.setProperty('width', width + 'px', 'important');
            root.style.setProperty('max-width', width + 'px', 'important');
            root.style.setProperty('margin-left', side + 'px', 'important');
            root.style.setProperty('margin-right', side + 'px', 'important');
            root.style.setProperty('box-sizing', 'border-box', 'important');
            document.documentElement.style.setProperty('--reader-width', width + 'px');
          }

          function geometry() {
            var root = content();
            var lineHeight = root ? (parseFloat(getComputedStyle(root).lineHeight) || 32) : 32;
            var available = Math.max(160, (window.innerHeight || 600) - 4);
            var step = Math.max(lineHeight, Math.floor(available / lineHeight) * lineHeight);
            return { step: step, available: available, lineHeight: lineHeight };
          }

          function pageCount() {
            var root = content();
            if (!root) { return 1; }
            var g = geometry();
            return Math.max(1, Math.ceil((root.scrollHeight + g.step * 0.15) / g.step));
          }

          function paint(animate) {
            var root = content();
            if (!root) { return; }
            var g = geometry();
            var total = pageCount();
            pageIndex = Math.min(Math.max(pageIndex, 0), total - 1);
            // 只让「一页高」的身体露出来，正文按页整体上移，页与页之间不会露出半行。
            document.body.style.height = g.step + 'px';
            document.body.style.overflow = 'hidden';
            root.style.transition = animate ? 'transform 180ms cubic-bezier(0.23, 1, 0.32, 1)' : 'none';
            root.style.transform = 'translate3d(0,' + (-pageIndex * g.step) + 'px,0)';
            try {
              window.webkit.messageHandlers.reader.postMessage({
                type: 'pagination',
                index: pageIndex,
                count: total,
                offset: total > 1 ? pageIndex / (total - 1) : 1,
                canForward: pageIndex + 1 < total
              });
            } catch (error) {}
          }

          window.__lumaPagerReport = function () { layout(); paint(false); };

          function installTurn() {
            if (!window.Luma) { setTimeout(installTurn, 60); return; }
            window.Luma.turn = function (delta) {
              var total = pageCount();
              var target = pageIndex + (delta > 0 ? 1 : -1);
              if (target < 0 || target >= total) { return false; }
              pageIndex = target;
              paint(true);
              return true;
            };
            window.Luma.__pagerIndex = function () { return pageIndex; };
            window.__lumaPagerJump = function (index) {
              var total = pageCount();
              pageIndex = Math.min(Math.max(Number(index) || 0, 0), total - 1);
              paint(false);
            };
          }
          function installMask() {
            if (document.getElementById('luma-page-mask')) { return; }
            var mask = document.createElement('div');
            mask.id = 'luma-page-mask';
            mask.style.cssText = 'position:fixed;left:0;right:0;bottom:0;height:6px;background:var(--paper);pointer-events:none;z-index:4';
            document.body.appendChild(mask);
          }
          // 手指左右滑动翻页（比点边缘自然）：在页面里判定，避免 SwiftUI 手势和 WebView 抢触摸。
          function installSwipe() {
            var startX = 0, startY = 0, startTime = 0, tracking = false;
            document.addEventListener('touchstart', function (event) {
              if (event.touches.length !== 1) { tracking = false; return; }
              tracking = true;
              startX = event.touches[0].clientX;
              startY = event.touches[0].clientY;
              startTime = Date.now();
            }, { passive: true });
            document.addEventListener('touchend', function (event) {
              if (!tracking) { return; }
              tracking = false;
              var touch = event.changedTouches && event.changedTouches[0];
              if (!touch) { return; }
              var dx = touch.clientX - startX;
              var dy = touch.clientY - startY;
              var dt = Date.now() - startTime;
              if (dt > 700 || Math.abs(dx) < 48 || Math.abs(dy) > Math.abs(dx) * 0.6) { return; }
              if (window.Luma && typeof window.Luma.turn === 'function') {
                window.Luma.turn(dx < 0 ? 1 : -1);
              }
            }, { passive: true });
          }

          installTurn();
          installSwipe();
          installMask();
          window.addEventListener('resize', function () { setTimeout(function () { layout(); paint(false); }, 120); });
          setTimeout(function () { layout(); paint(false); }, 150);
        })();
        """

        /// 手机上「点一个词」比「长按拖选」自然得多：取点到的那个词直接查。
        static let wordTapScript = """
        (function () {
          if (window.__lumaWordTapInstalled) { return; }
          window.__lumaWordTapInstalled = true;
          function wordAt(x, y) {
            var range = null;
            if (document.caretRangeFromPoint) {
              range = document.caretRangeFromPoint(x, y);
            } else if (document.caretPositionFromPoint) {
              var pos = document.caretPositionFromPoint(x, y);
              if (pos) {
                range = document.createRange();
                range.setStart(pos.offsetNode, pos.offset);
                range.setEnd(pos.offsetNode, pos.offset);
              }
            }
            if (!range) { return ''; }
            var node = range.startContainer;
            if (!node || node.nodeType !== 3) { return ''; }
            var text = node.nodeValue || '';
            var offset = range.startOffset;
            var isWord = /[A-Za-z0-9'’-]/;
            var left = offset;
            var right = offset;
            while (left > 0 && isWord.test(text.charAt(left - 1))) { left--; }
            while (right < text.length && isWord.test(text.charAt(right))) { right++; }
            var word = text.slice(left, right).replace(/^['’-]+/, '').replace(/['’-]+$/, '');
            return word;
          }
          document.addEventListener('click', function (event) {
            var word = wordAt(event.clientX, event.clientY);
            if (!word || word.length < 2 || !/[A-Za-z]/.test(word)) { return; }
            try {
              window.webkit.messageHandlers.reader.postMessage({ type: 'wordTap', word: word });
            } catch (error) {}
          }, true);
        })();
        """

        static let selectionScript = """
        (function () {
          var timer = null;
          var last = '';
          document.addEventListener('selectionchange', function () {
            if (timer) { clearTimeout(timer); }
            timer = setTimeout(function () {
              timer = null;
              var selection = window.getSelection();
              var text = selection ? String(selection.toString()) : '';
              text = text.replace(/\\s+/g, ' ').trim();
              if (!text || text === last) { return; }
              last = text;
              try {
                window.webkit.messageHandlers.selection.postMessage(text);
              } catch (error) {}
            }, 180);
          }, { passive: true });
        })();
        """
    }
}

// MARK: - 组装网页

private enum ReaderHTML {
    static func compose(content: String, fontSize: Int) -> String {
        let css = resource(named: "Reader", fileExtension: "css")
        let script = resource(named: "Reader", fileExtension: "js")
            .replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
        let hasScript = !script.isEmpty
        let appearance = appearanceCSS(fontSize: fontSize, hasScript: hasScript)
        let rootAttributes = ""
        let viewport = "<main id=\"luma-content\">\(content)</main>"
        let scriptTag = hasScript ? "<script>\(script)</script>" : ""
        return "<!doctype html><html\(rootAttributes)><head>"
            + "<meta charset=\"utf-8\">"
            + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            + "<style>\(css)\n\(appearance)</style></head>"
            + "<body>\(viewport)\(scriptTag)</body></html>"
    }

    private static func appearanceCSS(fontSize: Int, hasScript: Bool) -> String {
        var css = """
        :root{--paper:#FAF8F3;--text:#33322E;--reader-size:\(fontSize)px;--reader-width:calc(100vw - 36px);--reader-leading:1.75;--reader-paragraph:1.35em;--reader-indent:0}
        html,body{background:var(--paper);color:var(--text)}
        html,body{overflow-x:hidden;-webkit-text-size-adjust:100%}
        body{height:100%;overflow-y:auto;-webkit-overflow-scrolling:touch;padding:0 !important}
        #luma-content{width:calc(100vw - 36px);margin:0 auto;padding:6px 0 16px}
        #luma-page-footer{display:none !important}
        """
        if !hasScript {
            css += """

            #luma-content{padding:14px 0 24px}
            """
        }
        return css
    }

    private static func resource(named name: String, fileExtension: String) -> String {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: fileExtension),
            Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources")
        ]
        for url in candidates.compactMap({ $0 }) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return ""
    }
}

// MARK: - 查词

struct WordLookupSheet: View {
    let word: String
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSystemDictionary = false

    private var entry: ReaderVocabulary.Entry? {
        ReaderVocabulary.lookup(word)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let entry {
                    ScrollView {
                        Text(entry.meaning.isEmpty ? "暂无释义" : entry.meaning)
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                } else {
                    missingBlock
                }

                Spacer(minLength: 0)

                Button {
                    onAdd(word)
                    dismiss()
                } label: {
                    Label("加入生词本", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LumaPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.lumaPaper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .buttonStyle(ReaderPressStyle())
                    .foregroundStyle(Color.lumaAccent)
                }
            }
            .sheet(isPresented: $showSystemDictionary) {
                NavigationStack {
                    SystemDictionaryView(term: word)
                        .ignoresSafeArea()
                        .navigationTitle(word)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完成") {
                                    showSystemDictionary = false
                                }
                            }
                        }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(word)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .textSelection(.enabled)

            if let ipa = entry?.ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missingBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内置词表没有收录")
                .font(.headline)

            Text("可以改用系统词典查询，或先把这个词加入生词本。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            dictionaryAction
        }
    }

    @ViewBuilder
    private var dictionaryAction: some View {
        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word) {
            Button {
                showSystemDictionary = true
            } label: {
                Label("用系统词典查询", systemImage: "character.book.closed")
            }
            .buttonStyle(LumaSecondaryButtonStyle())
        } else if let url = systemDictionaryURL {
            Link("在系统词典里查询", destination: url)
                .font(.subheadline)
                .foregroundStyle(Color.lumaAccent)
        }
    }

    private var systemDictionaryURL: URL? {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "dict://\(encoded)")
    }
}

private struct SystemDictionaryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}

// MARK: - 内置词表

private enum ReaderVocabulary {
    struct Entry {
        let id: String
        let word: String
        let meaning: String
        let ipa: String
        let aliases: [String]
    }

    private static let index: [String: Entry] = buildIndex()

    static func lookup(_ term: String) -> Entry? {
        let key = normalize(term)
        guard !key.isEmpty else { return nil }
        if let exact = index[key] {
            return exact
        }
        if key.hasSuffix("'s") {
            let base = String(key.dropLast(2))
            if let hit = index[base] {
                return hit
            }
        }
        if key.hasSuffix("s"), key.count > 3 {
            let base = String(key.dropLast())
            if let hit = index[base] {
                return hit
            }
        }
        return nil
    }

    private static func buildIndex() -> [String: Entry] {
        let candidates = [
            Bundle.main.url(forResource: "ReadingVocabulary", withExtension: "json"),
            Bundle.main.url(forResource: "ReadingVocabulary", withExtension: "json", subdirectory: "Resources")
        ]
        guard let url = candidates.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let raw = object as? [[String: Any]] else {
            return [:]
        }

        var map: [String: Entry] = [:]
        map.reserveCapacity(raw.count)

        for item in raw {
            guard let word = item["word"] as? String, !word.isEmpty else { continue }
            let label = (item["label"] as? String) ?? ""
            let aliases = (item["aliases"] as? [String]) ?? []
            let entry = Entry(id: (item["id"] as? String) ?? word,
                              word: word,
                              meaning: (item["meaning"] as? String) ?? "",
                              ipa: (item["ipa"] as? String) ?? "",
                              aliases: aliases)

            var keys: [String] = [word]
            if !label.isEmpty { keys.append(label) }
            keys.append(contentsOf: aliases)

            for key in keys {
                let normalized = normalize(key)
                if !normalized.isEmpty, map[normalized] == nil {
                    map[normalized] = entry
                }
            }
        }
        return map
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

private enum ReaderWordSelection {
    static func normalized(_ raw: String) -> String? {
        let cleaned = raw
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "–", with: " ")

        var words: [String] = []
        for token in cleaned.split(whereSeparator: { $0.isWhitespace }) {
            let filtered = token.filter { character in
                guard character.unicodeScalars.count == 1,
                      let scalar = character.unicodeScalars.first else {
                    return false
                }
                if scalar.value == 39 || scalar.value == 45 {
                    return true
                }
                guard scalar.isASCII else { return false }
                return (scalar.value >= 65 && scalar.value <= 90)
                    || (scalar.value >= 97 && scalar.value <= 122)
            }
            let trimmed = filtered.trimmingCharacters(in: CharacterSet(charactersIn: "'-"))
            guard !trimmed.isEmpty else { continue }
            words.append(trimmed)
            if words.count == 3 { break }
        }

        guard !words.isEmpty else { return nil }
        return words.joined(separator: " ")
    }
}
