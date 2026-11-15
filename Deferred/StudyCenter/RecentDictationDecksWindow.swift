import SwiftUI

/// 「最近听的」独立窗口：按最近练习时间倒序列出**词本 / 单元**，
/// 不用一个个去翻听力列表找自己刚才在听哪个。
///
/// 点一行就直接切到那个单元继续听；这里不修改任何练习数据。
public struct RecentDictationDecksView: View {
    public struct Entry: Identifiable {
        public let id: String
        public let title: String
        public let lastPracticed: Date
        public let attempts: Int
        public let completed: Int
        public let total: Int
        public let wrongCount: Int
    }

    @Binding private var snapshot: StudyStoreSnapshot
    private let words: [VocabularyWord]
    private let titleFor: (String) -> String
    private let currentDeckID: String
    private let onPick: (String) -> Void

    @State private var search: String = ""

    public init(
        snapshot: Binding<StudyStoreSnapshot>,
        words: [VocabularyWord],
        currentDeckID: String,
        titleFor: @escaping (String) -> String,
        onPick: @escaping (String) -> Void
    ) {
        self._snapshot = snapshot
        self.words = words
        self.currentDeckID = currentDeckID
        self.titleFor = titleFor
        self.onPick = onPick
    }

    private var entries: [Entry] {
        var lastSeen: [String: Date] = [:]
        var rounds: [String: Set<UUID>] = [:]
        for log in snapshot.dictationLogs {
            lastSeen[log.deckID] = max(lastSeen[log.deckID] ?? .distantPast, log.timestamp)
            rounds[log.deckID, default: []].insert(log.sessionID)
        }
        var wordsByDeck: [String: [VocabularyWord]] = [:]
        for word in words {
            wordsByDeck[word.deckID, default: []].append(word)
        }
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let suppressed = Set(snapshot.suppressedWrongLogIDs ?? [])
        var wrongByDeck: [String: Set<String>] = [:]
        for log in snapshot.effectiveWrongLogs where !suppressed.contains(log.id) {
            wrongByDeck[log.deckID, default: []].insert(log.wordID)
        }
        let completedByDeck = Dictionary(grouping: snapshot.dictationLogs.filter { $0.isCorrect }, by: \.deckID)
            .mapValues { logs in Set(logs.map(\.wordID)).count }

        return wordsByDeck.keys
            .map { deck -> Entry in
                let deckWords = wordsByDeck[deck] ?? []
                let completed = completedByDeck[deck] ?? 0
                return Entry(
                    id: deck,
                    title: titleFor(deck),
                    lastPracticed: lastSeen[deck] ?? .distantPast,
                    attempts: rounds[deck]?.count ?? 0,
                    completed: min(completed, max(deckWords.count, completed)),
                    total: deckWords.count,
                    wrongCount: wrongByDeck[deck]?.count ?? 0
                )
            }
            .filter { $0.attempts > 0 }
            .filter { keyword.isEmpty || $0.title.lowercased().contains(keyword) }
            .sorted { $0.lastPracticed > $1.lastPracticed }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("最近听的").font(.system(size: 19, weight: .semibold))
                    Spacer()
                    Text("\(entries.count) 个词本")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("按最近练习时间倒序；点一行就切到那个单元继续听。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("搜索词本 / 单元名称", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.06)))
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            if entries.isEmpty {
                ContentUnavailableView(
                    "还没有听写记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("听过几个单元之后，这里会按最近时间列出来。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    row(entry)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 660, minHeight: 420)
    }

    private func row(_ entry: Entry) -> some View {
        let isCurrent = entry.id == currentDeckID
        return Button {
            onPick(entry.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isCurrent ? "headphones.circle.fill" : "headphones")
                    .font(.system(size: 15))
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        if isCurrent {
                            Text("正在听")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        if entry.wrongCount > 0 {
                            Text("\(entry.wrongCount) 错词")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.red.opacity(0.85))
                        }
                    }
                    Text("已完成 \(entry.completed)/\(max(entry.total, entry.completed)) · \(entry.attempts) 次练习")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(entry.lastPracticed.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}
