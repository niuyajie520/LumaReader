import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 独立窗口中的单元错题管理。仅撤销错题投影，不改动不可恢复的原始听写日志。
public struct DictationUnitWrongWindowView: View {
    @Binding public var snapshot: StudyStoreSnapshot
    public let words: [VocabularyWord]
    public let deckIDs: [String]
    public let deckTitle: String
    /// 本轮听写的起点：窗口只显示从这一刻起练出来的错题，重新进入/重新开始就自动清空。
    public let roundStartedAt: Date?
    /// Immutable identity of this practice round; timestamps alone mix other rounds and units.
    public let roundID: UUID?
    public let roundWordIDs: Set<String>?
    public let onChange: (StudyStoreSnapshot) -> Void

    @State private var selection = Set<String>()
    @State private var exportError: String?
    @Environment(\.studyAppearance) private var appearance

    public init(
        snapshot: Binding<StudyStoreSnapshot>,
        words: [VocabularyWord],
        deckIDs: [String],
        deckTitle: String,
        roundStartedAt: Date?,
        roundID: UUID? = nil,
        roundWordIDs: Set<String>? = nil,
        onChange: @escaping (StudyStoreSnapshot) -> Void
    ) {
        _snapshot = snapshot
        self.words = words
        self.deckIDs = deckIDs
        self.deckTitle = deckTitle
        self.roundStartedAt = roundStartedAt
        self.roundID = roundID
        self.roundWordIDs = roundWordIDs
        self.onChange = onChange
    }

    private struct Row: Identifiable {
        enum Kind { case attempt(DictationAttemptLog), meaning(String) }
        let id: String
        let word: String
        let meaning: String
        let kind: Kind
        let timestamp: Date?
        let typed: String?
    }

    private var rows: [Row] {
        let decks = Set(deckIDs)
        let wordByID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let suppressed = Set(snapshot.suppressedWrongLogIDs ?? [])
        let attempts = snapshot.dictationLogs.reversed().compactMap { log -> Row? in
            guard !log.isCorrect, decks.contains(log.deckID), !suppressed.contains(log.id),
                  wordByID[log.wordID] != nil,
                  roundWordIDs?.contains(log.wordID) ?? true else { return nil }
            // 同一词本可反复开新轮；只认本轮 sessionID，时间不是归属凭证。
            if let roundID {
                guard log.sessionID == roundID else { return nil }
            } else if let roundStartedAt, log.timestamp < roundStartedAt { return nil }
            return Row(id: "attempt:\(log.id.uuidString)", word: log.word,
                       meaning: wordByID[log.wordID]?.definitionZH ?? "", kind: .attempt(log),
                       timestamp: log.timestamp, typed: log.userTyped)
        }
        let meanings = Set(snapshot.roundMeaningWordIDs?[roundID?.uuidString ?? ""] ?? [])
        let sessionWordIDs: Set<String> = Set(snapshot.dictationLogs.filter { log in
            if let roundID { return log.sessionID == roundID && decks.contains(log.deckID) }
            return roundStartedAt.map { log.timestamp >= $0 && decks.contains(log.deckID) } ?? false
        }.map(\.wordID))
        let meaningRows = words.filter {
            decks.contains($0.deckID) && meanings.contains($0.id)
                && (roundWordIDs?.contains($0.id) ?? sessionWordIDs.contains($0.id))
        }
            .sorted { $0.word.localizedStandardCompare($1.word) == .orderedAscending }
            .map { word in
                Row(id: "meaning:\(word.id)", word: word.word, meaning: word.definitionZH,
                    kind: .meaning(word.id), timestamp: nil, typed: nil)
            }
        return attempts + meaningRows
    }

    private var selectedRows: [Row] { rows.filter { selection.contains($0.id) } }
    private var selectedAttemptIDs: Set<UUID> {
        Set(selectedRows.compactMap { if case .attempt(let log) = $0.kind { log.id } else { nil } })
    }
    private var selectedWordIDs: Set<String> {
        Set(selectedRows.map { row in
            switch row.kind {
            case .attempt(let log): return log.wordID
            case .meaning(let wordID): return wordID
            }
        })
    }
    private var selectedMeaningIDs: Set<String> {
        Set(selectedRows.compactMap { if case .meaning(let wordID) = $0.kind { wordID } else { nil } })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本轮错题").font(.title2.bold())
                    Text(deckTitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(rows.count) 条 · 已选 \(selectedRows.count) 条")
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }

            if rows.isEmpty {
                ContentUnavailableView("本轮暂无错题", systemImage: "checkmark.circle",
                                       description: Text("这一轮听写里打错的词和标记“意思不清”的词会出现在这里；重新开一轮会清空。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 用 ScrollView + LazyVStack 而不是 List：List 由 NSTableView 支撑，
                // 在独立窗口里出现过「标题显示 1 条、列表却空白」的情况，Stack 渲染稳定。
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            Button { toggleSelection(row.id) } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Image(systemName: selection.contains(row.id) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 13))
                                        .foregroundStyle(selection.contains(row.id) ? appearance.accent : .secondary)
                                        .frame(width: 20)
                                    Image(systemName: row.typed == nil ? "text.book.closed" : "xmark.circle")
                                        .foregroundStyle(row.typed == nil ? appearance.accent : .red)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 9) {
                                            Text(row.word).font(.headline)
                                            Text(row.typed == nil ? "意思不清" : "拼写错误")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        if !row.meaning.isEmpty {
                                            Text(row.meaning).font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    if let typed = row.typed {
                                        Text("输入：\(typed.isEmpty ? "（空）" : typed)")
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                            .frame(maxWidth: 210, alignment: .leading)
                                    }
                                    if let timestamp = row.timestamp {
                                        Text(timestamp, format: .dateTime.month().day().hour().minute())
                                            .font(.caption).foregroundStyle(.tertiary).monospacedDigit()
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 7)
                                .padding(.horizontal, 6)
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.25)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 10) {
                Button(selection.count == rows.count && !rows.isEmpty ? "取消全选" : "全选") {
                    if selection.count == rows.count { selection.removeAll() }
                    else { selection = Set(rows.map(\.id)) }
                }
                .disabled(rows.isEmpty)
                Spacer()
                Button("标记意思不清") { update { snapshot in
                    let key = roundID?.uuidString ?? ""
                    var marks = snapshot.roundMeaningWordIDs ?? [:]
                    marks[key] = Array(Set(marks[key] ?? []).union(selectedWordIDs)).sorted()
                    snapshot.roundMeaningWordIDs = marks
                } }
                .disabled(selectedWordIDs.isEmpty)
                Button("取消意思不清") { update { snapshot in
                    let key = roundID?.uuidString ?? ""
                    var marks = snapshot.roundMeaningWordIDs ?? [:]
                    marks[key] = Array(Set(marks[key] ?? []).subtracting(selectedMeaningIDs)).sorted()
                    snapshot.roundMeaningWordIDs = marks
                } }
                .disabled(selectedMeaningIDs.isEmpty)
                Button("撤销所选错误") { update { $0.suppressWrongLogs(selectedAttemptIDs) } }
                    .disabled(selectedAttemptIDs.isEmpty)
                Menu("导出") {
                    Button("导出所选…") { export(selectedRows) }.disabled(selectedRows.isEmpty)
                    Button("导出本单元…") { export(rows) }.disabled(rows.isEmpty)
                }
            }
            .buttonStyle(.bordered)
            Text("只显示本轮听写的错题；重新开始一轮后这里会清空。撤销只把该次错误移出错题统计，原始练习记录仍保留。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(minWidth: 720, minHeight: 440)
        .background(appearance.paper)
        .foregroundStyle(appearance.ink)
        .tint(appearance.accent)
        .alert("导出失败", isPresented: Binding(get: { exportError != nil },
                                          set: { if !$0 { exportError = nil } })) {
            Button("好") { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private func toggleSelection(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func update(_ change: (inout StudyStoreSnapshot) -> Void) {
        var updated = snapshot
        change(&updated)
        snapshot = updated
        onChange(updated)
        selection.formIntersection(Set(rows.map(\.id)))
    }

    private func export(_ exported: [Row]) {
        guard !exported.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "LumaReader-本轮错题.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        func field(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let lines = exported.map { row -> String in
            let kind = row.typed == nil ? "意思不清" : "拼写错误"
            let date = row.timestamp.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            return [row.word, row.meaning, kind, row.typed ?? "", date].map(field).joined(separator: ",")
        }
        let csv = "\u{FEFF}单词,释义,类型,实际输入,发生时间\r\n" + lines.joined(separator: "\r\n") + "\r\n"
        do { try csv.write(to: url, atomically: true, encoding: .utf8) }
        catch { exportError = error.localizedDescription }
    }
}
