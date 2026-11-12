import SwiftUI

// MARK: - Wrong Words Center model (presentation only)

public enum WrongWordMastery: String, Equatable, Sendable {
    case fresh, reviewing, mastered

    public var title: String {
        switch self {
        case .fresh: return "未复习"
        case .reviewing: return "复习中"
        case .mastered: return "已掌握"
        }
    }
}

public struct WrongWordEntry: Identifiable, Equatable, Sendable {
    public var id: String { wordID }
    public let wordID: String
    public let word: String
    public let meaning: String
    public let deckID: String
    public let deckTitle: String
    public let errorCount: Int
    public let dueAt: Date?
    public let lastAttemptAt: Date?
    public let lastReactionSeconds: Double?
    public let isDue: Bool
    public let isSlowReaction: Bool
    public let isStubborn: Bool
    public let mastery: WrongWordMastery

    public init(wordID: String, word: String, meaning: String, deckID: String, deckTitle: String,
                errorCount: Int, dueAt: Date?, lastReactionSeconds: Double?, isDue: Bool,
                isSlowReaction: Bool, isStubborn: Bool, lastAttemptAt: Date? = nil,
                mastery: WrongWordMastery = .fresh) {
        self.wordID = wordID
        self.word = word
        self.meaning = meaning
        self.deckID = deckID
        self.deckTitle = deckTitle
        self.errorCount = errorCount
        self.dueAt = dueAt
        self.lastAttemptAt = lastAttemptAt
        self.lastReactionSeconds = lastReactionSeconds
        self.isDue = isDue
        self.isSlowReaction = isSlowReaction
        self.isStubborn = isStubborn
        self.mastery = mastery
    }
}

public struct WrongWordDiagnosis: Identifiable, Equatable, Sendable {
    public var id: String { label }
    public let label: String
    public let count: Int
    public let wordIDs: [String]
    public init(label: String, count: Int, wordIDs: [String]) {
        self.label = label
        self.count = count
        self.wordIDs = wordIDs
    }
}

public struct WrongWordPracticeRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let word: String
    public let typed: String
    public let isCorrect: Bool
    public let date: Date
    public let durationSeconds: Double
    public let deckTitle: String
    public let isSlowReaction: Bool

    public init(id: UUID, word: String, typed: String, isCorrect: Bool, date: Date,
                durationSeconds: Double, deckTitle: String, isSlowReaction: Bool) {
        self.id = id
        self.word = word
        self.typed = typed
        self.isCorrect = isCorrect
        self.date = date
        self.durationSeconds = durationSeconds
        self.deckTitle = deckTitle
        self.isSlowReaction = isSlowReaction
    }
}

public struct WrongWordDayPoint: Identifiable, Equatable, Sendable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let attempts: Int
    public let correct: Int
    public let errors: Int
    public var accuracy: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }

    public init(key: String, label: String, attempts: Int, correct: Int, errors: Int) {
        self.key = key
        self.label = label
        self.attempts = attempts
        self.correct = correct
        self.errors = errors
    }
}

public struct WrongWordDeckGroup: Identifiable, Equatable, Sendable {
    public var id: String { deckID }
    public let deckID: String
    public let title: String
    public let entries: [WrongWordEntry]
    public let dueCount: Int
    public let totalErrors: Int

    public init(deckID: String, title: String, entries: [WrongWordEntry]) {
        self.deckID = deckID
        self.title = title
        self.entries = entries
        self.dueCount = entries.reduce(0) { $0 + ($1.isDue ? 1 : 0) }
        self.totalErrors = entries.reduce(0) { $0 + $1.errorCount }
    }
}

public struct WrongWordsCenterModel: Equatable, Sendable {
    public let groups: [WrongWordDeckGroup]
    public let totalWords: Int
    public let dueWords: Int
    public let totalErrors: Int
    public let todayErrors: Int
    public let slowCount: Int
    public let stubbornCount: Int
    public let reviewedWords: Int
    public let masteredCount: Int
    public let records: [WrongWordPracticeRecord]
    public let days: [WrongWordDayPoint]
    public let last7Accuracy: Double
    public let last7Errors: Int
    public let diagnoses: [WrongWordDiagnosis]

    public init(groups: [WrongWordDeckGroup], totalWords: Int, dueWords: Int, totalErrors: Int,
                todayErrors: Int, slowCount: Int, stubbornCount: Int, reviewedWords: Int,
                masteredCount: Int = 0, records: [WrongWordPracticeRecord] = [],
                days: [WrongWordDayPoint] = [], last7Accuracy: Double = 0, last7Errors: Int = 0,
                diagnoses: [WrongWordDiagnosis] = []) {
        self.groups = groups
        self.totalWords = totalWords
        self.dueWords = dueWords
        self.totalErrors = totalErrors
        self.todayErrors = todayErrors
        self.slowCount = slowCount
        self.stubbornCount = stubbornCount
        self.reviewedWords = reviewedWords
        self.masteredCount = masteredCount
        self.records = records
        self.days = days
        self.last7Accuracy = last7Accuracy
        self.last7Errors = last7Errors
        self.diagnoses = diagnoses
    }

    public static let empty = WrongWordsCenterModel(groups: [], totalWords: 0, dueWords: 0,
                                                    totalErrors: 0, todayErrors: 0, slowCount: 0,
                                                    stubbornCount: 0, reviewedWords: 0)
    public var isEmpty: Bool { totalWords == 0 }
    public var reviewProgress: Double {
        totalWords == 0 ? 0 : min(1, max(0, Double(reviewedWords) / Double(totalWords)))
    }
    public var allEntries: [WrongWordEntry] { groups.flatMap(\.entries) }
}

// MARK: - Filters & sort

public enum WrongWordsFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "全部错词"
    case due = "今日待复习"
    case highFrequency = "高频错词"
    case stubborn = "顽固单词"
    case slow = "慢反应"
    case records = "练习记录"
    public var id: String { rawValue }
    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .due: return "clock.badge.exclamationmark"
        case .highFrequency: return "flame"
        case .stubborn: return "exclamationmark.triangle"
        case .slow: return "tortoise"
        case .records: return "clock.arrow.circlepath"
        }
    }
}

public enum WrongWordsSort: String, CaseIterable, Identifiable, Sendable {
    case errors = "错误最多"
    case recent = "最近练习"
    case due = "最快到期"
    case alphabetical = "字母顺序"
    public var id: String { rawValue }
}

// MARK: - View

public struct WrongWordsCenterView: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaDynamicMotion) private var dynamicMotion

    private let model: WrongWordsCenterModel
    private let onStartDue: (String) -> Void
    private let onStartAll: (String) -> Void
    private let onStartSlow: () -> Void
    private let onStartStubborn: () -> Void
    private let onStartMixed: () -> Void
    private let onRemoveSlow: (String) -> Void
    private let onSpeak: (String) -> Void
    private let onGoToDictation: () -> Void
    private let onExportRecords: () -> Void
    private let onStartTodayQueue: () -> Void
    private let onStartAllWrongWords: () -> Void
    private let onStartMicroDrill: ([String]) -> Void
    private let renderMode: Bool

    @State private var query = ""
    @State private var filter: WrongWordsFilter = .all
    @State private var sort: WrongWordsSort = .errors
    @State private var deckFilter = "全部词库"
    @State private var selectedEntryID: String?
    @State private var showDecks = false
    @State private var showDetails = false
    @State private var showAnalysis = false
    @State private var searchExpanded = false
    @State private var listExpanded = false
    @State private var listVisible = true
    @FocusState private var searchFocused: Bool

    public init(model: WrongWordsCenterModel,
                onStartDue: @escaping (String) -> Void,
                onStartAll: @escaping (String) -> Void,
                onStartSlow: @escaping () -> Void,
                onStartStubborn: @escaping () -> Void,
                onStartMixed: @escaping () -> Void,
                onRemoveSlow: @escaping (String) -> Void,
                onSpeak: @escaping (String) -> Void,
                onGoToDictation: @escaping () -> Void,
                onExportRecords: @escaping () -> Void = {},
                onStartTodayQueue: @escaping () -> Void = {},
                onStartAllWrongWords: @escaping () -> Void = {},
                onStartMicroDrill: @escaping ([String]) -> Void = { _ in },
                renderMode: Bool = false) {
        self.model = model
        self.onStartDue = onStartDue
        self.onStartAll = onStartAll
        self.onStartSlow = onStartSlow
        self.onStartStubborn = onStartStubborn
        self.onStartMixed = onStartMixed
        self.onRemoveSlow = onRemoveSlow
        self.onSpeak = onSpeak
        self.onGoToDictation = onGoToDictation
        self.onExportRecords = onExportRecords
        self.onStartTodayQueue = onStartTodayQueue
        self.onStartAllWrongWords = onStartAllWrongWords
        self.onStartMicroDrill = onStartMicroDrill
        self.renderMode = renderMode
    }

    private var ink: Color { appearance.ink }
    private var accent: Color { appearance.accent }
    private var surface: Color { appearance.surface }
    private func semanticTint(_ color: Color) -> Color {
        appearance.visualThemeSystem == "monet" ? color : accent
    }
    private var animated: Bool { !reduceMotion && dynamicMotion }

    public var body: some View {
        Group {
            if renderMode {
                pageContent(wide: true).frame(width: 1180, height: 900, alignment: .topLeading)
            } else {
                GeometryReader { proxy in
                    ScrollView {
                        pageContent(wide: proxy.size.width >= 1120)
                    }
                    .scrollIndicators(.never)
                }
            }
        }
        .background(appearance.background.ignoresSafeArea())
        .onChange(of: model) { _, newValue in
            if deckFilter != "全部词库", !newValue.groups.contains(where: { $0.title == deckFilter }) {
                deckFilter = "全部词库"
            }
        }
    }

    private func pageContent(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            overview(wide: wide)
            if wide && !showDetails { deckPanel }
            if wide {
                HStack(alignment: .top, spacing: 16) {
                    mainColumn(wide: wide)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                    if showDetails {
                        sideColumn(includeDeckPanel: true)
                            .frame(width: 260, alignment: .top)
                    }
                }
            } else {
                deckPanel
                mainColumn(wide: false)
                if showDetails { sideColumn(includeDeckPanel: false) }
            }
        }
        .padding(.horizontal, wide ? 32 : 20)
        .padding(.top, 14)
        .padding(.bottom, 34)
        .frame(maxWidth: 1240, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Header

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                headerHeading
                Spacer(minLength: 8)
                headerActions
            }
            VStack(alignment: .leading, spacing: 12) {
                headerHeading
                headerActions
            }
        }
    }

    private var headerHeading: some View {
        Label("错词中心", systemImage: "checklist.unchecked")
            .lumaFont(size: 25, weight: .bold, design: .serif)
            .foregroundStyle(ink)
            .fixedSize()
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                if let deck = preferredDeck() { onStartDue(deck) }
            } label: {
                Label(model.dueWords > 0 ? "到期复习 \(model.dueWords)" : "暂无到期错词", systemImage: "play.fill")
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: model.dueWords > 0, horizontalPadding: 13, height: 32))
            .disabled(model.dueWords == 0)

            Button {
                onStartAllWrongWords()
            } label: {
                Label("全部错词听写 \(model.totalWords)", systemImage: "text.badge.xmark")
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: false, horizontalPadding: 12, height: 32))
            .disabled(model.totalWords == 0)
            .help("把错词本里的全部 \(model.totalWords) 个错词放进同一个循环听写")

            Menu {
                if let entry = model.allEntries.first(where:{ $0.wordID == selectedEntryID }) {
                    Section("已选单词：\(entry.word)") {
                        Button("朗读") { onSpeak(entry.word) }
                        Button("复习本词库") { onStartAll(entry.deckID) }
                        if entry.isSlowReaction {
                            Button("移出慢反应词",role:.destructive) { onRemoveSlow(entry.wordID) }
                        }
                    }
                }
                Section("复习方式") {
                    Button("复习错词（优先当前词库）") { if let deck = preferredDeck() { onStartAll(deck) } }
                    Button("今日错词队列") { onStartTodayQueue() }
                    Button("全部错词听写（\(model.totalWords)）") { onStartAllWrongWords() }
                        .disabled(model.totalWords == 0)
                    Button("多词本合练…") { onStartMixed() }
                }
                Section("专项强化") {
                    Button("慢反应词提速（\(model.slowCount)）") { onStartSlow() }
                        .disabled(model.slowCount == 0)
                    Button("顽固单词（\(model.stubbornCount)）") { onStartStubborn() }
                        .disabled(model.stubbornCount == 0)
                }
                Section("记录") {
                    Button("查看练习记录") { filter = .records }
                    Button("导出练习记录 TXT…") { onExportRecords() }
                }
                Divider()
                Button("去听写") { onGoToDictation() }
            } label: {
                Label("操作", systemImage: "slider.horizontal.3")
                    .lumaFont(size: 12, weight: .medium)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                withAnimation(animated ? .easeOut(duration: 0.18) : nil) { showDetails.toggle() }
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 15))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(showDetails ? accent : ink.opacity(0.6))
            .help(showDetails ? "收起统计详情" : "展开统计详情")
            .accessibilityLabel(showDetails ? "收起统计详情" : "展开统计详情")
        }
        .fixedSize()
    }

    /// Collapsible per-deck source list. It lives in the sidebar on wide
    /// windows and above the table only when the window is narrow.
    private var deckPanel: some View {
        DisclosureGroup(isExpanded: $showDecks) {
            VStack(spacing: 2) {
                deckRow("全部词库", count: model.totalWords, due: model.dueWords,
                        selected: deckFilter == "全部词库") { deckFilter = "全部词库" }
                ForEach(model.groups) { group in
                    deckRow(group.title, count: group.entries.count, due: group.dueCount,
                            selected: deckFilter == group.title) { deckFilter = group.title }
                }
                if let deck = selectedDeckID {
                    Button {
                        onStartAll(deck)
                    } label: {
                        Label("训练本词库", systemImage: "headphones")
                            .lumaFont(size: 11, weight: .semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 10, height: 28))
                    .padding(.top, 5)
                }
            }
            .padding(.top, 5)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("按词库筛选")
                        .lumaFont(size: 11.5, weight: .semibold)
                        .foregroundStyle(ink)
                    Text(deckFilter)
                        .lumaFont(size: 9.5)
                        .foregroundStyle(ink.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(model.groups.count) 本")
                    .lumaFont(size: 9.5, weight: .medium, monospacedDigits: true)
                    .foregroundStyle(ink.opacity(0.42))
            }
        }
        .padding(12)
        .background(panelBackground)
    }

    private func deckRow(_ title: String, count: Int, due: Int, selected: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? accent : ink.opacity(0.72))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(count)")
                    .lumaFont(size: 9.5, weight: .semibold, monospacedDigits: true)
                    .foregroundStyle(selected ? accent : ink.opacity(0.42))
                if due > 0 {
                    Text("\(due)")
                        .lumaFont(size: 8.5, weight: .bold, monospacedDigits: true)
                        .foregroundStyle(selected ? accent : semanticTint(.orange))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill((selected ? accent : semanticTint(.orange)).opacity(0.12)))
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(Capsule().fill(selected ? appearance.selected : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var selectedDeckID: String? {
        guard deckFilter != "全部词库" else { return nil }
        return model.groups.first(where: { $0.title == deckFilter })?.deckID
    }

    // MARK: Overview

    private func overview(wide: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: wide ? 170 : 140), spacing: 8)],
                  spacing: 8) {
            compactStat("今日到期", "\(model.dueWords)", "clock.badge.exclamationmark", accent)
            compactStat("累计错词", "\(model.totalWords)", "text.badge.xmark", semanticTint(.orange))
            compactStat("顽固", "\(model.stubbornCount)", "exclamationmark.triangle.fill", semanticTint(.purple))
            compactStat("近 7 天正确率", model.records.isEmpty ? "—" : "\(Int((model.last7Accuracy * 100).rounded()))%",
                        "chart.line.uptrend.xyaxis", accent)
        }
    }

    private func compactStat(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .lumaFont(size: 17, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .contentTransition(.numericText())
                Text(title)
                    .lumaFont(size: 10)
                    .foregroundStyle(ink.opacity(0.52))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(surface.opacity(appearance.isDark ? 0.62 : 0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(tint.opacity(0.12), lineWidth: 0.7)
        )
    }

    // MARK: Main table

    private func mainColumn(wide: Bool) -> some View {
        VStack(spacing: 0) {
            tableToolbar(wide: wide)
            if listVisible {
                if filter == .records {
                    recordsTable(wide: wide)
                } else {
                    wordsTable(wide: wide)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(surface.opacity(appearance.isDark ? 0.52 : 0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(appearance.line, lineWidth: 0.75)
        )
    }

    private func tableToolbar(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    searchExpanded.toggle()
                    searchFocused = searchExpanded
                    if !searchExpanded { query = "" }
                } label: {
                    Label(searchExpanded ? "收起搜索" : "搜索", systemImage: "magnifyingglass")
                        .lumaFont(size: 12, weight: .medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                .help("展开或收起搜索")
                if searchExpanded {
                HStack(spacing: 6) {
                    TextField(filter == .records ? "搜索单词、输入或词库" : "搜索单词或中文释义", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onExitCommand { query = ""; searchExpanded = false; searchFocused = false }
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("清空搜索")
                    }
                }
                .lumaFont(size: 12)
                .padding(.horizontal, 10)
                .frame(minWidth:120, maxWidth:320, minHeight:32)
                .background(Capsule().fill(appearance.paper.opacity(0.45)))
                .overlay(Capsule().strokeBorder(appearance.line, lineWidth: 0.7))
                }
                Spacer(minLength:0)

                Menu {
                    Picker("筛选", selection: $filter) {
                        ForEach(WrongWordsFilter.allCases) { item in
                            Label(item.rawValue, systemImage: item.symbol).tag(item)
                        }
                    }
                    if filter != .records {
                        Picker("排序", selection: $sort) {
                            ForEach(WrongWordsSort.allCases) { item in Text(item.rawValue).tag(item) }
                        }
                    }
                    Divider()
                    Button("重置筛选") { filter = .all; sort = .errors; query = ""; deckFilter = "全部词库" }
                } label: {
                    Label(filter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                        .lumaFont(size: 11.5, weight: .medium)
                        .foregroundStyle(accent)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("筛选与排序")
            }
            HStack(spacing:10) {
                Text(tableSummary + (filter == .records ? "" : " · " + sort.rawValue))
                    .lumaFont(size: 10.5, weight: .medium)
                    .foregroundStyle(ink.opacity(0.5))
                Spacer(minLength:0)
                if listVisible {
                    Button {
                        listExpanded.toggle()
                    } label: {
                        Label(listExpanded ? "缩短列表" : "加长列表", systemImage:listExpanded ? "arrow.up.right.and.arrow.down.left" : "arrow.down.left.and.arrow.up.right")
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    listVisible.toggle()
                } label: {
                    Label(listVisible ? "收起列表" : "展开列表", systemImage:listVisible ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            .lumaFont(size: 10.5, weight:.medium)
            .foregroundStyle(accent)
        }
        .padding(12)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }

    private var tableSummary: String {
        if filter == .records {
            return "\(filteredRecords.count) 条练习记录"
        }
        return "\(filteredEntries.count) 个错词 · \(model.dueWords) 个今日到期"
    }

    private func wordsTable(wide: Bool) -> some View {
        let compact = !wide
        return VStack(spacing: 0) {
            tableHeader(wide: wide, records: false)
            if filteredEntries.isEmpty {
                emptyTable("没有符合条件的错词", "换个筛选条件，或去听写积累错词。")
            } else {
                let entries = filteredEntries
                if renderMode {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            wordRow(entry, compact: compact)
                            if index < entries.count - 1 { Divider().opacity(0.28).padding(.leading, 14) }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                wordRow(entry, compact: compact)
                                if index < entries.count - 1 { Divider().opacity(0.28).padding(.leading, 14) }
                            }
                        }
                    }
                    .frame(height:listExpanded ? 560 : 260)
                }
            }
        }
    }

    private func tableHeader(wide: Bool, records: Bool) -> some View {
        HStack(spacing: 10) {
            Text(records ? "单词 / 输入" : "单词")
                .frame(width: wide ? 190 : 150, alignment: .leading)
            Text(records ? "结果" : "中文释义")
                .frame(maxWidth: .infinity, alignment: .leading)
            if wide {
                Text(records ? "反应" : "错误").frame(width: 58, alignment: .trailing)
                Text(records ? "时间" : "最近练习").frame(width: 84, alignment: .trailing)
                if !records { Text("状态").frame(width: 78, alignment: .leading) }
                Text(records ? "词库" : "下次复习").frame(width: 86, alignment: .trailing)
            } else {
                Text("错误").frame(width: 48, alignment: .trailing)
            }
            Color.clear.frame(width: 26)
        }
        .lumaFont(size: 9.5, weight: .semibold)
        .foregroundStyle(ink.opacity(0.45))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(appearance.paper.opacity(appearance.isDark ? 0.24 : 0.18))
    }

    private func wordRow(_ entry: WrongWordEntry, compact: Bool) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Button { onSpeak(entry.word) } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(accent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(accent.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .help("朗读 \(entry.word)")
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.word)
                        .lumaFont(size: 14.5, weight: .semibold, design: .serif)
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.deckTitle)
                        .lumaFont(size: 9)
                        .foregroundStyle(ink.opacity(0.42))
                        .lineLimit(1)
                }
            }
            .frame(width: compact ? 150 : 190, alignment: .leading)

            Text(entry.meaning.isEmpty ? "—" : entry.meaning)
                .lumaFont(size: 11.5)
                .foregroundStyle(ink.opacity(0.64))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !compact {
                Text("\(entry.errorCount)")
                    .lumaFont(size: 11, weight: .semibold, monospacedDigits: true)
                    .foregroundStyle(entry.errorCount >= 3 ? semanticTint(.orange) : ink.opacity(0.6))
                    .frame(width: 58, alignment: .trailing)
                Text(relativeDate(entry.lastAttemptAt))
                    .lumaFont(size: 10, monospacedDigits: true)
                    .foregroundStyle(ink.opacity(0.52))
                    .frame(width: 84, alignment: .trailing)
                masteryBadge(entry)
                    .frame(width: 78, alignment: .leading)
                Text(dueText(entry.dueAt))
                    .lumaFont(size: 10, monospacedDigits: true)
                    .foregroundStyle(entry.isDue ? accent : ink.opacity(0.5))
                    .frame(width: 86, alignment: .trailing)
            } else {
                Text("\(entry.errorCount) 错")
                    .lumaFont(size: 10.5, weight: .semibold, monospacedDigits: true)
                    .foregroundStyle(entry.errorCount >= 3 ? semanticTint(.orange) : ink.opacity(0.6))
                    .frame(width: 48, alignment: .trailing)
            }


        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(selectedEntryID == entry.wordID ? accent.opacity(0.10) : Color.clear)
        .onTapGesture { selectedEntryID = entry.wordID }
        .modifier(WrongRowHover())
    }

    private func masteryBadge(_ entry: WrongWordEntry) -> some View {
        let color: Color = entry.isStubborn ? semanticTint(.purple) : (entry.mastery == .mastered ? semanticTint(.green) : (entry.mastery == .reviewing ? accent : semanticTint(.orange)))
        return Text(entry.isStubborn ? "顽固" : (entry.isSlowReaction ? "慢反应" : entry.mastery.title))
            .lumaFont(size: 9, weight: .semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func recordsTable(wide: Bool) -> some View {
        VStack(spacing: 0) {
            tableHeader(wide: wide, records: true)
            if filteredRecords.isEmpty {
                emptyTable("还没有练习记录", "开始听写后，正确与错误记录会自动出现在这里。")
            } else {
                let records = filteredRecords
                if renderMode {
                    VStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            recordRow(record, compact: !wide)
                            if index < records.count - 1 { Divider().opacity(0.28).padding(.leading, 14) }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                                recordRow(record, compact: !wide)
                                if index < records.count - 1 { Divider().opacity(0.28).padding(.leading, 14) }
                            }
                        }
                    }
                    .frame(height:listExpanded ? 560 : 260)
                }
            }
        }
    }

    private func recordRow(_ record: WrongWordPracticeRecord, compact: Bool) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(record.isCorrect ? semanticTint(.green) : .red.opacity(0.85))
                VStack(alignment: .leading, spacing: 1) {
                    Text(record.word)
                        .lumaFont(size: 13, weight: .semibold, design: .serif)
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Text(record.typed.isEmpty ? "（空输入）" : record.typed)
                        .lumaFont(size: 9.5, design: .monospaced)
                        .foregroundStyle(ink.opacity(0.48))
                        .lineLimit(1)
                }
            }
            .frame(width: compact ? 150 : 190, alignment: .leading)

            Text(record.isCorrect ? "正确" : "错误")
                .lumaFont(size: 10.5, weight: .semibold)
                .foregroundStyle(record.isCorrect ? semanticTint(.green) : .red.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            if !compact {
                Text(String(format: "%.1fs", record.durationSeconds))
                    .lumaFont(size: 10, monospacedDigits: true)
                    .foregroundStyle(record.isSlowReaction ? semanticTint(.orange) : ink.opacity(0.52))
                    .frame(width: 58, alignment: .trailing)
                Text(relativeDate(record.date))
                    .lumaFont(size: 10, monospacedDigits: true)
                    .foregroundStyle(ink.opacity(0.52))
                    .frame(width: 84, alignment: .trailing)
                Text(record.deckTitle)
                    .lumaFont(size: 9.5)
                    .foregroundStyle(ink.opacity(0.45))
                    .lineLimit(1)
                    .frame(width: 86, alignment: .trailing)
            } else {
                Text(String(format: "%.1fs", record.durationSeconds))
                    .lumaFont(size: 10, monospacedDigits: true)
                    .foregroundStyle(ink.opacity(0.5))
                    .frame(width: 48, alignment: .trailing)
            }
            Color.clear.frame(width: 26)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .modifier(WrongRowHover())
    }

    private func emptyTable(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(accent.opacity(0.7))
            Text(title)
                .lumaFont(size: 13, weight: .semibold)
                .foregroundStyle(ink)
            Text(subtitle)
                .lumaFont(size: 10.5)
                .foregroundStyle(ink.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(20)
    }

    // MARK: Sidebar

    private func sideColumn(includeDeckPanel: Bool) -> some View {
        VStack(spacing: 12) {
            if includeDeckPanel { deckPanel }
            masteryCard
            DisclosureGroup("趋势与错误分析", isExpanded: $showAnalysis) {
                VStack(spacing: 12) {
                    weekCard
                    if !model.diagnoses.isEmpty { diagnosisCard }
                }
                .padding(.top, 8)
            }
            .lumaFont(size: 12, weight: .medium)
            .tint(accent)
        }
    }

    private var masteryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(ink.opacity(0.08), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.001, model.reviewProgress))
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(animated ? .spring(response: 0.45, dampingFraction: 0.84) : nil,
                               value: model.reviewProgress)
                Text("\(Int((model.reviewProgress * 100).rounded()))%")
                    .lumaFont(size: 14, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(ink)
            }
            .frame(width: 68, height: 68)
            VStack(alignment: .leading, spacing: 3) {
                Text("复习进度")
                    .lumaFont(size: 12, weight: .semibold)
                    .foregroundStyle(ink)
                Text("已复习 \(model.reviewedWords) / \(model.totalWords)")
                    .lumaFont(size: 10.5)
                    .foregroundStyle(ink.opacity(0.56))
                Text("已掌握 \(model.masteredCount) 个词")
                    .lumaFont(size: 10.5, weight: .medium)
                    .foregroundStyle(accent)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(panelBackground)
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近 7 天")
                    .lumaFont(size: 12, weight: .semibold)
                    .foregroundStyle(ink)
                Spacer()
                Text(model.records.isEmpty ? "暂无记录" : "正确率 \(Int((model.last7Accuracy * 100).rounded()))%")
                    .lumaFont(size: 9.5, weight: .medium)
                    .foregroundStyle(ink.opacity(0.5))
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(model.days) { day in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            Capsule().fill(ink.opacity(0.06)).frame(height: 46)
                            let totalHeight = max(3, 46 * min(1, Double(day.attempts) / 14.0))
                            let errorHeight = day.attempts == 0 ? 0 : totalHeight * Double(day.errors) / Double(day.attempts)
                            Capsule()
                                .fill(LinearGradient(colors: [accent.opacity(0.55), accent],
                                                     startPoint: .bottom, endPoint: .top))
                                .frame(height: totalHeight)
                            Capsule()
                                .fill(semanticTint(.orange).opacity(0.75))
                                .frame(height: max(0, errorHeight))
                        }
                        .frame(width: 18, height: 46)
                        .clipShape(Capsule())
                        Text(day.label)
                            .lumaFont(size: 8)
                            .foregroundStyle(ink.opacity(0.42))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 10) {
                Label("\(model.last7Errors) 次错误", systemImage: "xmark.circle")
                Spacer()
                Label("\(model.totalWords) 个错词", systemImage: "text.badge.xmark")
            }
            .lumaFont(size: 9)
            .foregroundStyle(ink.opacity(0.45))
        }
        .padding(14)
        .background(panelBackground)
    }

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("错误模式")
                    .lumaFont(size: 12, weight: .semibold)
                    .foregroundStyle(ink)
                Spacer()
                Text("来自实际输入")
                    .lumaFont(size: 9)
                    .foregroundStyle(ink.opacity(0.42))
            }
            ForEach(model.diagnoses.prefix(3)) { diagnosis in
                HStack(spacing: 7) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(diagnosis.label)
                            .lumaFont(size: 10.5, weight: .medium)
                            .foregroundStyle(ink.opacity(0.82))
                            .lineLimit(2)
                        Text("\(diagnosis.count) 个词")
                            .lumaFont(size: 9)
                            .foregroundStyle(ink.opacity(0.42))
                    }
                    Spacer(minLength: 0)
                    Button("针对练习") { onStartMicroDrill(diagnosis.wordIDs) }
                        .buttonStyle(.plain)
                        .lumaFont(size: 9.5, weight: .semibold)
                        .foregroundStyle(accent)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(13)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: appearance.visualThemeSystem == "manga" ? 4:14, style: .continuous)
            .fill(surface.opacity(appearance.isDark ? 0.56 : 0.36))
            .overlay(
                RoundedRectangle(cornerRadius: appearance.visualThemeSystem == "manga" ? 4:14, style: .continuous)
                    .strokeBorder(appearance.line, lineWidth: appearance.visualThemeSystem == "manga" ? CGFloat(appearance.mangaLineWeight):0.7)
            )
    }

    // MARK: Data

    private var filteredEntries: [WrongWordEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var entries = model.allEntries.filter { entry in
            if deckFilter != "全部词库", entry.deckTitle != deckFilter { return false }
            switch filter {
            case .all, .records: break
            case .due: if !entry.isDue { return false }
            case .highFrequency: if entry.errorCount < 3 { return false }
            case .stubborn: if !entry.isStubborn { return false }
            case .slow: if !entry.isSlowReaction { return false }
            }
            guard !q.isEmpty else { return true }
            return entry.word.lowercased().contains(q) || entry.meaning.lowercased().contains(q)
        }
        switch sort {
        case .errors:
            entries.sort { $0.errorCount == $1.errorCount ? $0.word < $1.word : $0.errorCount > $1.errorCount }
        case .recent:
            entries.sort { ($0.lastAttemptAt ?? .distantPast) > ($1.lastAttemptAt ?? .distantPast) }
        case .due:
            entries.sort { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        case .alphabetical:
            entries.sort { $0.word.localizedStandardCompare($1.word) == .orderedAscending }
        }
        return entries
    }

    private var filteredRecords: [WrongWordPracticeRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return model.records }
        return model.records.filter {
            $0.word.lowercased().contains(q) || $0.typed.lowercased().contains(q) || $0.deckTitle.lowercased().contains(q)
        }
    }

    private func preferredDeck() -> String? {
        if let selectedDeckID { return selectedDeckID }
        if let due = model.groups.first(where: { $0.dueCount > 0 }) { return due.deckID }
        return model.groups.first?.deckID
    }

    private func dueText(_ date: Date?) -> String {
        guard let date else { return "—" }
        let now = Date()
        if date <= now { return "已到期" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now),
                                                   to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "明天" }
        return "\(days) 天后"
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) 小时前" }
        let days = Int(seconds / 86400)
        if days == 1 { return "昨天" }
        if days < 7 { return "\(days) 天前" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Row hover

private struct WrongRowHover: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.045 : 0))
            )
            .onHover { inside in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { hovered = inside }
            }
    }
}
