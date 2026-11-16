import SwiftUI

/// 词库：词本列表 → 词条列表 → 词条详情。
struct VocabularyHomeView: View {
    @Environment(StudyStore.self) private var store
    @State private var query = ""
    @State private var importing = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.decks.isEmpty {
                    emptyState
                } else if query.isEmpty {
                    deckList
                } else {
                    searchResults
                }
            }
            .navigationTitle("词库")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索单词或释义")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                        .accessibilityLabel("导入词表")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText], allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .overlay(alignment: .bottom) {
                if let importMessage {
                    Text(importMessage)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.lumaSurface, in: Capsule())
                        .padding(.bottom, 12)
                        .task(id: importMessage) {
                            try? await Task.sleep(nanoseconds: 2_600_000_000)
                            self.importMessage = nil
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有词本", systemImage: "square.stack.3d.up")
        } description: {
            Text("阅读时把生词加进来，或导入一份词表。")
        } actions: {
            Button("导入词表") { importing = true }
                .buttonStyle(LumaPrimaryButtonStyle())
        }
        .background(Color.lumaPaper)
    }

    private var deckList: some View {
        List {
            Section {
                ForEach(store.decks) { deck in
                    NavigationLink {
                        DeckDetailView(deck: deck)
                    } label: {
                        deckRow(deck)
                    }
                }
            } header: {
                Text("共 \(store.words.count) 个条目")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deckRow(_ deck: VocabularyDeck) -> some View {
        let due = deck.words.filter { WordReviewOrdering.isDueForNextDayRecall(store.progress(for: $0.id)) }.count
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.title).font(.body.weight(.medium)).lineLimit(1)
                Text("\(deck.count) 个条目").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if due > 0 {
                Text("\(due) 到期")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.lumaWarning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lumaWarning.opacity(0.12), in: Capsule())
            }
            if store.activeDeck?.id == deck.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lumaAccent)
            }
        }
        .contentShape(Rectangle())
    }

    private var searchResults: some View {
        let hits = store.words.filter {
            $0.word.localizedCaseInsensitiveContains(query) || $0.definitionZH.localizedCaseInsensitiveContains(query)
        }
        return List {
            Section {
                ForEach(hits.prefix(200)) { word in
                    NavigationLink { WordDetailView(word: word) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.word).font(.body)
                            Text(word.shortDefinition).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            } header: {
                Text("匹配 \(hits.count) 个")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = "导入失败：\(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "读不到这个文件。"
                return
            }
            let deckTitle = url.deletingPathExtension().lastPathComponent
            let imported = WordListImporter.words(from: data, deckTitle: deckTitle)
            guard !imported.isEmpty else {
                importMessage = "这个文件里没有可用的词条。"
                return
            }
            var existing = store.words
            let known = Set(existing.map(\.id))
            existing.append(contentsOf: imported.filter { !known.contains($0.id) })
            store.replaceWords(existing)
            importMessage = "已导入 \(imported.count) 个条目"
        }
    }
}

// MARK: - 词本详情

struct DeckDetailView: View {
    @Environment(StudyStore.self) private var store
    let deck: VocabularyDeck
    @State private var query = ""

    var body: some View {
        let words = query.isEmpty ? deck.words : deck.words.filter {
            $0.word.localizedCaseInsensitiveContains(query) || $0.definitionZH.localizedCaseInsensitiveContains(query)
        }
        List {
            Section {
                Button {
                    store.select(deckID: deck.id)
                } label: {
                    Label(store.activeDeck?.id == deck.id ? "当前听写词本" : "设为当前听写词本",
                          systemImage: store.activeDeck?.id == deck.id ? "checkmark.circle.fill" : "circle")
                }
                .disabled(store.activeDeck?.id == deck.id)
            }
            Section {
                ForEach(words) { word in
                    NavigationLink { WordDetailView(word: word) } label: { row(word) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.replaceWords(store.words.filter { $0.id != word.id })
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text(query.isEmpty ? "\(words.count) 个条目" : "匹配 \(words.count) 个")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "在这个词本里搜索")
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ word: VocabularyWord) -> some View {
        let stage = store.progress(for: word.id)?.stage ?? 0
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word).font(.body)
                Text(word.shortDefinition).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if stage > 0 {
                Text("第 \(stage) 档")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - 词条详情

struct WordDetailView: View {
    @Environment(StudyStore.self) private var store
    @Environment(SpeechService.self) private var speech
    let word: VocabularyWord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.word).font(.system(size: 30, weight: .semibold, design: .rounded))
                        .textSelection(.enabled)
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }

                Button {
                    speech.accent = store.speechAccent
                    speech.rate = store.speechRate
                    speech.speak(word.word)
                } label: {
                    Label("朗读", systemImage: "speaker.wave.2")
                }
                .buttonStyle(LumaSecondaryButtonStyle())

                VStack(alignment: .leading, spacing: 8) {
                    Text("释义").font(.subheadline.weight(.semibold))
                    Text(word.definitionZH.isEmpty ? "还没有释义。" : word.definitionZH)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !word.exampleSentence.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("出处").font(.subheadline.weight(.semibold))
                        Text(word.exampleSentence).font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                progressCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.lumaPaper)
        .navigationTitle(word.deckTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressCard: some View {
        let progress = store.progress(for: word.id)
        return VStack(alignment: .leading, spacing: 8) {
            Text("复习进度").font(.subheadline.weight(.semibold))
            if let progress {
                LabeledContent("档位", value: "第 \(progress.stage) 档")
                LabeledContent("下次复习", value: dueText(progress.dueAt))
                LabeledContent("漏答次数", value: "\(progress.lapses) 次")
            } else {
                Text("还没开始练。").font(.callout).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lumaSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dueText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        if date <= Date() { return "今天" }
        return formatter.string(from: date)
    }
}

// MARK: - 词表导入

enum WordListImporter {
    /// 支持三种输入：本 App 的 JSON 数组、macOS 的整份 store、一行一个词的文本。
    static func words(from data: Data, deckTitle: String) -> [VocabularyWord] {
        if let snapshot = StudyStore.decodeSnapshot(data), !snapshot.words.isEmpty {
            return snapshot.words
        }
        if let object = try? JSONSerialization.jsonObject(with: data) {
            if let list = object as? [[String: Any]] {
                return list.enumerated().compactMap { index, entry -> VocabularyWord? in
                    let rawWord: String = (entry["word"] as? String) ?? (entry["label"] as? String) ?? ""
                    guard !rawWord.isEmpty else { return nil }
                    let rawID: String = (entry["id"] as? String) ?? "ios.import.\(abs(rawWord.hashValue))_\(index)"
                    let meaning: String = (entry["definitionZH"] as? String) ?? (entry["meaning"] as? String) ?? ""
                    let phonetic: String = (entry["phoneticUS"] as? String) ?? (entry["ipa"] as? String) ?? ""
                    let deck: String = (entry["deckID"] as? String) ?? "ios.import.\(deckTitle)"
                    let title: String = (entry["deckTitle"] as? String) ?? deckTitle
                    return VocabularyWord(
                        id: rawID,
                        word: rawWord,
                        phoneticUS: phonetic,
                        definitionZH: meaning,
                        deckID: deck,
                        deckTitle: title
                    )
                }
            }
        }
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let deckID = "ios.import.\(deckTitle)"
        return text.split(whereSeparator: \.isNewline).enumerated().compactMap { index, line in
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            let head = parts[0].trimmingCharacters(in: .whitespaces)
            let definition = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            guard !head.isEmpty, head.rangeOfCharacter(from: .letters) != nil else { return nil }
            return VocabularyWord(id: "\(deckID).\(index)", word: head, definitionZH: definition,
                                  deckID: deckID, deckTitle: deckTitle)
        }
    }
}
