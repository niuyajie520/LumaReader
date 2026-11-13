import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ReadingVocabularySource: String, CaseIterable, Decodable, Sendable {
    case base, supplement, advanced

    var title: String {
        switch self {
        case .base: "雅思词汇真经"
        case .supplement: "阅读补充词表"
        case .advanced: "阅读进阶词表"
        }
    }
}

private struct ReadingVocabularyEntry: Decodable, Identifiable, Sendable {
    let id: String
    let word: String
    let label: String
    let meaning: String
    let ipa: String
    let source: ReadingVocabularySource
    let chapter: Int?
    let number: Int
    let aliases: [String]
    let form: String?

    func matches(_ query: String) -> Bool {
        word.localizedStandardContains(query) ||
        label.localizedStandardContains(query) ||
        meaning.localizedStandardContains(query) ||
        aliases.contains { $0.localizedStandardContains(query) }
    }
}

enum ReadingVocabularyCatalog {
    fileprivate static let entries: [ReadingVocabularyEntry]? = {
        let roots = [Bundle.main.resourceURL, Bundle.main.bundleURL,
                     Bundle.main.executableURL?.deletingLastPathComponent()].compactMap { $0 }
        let bundleNames = ["StudyCenter_LumaReaderStudyKit.bundle", "LumaReader_LumaReaderStudyKit.bundle"]
        var bundles = [Bundle.main]
        bundles += roots.flatMap { root in
            bundleNames.compactMap { Bundle(url: root.appendingPathComponent($0)) }
        }
        for bundle in bundles {
            guard let url = bundle.url(forResource: "ReadingVocabulary", withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { continue }
            if let entries = try? JSONDecoder().decode([ReadingVocabularyEntry].self, from: data) {
                return entries
            }
        }
        return nil
    }()
    static func deckID(_ source: ReadingVocabularySource) -> String {
        "reading_builtin_" + source.rawValue
    }

    static let wordsByDeck: [String: [VocabularyWord]] = Dictionary(
        grouping: (entries ?? []).map { entry in
            VocabularyWord(id: "reading_" + entry.id, word: entry.word, phoneticUK: entry.ipa,
                           definitionZH: entry.meaning, deckID: deckID(entry.source), deckTitle: entry.source.title)
        }, by: \.deckID
    )

    static let wordsByID = Dictionary(uniqueKeysWithValues: wordsByDeck.values.flatMap { $0 }.map { ($0.id, $0) })

}

enum VocabularyPageLayout {
    static let inset: CGFloat = 32
    static let topInset: CGFloat = 18
    static let spacing: CGFloat = 16
    static let cardHeight: CGFloat = 174
    static var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 188, maximum: 242), spacing: spacing, alignment: .topLeading)]
    }
}

struct VocabularyPageHeading<Actions: View>: View {
    let title: String
    let placeholder: String
    @Binding var search: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .lumaFont(size: 28, weight: .bold, design: .serif)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            StudySearchField(placeholder, text: $search, width: 215)
            actions()
        }
    }
}

struct VocabularyPageMenuLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .frame(width: 30, height: 32)
            .contentShape(Rectangle())
    }
}

struct ReadingVocabularyPosition {
    var source: ReadingVocabularySource?
    var customDeckID: String?
    var chapter: Int?
    var search = ""
    var cardID: String?
    var wordID: String?
}

struct ReadingVocabularyView: View {
    @Environment(\.studyAppearance) private var appearance
    @ObservedObject var library: LumaChoiceLibrary
    let onStart: (String) -> Void
    let onConfusable: () -> Void
    @State private var importShown = false
    @State private var draft: VocabularyImportDraft?
    @State private var entries: [ReadingVocabularyEntry] = []
    @Binding var position: ReadingVocabularyPosition

    private var source: ReadingVocabularySource? { position.source }
    private var customDeckID: String? { position.customDeckID }
    private var chapter: Int? { position.chapter }
    private var search: String { position.search }
    @State private var isLoading = true
    @State private var failedToLoad = false

    private var chapters: [Int] {
        Set(entries.compactMap(\.chapter)).sorted()
    }

    var body: some View {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let customDeck = customDeckID.flatMap { library.deck($0) }
        let scopedEntries = source == nil ? entries : entries.filter {
            $0.source == source && (chapter == nil || $0.chapter == chapter)
        }
        let imported = customDeck.map { library.words(in: $0.id) } ?? (source == nil ? library.allWords : [])
        let matchingImports = query.isEmpty ? imported : imported.filter {
            $0.word.localizedStandardContains(query) || $0.definitionZH.localizedStandardContains(query)
        }

        VStack(alignment: .leading, spacing: VocabularyPageLayout.spacing) {
            HStack(spacing: 12) {
                if source != nil || customDeck != nil {
                    Button {
                        position.source = nil
                        position.chapter = nil
                        position.customDeckID = nil
                        position.wordID = nil
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                    .accessibilityLabel("返回阅读词库")
                }
                VocabularyPageHeading(title: customDeck?.title ?? source?.title ?? "阅读词汇",
                                      placeholder: "搜索单词或释义", search: $position.search) {
                    if let deckID = customDeck?.id ?? source.map(ReadingVocabularyCatalog.deckID) {
                        Button(LumaChoiceQuizProgress.draft(for: deckID) == nil ? "开始背词" : "继续背词") { onStart(deckID) }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 12, height: 32))
                            .disabled(library.readingWords(in: deckID).isEmpty)
                    } else {
                        Menu {
                            Button("导入词库…", systemImage: "square.and.arrow.down") { importShown = true }
                            Button("易混词", systemImage: "arrow.left.arrow.right", action: onConfusable)
                        } label: {
                            VocabularyPageMenuLabel()
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .help("阅读词库操作")
                        .accessibilityLabel("阅读词库操作")
                    }
                }
            }
            if let error = library.lastError {
                Text(error).foregroundStyle(.red)
            }
            if source == .base {
                HStack(spacing: 12) {
                    Picker("List", selection: $position.chapter) {
                        Text("全部 List").tag(Int?.none)
                        ForEach(chapters, id: \.self) { value in
                            Text("List \(value)").tag(Optional(value))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 165)
                    Text("\(scopedEntries.count) 词")
                        .lumaFont(size: 12)
                        .monospacedDigit()
                        .foregroundStyle(appearance.ink.opacity(0.64))
                }
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failedToLoad {
                ContentUnavailableView("阅读词库加载失败", systemImage: "book.closed")
            } else if source == nil && customDeck == nil && query.isEmpty {
                deckGrid
            } else {
                let builtIn = customDeck == nil ? scopedEntries : []
                wordList(query.isEmpty ? builtIn : builtIn.filter { $0.matches(query) }, imported: matchingImports)
            }
        }
        .padding(.horizontal, VocabularyPageLayout.inset)
        .padding(.vertical, VocabularyPageLayout.topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(appearance.ink)
        .background(appearance.background.ignoresSafeArea())
        .fileImporter(isPresented: $importShown, allowedContentTypes: [.plainText, .commaSeparatedText, .tabSeparatedText, .json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    draft = try VocabularyImportDraft(data: Data(contentsOf: url), filename: url.lastPathComponent)
                } catch {
                    library.lastError = error.localizedDescription
                }
            case .failure(let error):
                library.lastError = error.localizedDescription
            }
        }
        .sheet(item: $draft) { draft in
            VocabularyImportReview(draft: draft, existing: [], onConfirm: { words in
                guard !words.isEmpty else { return "没有可导入的词条。" }
                guard let id = library.createDeck(title: words.first?.deckTitle ?? draft.deckTitle, in: [], words: words) else {
                    return library.lastError ?? "导入失败。"
                }
                position.search = ""
                position.customDeckID = id
                return nil
            })
            .environment(\.studyAppearance, appearance)
        }
        .task {
            let catalog = await Task.detached(priority: .userInitiated) { ReadingVocabularyCatalog.entries }.value
            guard !Task.isCancelled else { return }
            entries = catalog ?? []
            failedToLoad = catalog == nil
            isLoading = false
        }
    }

    private var deckGrid: some View {
        ScrollView {
            LazyVGrid(columns: VocabularyPageLayout.columns, alignment: .leading, spacing: VocabularyPageLayout.spacing) {
                ForEach(ReadingVocabularySource.allCases, id: \.self) { deck in
                    let id = ReadingVocabularyCatalog.deckID(deck)
                    deckCard(deck.title, id: id) {
                        position.chapter = nil
                        position.cardID = id
                        position.wordID = nil
                        position.source = deck
                    }
                    .id(id)
                }
                ForEach(library.snapshot.decks) { deck in
                    deckCard(deck.title, id: deck.id) {
                        position.cardID = deck.id
                        position.wordID = nil
                        position.customDeckID = deck.id
                    }
                    .id(deck.id)
                }
            }
            .scrollTargetLayout()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 20)
        }
        .scrollPosition(id: $position.cardID)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func deckCard(_ title: String, id: String, open: @escaping () -> Void) -> some View {
        let count = library.readingWords(in: id).count
        let draft = LumaChoiceQuizProgress.draft(for: id)
        return VStack(alignment: .leading, spacing: 8) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 23, weight: .light))
                        .foregroundStyle(appearance.accent)
                        .accessibilityHidden(true)
                    Text(title)
                        .lumaFont(size: 16, weight: .semibold)
                        .foregroundStyle(appearance.ink)
                        .lineLimit(2)
                    Text(draft.map { "\($0.answeredCount) / \($0.questions.count)" } ?? "\(count) 词")
                        .lumaFont(size: 12, monospacedDigits: true)
                        .foregroundStyle(appearance.ink.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(StudyFluidPressStyle())
            .accessibilityHint("查看单词")

            Spacer(minLength: 0)
            Button {
                position.cardID = id
                onStart(id)
            } label: {
                Label(draft == nil ? "开始背词" : "继续背词", systemImage: "play.fill")
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 10, height: 28))
            .disabled(count == 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: VocabularyPageLayout.cardHeight, alignment: .leading)
        .background(appearance.secondaryGradient, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(appearance.line, lineWidth: 1).allowsHitTesting(false))
    }

    @ViewBuilder
    private func wordList(_ results: [ReadingVocabularyEntry], imported: [VocabularyWord]) -> some View {
        if results.isEmpty && imported.isEmpty {
            ContentUnavailableView("没有匹配的词条", systemImage: "magnifyingglass")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { entry in
                        VStack(spacing: 0) {
                            row(entry)
                            Divider().opacity(0.45)
                        }
                        .id(entry.id)
                    }
                    ForEach(imported) { word in
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            Text(word.word).lumaFont(size: 16, weight: .semibold)
                                .frame(minWidth: 145, idealWidth: 190, maxWidth: 210, alignment: .leading)
                            Text(word.definitionZH).lumaFont(size: 14)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .textSelection(.enabled)
                        .id(word.id)
                        Divider().opacity(0.45)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $position.wordID)
            .onChange(of: chapter) { _, _ in position.wordID = nil }
            .onChange(of: search) { _, _ in position.wordID = nil }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func row(_ entry: ReadingVocabularyEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.label)
                    .lumaFont(size: 16, weight: .semibold)
                if !entry.ipa.isEmpty {
                    Text(entry.ipa)
                        .lumaFont(size: 12)
                        .foregroundStyle(appearance.ink.opacity(0.65))
                }
                if let form = entry.form {
                    Text(entry.word == "criteria" ? "单数 \(form)" : "复数 \(form)")
                        .lumaFont(size: 11)
                        .foregroundStyle(appearance.ink.opacity(0.65))
                }
            }
            .frame(minWidth: 145, idealWidth: 190, maxWidth: 210, alignment: .leading)
            Text(entry.meaning)
                .lumaFont(size: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if source == nil || entry.chapter != nil {
                Text(entry.chapter.map { "L\($0) · \(entry.number)" } ?? entry.source.title)
                    .lumaFont(size: 11)
                    .monospacedDigit()
                    .foregroundStyle(appearance.ink.opacity(0.60))
            }
        }
        .padding(.vertical, 10)
        .textSelection(.enabled)
    }
}

struct ReadingWrongWordsView: View {
    @Environment(\.studyAppearance) private var appearance
    @ObservedObject var library: LumaChoiceLibrary
    let onReview: ([VocabularyWord]) -> Void

    @State private var deckID = ""
    @State private var search = ""
    @State private var dueOnly = false
    @State private var alphabetical = false

    var body: some View {
        let all = library.readingWrongWords
        let deckIDs = Set(all.map(\.deckID))
        let decks = library.readingDecks.filter { deckIDs.contains($0.id) }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let visible = all.filter {
            (deckID.isEmpty || !deckIDs.contains(deckID) || $0.deckID == deckID) &&
                (!dueOnly || library.isReadingReviewDue($0.id, at: now)) &&
                (query.isEmpty || $0.word.localizedStandardContains(query) || $0.definitionZH.localizedStandardContains(query))
        }.sorted {
            let left = library.isReadingReviewDue($0.id, at: now)
            let right = library.isReadingReviewDue($1.id, at: now)
            if left != right { return left }
            if alphabetical { return $0.word.localizedStandardCompare($1.word) == .orderedAscending }
            let misses = library.snapshot.readingMisses ?? [:]
            let lhs = misses[$0.id, default: 0]
            let rhs = misses[$1.id, default: 0]
            return lhs == rhs ? $0.word.localizedStandardCompare($1.word) == .orderedAscending : lhs > rhs
        }
        let due = visible.filter { library.isReadingReviewDue($0.id, at: now) }

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("阅读错词").lumaFont(size: 28, weight: .bold, design: .serif)
                Text("\(visible.count) 词").lumaFont(size: 12).foregroundStyle(appearance.ink.opacity(0.60))
                Spacer()
                if !due.isEmpty {
                    Button("开始复习") { onReview(due) }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 12, height: 32))
                }
                Menu {
                    Picker("词库", selection: $deckID) {
                        Text("全部词库").tag("")
                        ForEach(decks) { deck in Text(deck.title).tag(deck.id) }
                    }
                    Toggle("仅显示到期词", isOn: $dueOnly)
                    Toggle("按字母排序", isOn: $alphabetical)
                    Divider()
                    Button("复习当前列表") { onReview(visible) }.disabled(visible.isEmpty)
                } label: {
                    VocabularyPageMenuLabel()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .accessibilityLabel("错词筛选与操作")
            }
            StudySearchField("搜索错词", text: $search, width: 200)
            if let error = library.lastError {
                Text(error).foregroundStyle(.red)
            }
            if visible.isEmpty {
                ContentUnavailableView(all.isEmpty ? "还没有阅读错词" : "没有匹配的错词", systemImage: "list.bullet")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visible) { word in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(word.word).lumaFont(size: 16, weight: .semibold)
                                    .frame(minWidth: 145, idealWidth: 190, maxWidth: 210, alignment: .leading)
                                Text(word.definitionZH).lumaFont(size: 14)
                                Spacer()
                                if library.isReadingReviewDue(word.id, at: now) {
                                    Text("到期").lumaFont(size: 11).foregroundStyle(appearance.accent)
                                }
                                Text("\(library.snapshot.readingMisses?[word.id] ?? 0) 错")
                                    .lumaFont(size: 12).monospacedDigit()
                            }
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button("移出错词", role: .destructive) { library.removeReadingMiss(word.id) }
                            }
                            Divider().opacity(0.45)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(appearance.ink)
    }
}
