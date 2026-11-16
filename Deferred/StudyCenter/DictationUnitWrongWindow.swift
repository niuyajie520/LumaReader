import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 「本轮错题」的按词归并（纯函数，不依赖界面，便于测试）。
public enum DictationWrongLogGrouping {
    public struct Group: Equatable, Sendable {
        public let wordID: String
        public let count: Int
        public let latest: DictationAttemptLog
        public let logs: [DictationAttemptLog]
    }

    /// 输入按时间倒序（新的在前），输出保持单词首次出现的顺序。
    public static func groups(_ newestFirst: [DictationAttemptLog]) -> [Group] {
        var order: [String] = []
        var grouped: [String: [DictationAttemptLog]] = [:]
        for log in newestFirst {
            if grouped[log.wordID] == nil { order.append(log.wordID) }
            grouped[log.wordID, default: []].append(log)
        }
        return order.compactMap { wordID in
            guard let logs = grouped[wordID], let latest = logs.first else { return nil }
            return Group(wordID: wordID, count: logs.count, latest: latest, logs: logs)
        }
    }
}

/// 独立窗口中的单元错题管理。仅撤销错题投影，不改动不可恢复的原始听写日志。
public struct DictationUnitWrongWindowView: View {
    @Binding public var snapshot: StudyStoreSnapshot
    public let words: [VocabularyWord]
    public let deckIDs: [String]
    public let deckTitle: String
    /// 本轮 = 词本 + 轮次 ID。时间戳不是归属凭证（v4 硬约束 2.4C）。
    public let roundID: UUID
    public let roundWordIDs: Set<String>?
    public let onChange: (StudyStoreSnapshot) -> Void

    @State private var selection = Set<String>()
    @State private var exportError: String?
    /// 搜索框：按单词 / 释义 / 输入内容过滤，只影响显示，不改统计。
    @State private var query = ""
    @Environment(\.studyAppearance) private var appearance

    public init(
        snapshot: Binding<StudyStoreSnapshot>,
        words: [VocabularyWord],
        deckIDs: [String],
        deckTitle: String,
        roundID: UUID,
        roundWordIDs: Set<String>? = nil,
        onChange: @escaping (StudyStoreSnapshot) -> Void
    ) {
        _snapshot = snapshot
        self.words = words
        self.deckIDs = deckIDs
        self.deckTitle = deckTitle
        self.roundID = roundID
        self.roundWordIDs = roundWordIDs
        self.onChange = onChange
    }

    private struct Row: Identifiable {
        enum Kind { case attempt(wordID: String, logIDs: [UUID]), meaning(String) }
        let id: String
        let word: String
        let meaning: String
        let kind: Kind
        let timestamp: Date?
        let typed: String?
        /// 同一个词在同一轮里错几次都只占一行，次数写在旁边。
        let count: Int
        /// 该词在本次统计里的全部错误输入（新的在前），用于悬停提示。
        let typedHistory: [String]

        init(id: String, word: String, meaning: String, kind: Kind,
             timestamp: Date?, typed: String?, count: Int = 1, typedHistory: [String] = []) {
            self.id = id
            self.word = word
            self.meaning = meaning
            self.kind = kind
            self.timestamp = timestamp
            self.typed = typed
            self.count = count
            self.typedHistory = typedHistory
        }
    }

    private var scope: RoundScope { RoundScope(deckIDs: deckIDs, roundID: roundID) }

    /// 按词归并：一个词在本轮错 10 次也只有一行（不显示次数）。
    private var rows: [Row] {
        let scope = self.scope
        let wordByID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let suppressed = Set(snapshot.suppressedWrongLogIDs ?? [])
        let wrongLogs = snapshot.dictationLogs.reversed().filter { log in
            !log.isCorrect && scope.contains(log) && !suppressed.contains(log.id)
                && wordByID[log.wordID] != nil
                && (roundWordIDs?.contains(log.wordID) ?? true)
        }
        let attempts = DictationWrongLogGrouping.groups(wrongLogs).compactMap { group -> Row? in
            guard let word = wordByID[group.wordID] else { return nil }
            return Row(id: "word:\(group.wordID)", word: group.latest.word,
                       meaning: word.definitionZH,
                       kind: .attempt(wordID: group.wordID, logIDs: group.logs.map(\.id)),
                       timestamp: group.latest.timestamp, typed: group.latest.userTyped,
                       count: group.count,
                       typedHistory: group.logs.map { $0.userTyped })
        }
        let meanings = scope.meaningWordIDs(in: snapshot)
        let sessionWordIDs = scope.wordIDs(in: snapshot.dictationLogs)
        let meaningRows = words.filter {
            scope.deckIDs.contains($0.deckID) && meanings.contains($0.id)
                && (roundWordIDs?.contains($0.id) ?? sessionWordIDs.contains($0.id))
        }
            .sorted { $0.word.localizedStandardCompare($1.word) == .orderedAscending }
            .map { word in
                Row(id: "meaning:\(word.id)", word: word.word, meaning: word.definitionZH,
                    kind: .meaning(word.id), timestamp: nil, typed: nil)
            }
        return attempts + meaningRows
    }

    /// 标题行小结：只报「几个词」——一个词错几次都只算一个词，不再显示错误次数。
    private func summaryLine(shown: Int) -> String {
        "\(shown) 个词 · 已选 \(selectedRows.count)"
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var visibleRows: [Row] {
        let needle = trimmedQuery
        guard !needle.isEmpty else { return rows }
        return rows.filter { row in
            row.word.localizedCaseInsensitiveContains(needle)
                || row.meaning.localizedCaseInsensitiveContains(needle)
                || row.typedHistory.contains { $0.localizedCaseInsensitiveContains(needle) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("搜索单词、释义或写错的内容", text: $query)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .disableAutocorrection(true)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(appearance.ink.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(appearance.ink.opacity(0.10), lineWidth: 1))
    }

    private var selectedRows: [Row] { rows.filter { selection.contains($0.id) } }
    private var selectedAttemptIDs: Set<UUID> {
        Set(selectedRows.flatMap { row -> [UUID] in
            if case .attempt(_, let logIDs) = row.kind { return logIDs } else { return [] }
        })
    }
    private var selectedWordIDs: Set<String> {
        Set(selectedRows.map { row in
            switch row.kind {
            case .attempt(let wordID, _): return wordID
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
                    Text("\(deckTitle) · 本轮").font(.title2.bold())
                    Text("本轮错题").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(trimmedQuery.isEmpty
                     ? summaryLine(shown: rows.count)
                     : "匹配 \(visibleRows.count) / \(rows.count) 个词 · 已选 \(selectedRows.count)")
                    .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }

            searchField

            if rows.isEmpty {
                ContentUnavailableView("本轮还没有错题", systemImage: "checkmark.circle",
                                       description: Text("本轮打错的词和标记「意思不清」的词会出现在这里。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleRows.isEmpty {
                ContentUnavailableView("没有匹配的错题", systemImage: "magnifyingglass",
                                       description: Text("换个关键词，或者清空搜索框看全部 \(rows.count) 条。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 用 ScrollView + LazyVStack 而不是 List：List 由 NSTableView 支撑，
                // 在独立窗口里出现过「标题显示 1 条、列表却空白」的情况，Stack 渲染稳定。
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleRows) { row in
                            Button { toggleSelection(row.id) } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Image(systemName: selection.contains(row.id) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 13))
                                        .foregroundStyle(selection.contains(row.id) ? appearance.accent : .secondary)
                                        .frame(width: 20)
                                    Image(systemName: row.typed == nil ? "questionmark.circle" : "xmark.circle")
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
                                        Text("\(row.count > 1 ? "最近输入" : "输入")：\(typed.isEmpty ? "（空）" : typed)")
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                            .frame(maxWidth: 210, alignment: .leading)
                                            .help(row.typedHistory.joined(separator: "\n"))
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

            // 空的时候只显示空态，不出现一排灰按钮。
            if !rows.isEmpty {
            HStack(spacing: 10) {
                Button(visibleRows.isEmpty || selection.isSuperset(of: Set(visibleRows.map(\.id))) ? "取消全选" : "全选") {
                    if !visibleRows.isEmpty && selection.isSuperset(of: Set(visibleRows.map(\.id))) { selection.removeAll() }
                    else { selection = Set(visibleRows.map(\.id)) }
                }
                .disabled(visibleRows.isEmpty)
                Spacer()
                Button("标记意思不清") { update { snapshot in
                    let key = roundID.uuidString
                    var marks = snapshot.roundMeaningWordIDs ?? [:]
                    marks[key] = Array(Set(marks[key] ?? []).union(selectedWordIDs)).sorted()
                    snapshot.roundMeaningWordIDs = marks
                } }
                .disabled(selectedWordIDs.isEmpty)
                Button("取消意思不清") { update { snapshot in
                    let key = roundID.uuidString
                    var marks = snapshot.roundMeaningWordIDs ?? [:]
                    marks[key] = Array(Set(marks[key] ?? []).subtracting(selectedMeaningIDs)).sorted()
                    snapshot.roundMeaningWordIDs = marks
                } }
                .disabled(selectedMeaningIDs.isEmpty)
                Button("撤销所选错误") { update { $0.suppressWrongLogs(selectedAttemptIDs) } }
                    .disabled(selectedAttemptIDs.isEmpty)
                Menu("导出") {
                    Button("导出所选…") { export(selectedRows) }.disabled(selectedRows.isEmpty)
                    Button("导出当前列表…") { export(visibleRows) }.disabled(visibleRows.isEmpty)
                    Button("导出本单元全部…") { export(rows) }.disabled(rows.isEmpty)
                }
            }
            .buttonStyle(LumaButtonStyle(.secondary, size: .regular))
            Text("撤销只把该次错误移出错题统计，原始练习记录仍保留。")
                .font(.caption).foregroundStyle(.secondary)
            }
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
            return [row.word, row.meaning, kind, String(row.count), row.typed ?? "",
                    row.typedHistory.joined(separator: " | "), date].map(field).joined(separator: ",")
        }
        let csv = "\u{FEFF}单词,释义,类型,错误次数,最近输入,全部输入,发生时间\r\n" + lines.joined(separator: "\r\n") + "\r\n"
        do { try csv.write(to: url, atomically: true, encoding: .utf8) }
        catch { exportError = error.localizedDescription }
    }
}
