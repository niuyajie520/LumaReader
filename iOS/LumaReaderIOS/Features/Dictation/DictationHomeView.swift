import SwiftUI

/// 听写主界面：手机上主打「听 → 打 → 立刻订正」，一屏只放当前这一个词。
struct DictationHomeView: View {
    @Environment(StudyStore.self) private var store
    @Environment(SpeechService.self) private var speech

    @State private var active: DictationSession?
    @State private var setupPresented = false
    @State private var finishedSummary: DictationSummary?

    var body: some View {
        NavigationStack {
            Group {
                if let active {
                    DictationRunnerView(session: active) { summary in
                        finishedSummary = summary
                        self.active = nil
                    }
                } else {
                    startPanel
                }
            }
            .navigationTitle("听写")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if active == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { setupPresented = true } label: { Image(systemName: "slider.horizontal.3") }
                            .accessibilityLabel("听写设置")
                    }
                }
            }
            .sheet(isPresented: $setupPresented) {
                DictationSetupSheet { deck, strategy, scope, limit in
                    begin(deck: deck, strategy: strategy, scope: scope, limit: limit)
                }
            }
            .sheet(item: $finishedSummary) { summary in
                DictationSummarySheet(summary: summary) {
                    finishedSummary = nil
                }
            }
        }
    }

    // MARK: 开始面板

    private var startPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let deck = store.activeDeck
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck?.title ?? "还没有词本")
                        .font(.title2.weight(.semibold))
                    Text(deck.map { "\($0.count) 个条目" } ?? "先在「词库」里导入，或阅读时把生词加进来。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                let due = store.dueReviews.count
                HStack(spacing: 10) {
                    Label("\(due) 个到期", systemImage: "clock.badge.checkmark")
                    if due > 0 { Text("先过到期词，再进新词") .foregroundStyle(.secondary) }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button {
                    beginDefault()
                } label: {
                    Label("开始听写", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LumaPrimaryButtonStyle())
                .accessibilityIdentifier("dictation.start")
                .disabled(deck == nil)

                Button {
                    setupPresented = true
                } label: {
                    Label("选范围与策略", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LumaSecondaryButtonStyle())
                .accessibilityIdentifier("dictation.setup")

                recentWrongCard
            }
            .padding(20)
        }
        .background(Color.lumaPaper)
    }

    private var recentWrongCard: some View {
        let wrong = store.wrongWords(inRound: nil, deckID: store.activeDeck?.id)
        return Group {
            if wrong.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近做错的 \(Set(wrong.map(\.wordID)).count) 个词")
                        .font(.headline)
                    ForEach(wrong.prefix(5)) { log in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(log.word).font(.callout.weight(.medium))
                            Spacer()
                            Text(log.userTyped.isEmpty ? "空" : log.userTyped)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.lumaSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: 启动

    private func beginDefault() {
        guard let deck = store.activeDeck else { return }
        let limit = 20
        let due = store.dueReviews.filter { $0.deckID == deck.id }
        let words = due.isEmpty ? Array(deck.words.prefix(limit)) : Array(due.prefix(limit))
        begin(deck: deck, strategy: .quick, scope: .dueFirst, limit: limit, words: words)
    }

    private func begin(deck: VocabularyDeck?, strategy: DictationStrategy, scope: DictationScope, limit: Int) {
        guard let deck else { return }
        let words: [VocabularyWord]
        switch scope {
        case .dueFirst:
            let due = store.dueReviews.filter { $0.deckID == deck.id }
            let rest = deck.words.filter { word in !due.contains(where: { $0.id == word.id }) }
            words = Array((due + rest).prefix(limit))
        case .dueOnly:
            words = Array(store.dueReviews.filter { $0.deckID == deck.id }.prefix(limit))
        case .all:
            words = Array(deck.words.prefix(limit))
        case .wrongOnly:
            let ids = store.wrongWordIDs(inRound: nil, deckID: deck.id)
            words = deck.words.filter { ids.contains($0.id) }
        }
        guard !words.isEmpty else { return }
        begin(deck: deck, strategy: strategy, scope: scope, limit: limit, words: words)
    }

    private func begin(deck: VocabularyDeck, strategy: DictationStrategy, scope: DictationScope, limit: Int, words: [VocabularyWord]) {
        speech.accent = store.speechAccent
        speech.rate = store.speechRate
        let session = DictationSession(deck: deck, words: WordReviewOrdering.dueFirst(words, schedule: store.schedule), strategy: strategy)
        active = session
    }
}

enum DictationScope: String, CaseIterable, Identifiable {
    case dueFirst, dueOnly, all, wrongOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueFirst: return "到期优先＋新词"
        case .dueOnly: return "只练到期词"
        case .all: return "按顺序过一遍"
        case .wrongOnly: return "只练做错的词"
        }
    }
}

// MARK: - 设置面板

private struct DictationSetupSheet: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var deckID: String = ""
    @State private var strategy: DictationStrategy = .quick
    @State private var scope: DictationScope = .dueFirst
    @State private var limit: Int = 20

    let onStart: (VocabularyDeck?, DictationStrategy, DictationScope, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("词本") {
                    Picker("词本", selection: $deckID) {
                        ForEach(store.decks) { deck in
                            Text(deck.title).tag(deck.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("本轮范围") {
                    Picker("范围", selection: $scope) {
                        ForEach(DictationScope.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("复习策略") {
                    Picker("策略", selection: $strategy) {
                        ForEach(DictationStrategy.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Text(strategy.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("本轮词数上限") {
                    Picker("上限", selection: $limit) {
                        ForEach([10, 20, 30, 50], id: \.self) { Text("\($0) 个").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("听写设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") {
                        onStart(store.deck(id: deckID) ?? store.activeDeck, strategy, scope, limit)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if deckID.isEmpty { deckID = store.activeDeck?.id ?? store.decks.first?.id ?? "" }
            }
        }
    }
}

// MARK: - 一轮进行中

struct DictationRunnerView: View {
    @Environment(StudyStore.self) private var store
    @Environment(SpeechService.self) private var speech

    let session: DictationSession
    let onFinish: (DictationSummary) -> Void

    @State private var input = ""
    @State private var feedback: Feedback = .none
    /// 快速过词模式下答错会立刻跳到下一个词，这里留一行「刚才那个词」让用户看得见正确答案。
    @State private var missedAnswer: String?
    /// 点了「看答案」之后留在屏幕上的那个词（快速过词会立刻跳到下一词）。
    @State private var revealedAnswer: String?
    @State private var revealTarget = false
    @State private var wordStartedAt = Date()
    @State private var showQuitConfirm = false
    @FocusState private var inputFocused: Bool

    enum Feedback: Equatable {
        case none
        case correct
        case wrong(count: Int)
        case phraseFix(fragment: String)
        case stubborn
    }

    var body: some View {
        // 手机上键盘会盖住底部三分之一的屏幕：正文放进可滚动区，提交按钮用
        // safeAreaInset 钉在键盘上方，敲完字不用收键盘就能直接提交。
        ScrollView {
            VStack(spacing: 16) {
                progressHeader
                promptCard
                secondaryActions
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        // 输入框和提交按钮一起钉在键盘上方：键盘弹出时也能看见自己打的字，
        // 否则输入框会被键盘挤出屏幕、点「输入框」实际点在提交按钮上。
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                inputField
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.lumaPaper)
        }
        .background(Color.lumaPaper)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("结束") { showQuitConfirm = true }
            }
        }
        .confirmationDialog("结束本轮听写？", isPresented: $showQuitConfirm, titleVisibility: .visible) {
            Button("结束并看结果") { finish() }
            Button("继续听写", role: .cancel) {}
        }
        .onAppear { startCurrentWord() }
        .onChange(of: session.current?.id) { _, _ in startCurrentWord() }
        .onChange(of: session.phase) { _, phase in
            if phase == .finished { finish() }
        }
    }

    // MARK: 顶部进度

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(session.deckTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text("剩 \(session.remainingCount) · 已过 \(session.completedWordIDs.count)")
                    .accessibilityIdentifier("dictation.progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: Double(session.completedWordIDs.count),
                         total: Double(max(1, session.completedWordIDs.count + session.remainingCount)))
                .tint(Color.lumaAccent)
        }
        .padding(.top, 8)
    }

    // MARK: 卡片

    private var promptCard: some View {
        // 键盘弹出时把卡片压紧：手机上竖向空间不够，否则卡片底部会被输入区切掉。
        VStack(spacing: inputFocused ? 10 : 14) {
            Button {
                replay()
            } label: {
                Image(systemName: speech.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.system(size: inputFocused ? 32 : 44, weight: .regular))
                    .frame(width: inputFocused ? 68 : 96, height: inputFocused ? 68 : 96)
                    .background(Color.lumaSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("再听一遍")

            if let word = session.current {
                if let answer = revealedAnswer ?? ((revealTarget || session.phase == .correcting) ? word.word : nil) {
                    Text(answer)
                        .accessibilityIdentifier("dictation.target")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(word.shortDefinition.isEmpty ? "暂无释义" : word.shortDefinition)
                        .accessibilityIdentifier("dictation.definition")
                        .font(.system(size: 24, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                }
                if !inputFocused {
                    Text("\(word.wordCount) 个词\(word.isPhrase ? " · 整条听写" : "")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

            }
            feedbackLine
            if let missedAnswer {
                Label("刚才那个词：\(missedAnswer)", systemImage: "textformat.abc")
                    .accessibilityIdentifier("dictation.missedAnswer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, inputFocused ? 16 : 24)
        .padding(.horizontal, 16)
        .background(Color.lumaSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.snappy(duration: 0.14), value: inputFocused)
    }

    @ViewBuilder
    private var feedbackLine: some View {
        switch feedback {
        case .none:
            EmptyView()
        case .correct:
            Label("对了", systemImage: "checkmark.circle.fill")
                .accessibilityIdentifier("dictation.feedback")
                .foregroundStyle(Color.lumaPositive)
                .font(.subheadline.weight(.medium))
        case .wrong(let count):
            Label("再拼一次，本轮第 \(count) 次", systemImage: "exclamationmark.triangle.fill")
                .accessibilityIdentifier("dictation.feedback")
                .foregroundStyle(Color.lumaWarning)
                .font(.subheadline.weight(.medium))
        case .phraseFix(let fragment):
            Label("只差「\(fragment)」，整条重拼一次", systemImage: "text.badge.checkmark")
                .accessibilityIdentifier("dictation.feedback")
                .foregroundStyle(Color.lumaWarning)
                .font(.subheadline.weight(.medium))
        case .stubborn:
            Label("这个词先挪到本轮最后", systemImage: "arrow.uturn.backward")
                .accessibilityIdentifier("dictation.feedback")
                .foregroundStyle(Color.lumaWarning)
                .font(.subheadline.weight(.medium))
        }
    }

    // MARK: 输入

    private var inputField: some View {
        TextField("照着听到的拼写", text: $input)
            .accessibilityIdentifier("dictation.input")
            .textFieldStyle(.plain)
            .font(.system(size: 24, weight: .regular, design: .rounded))
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.done)
            .focused($inputFocused)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(Color.lumaSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onSubmit { submit() }
    }

    private var secondaryActions: some View {
        HStack(spacing: 12) {
                Button {
                    if session.phase == .awaitingAnswer, let word = session.current {
                        revealedAnswer = word.word
                        _ = session.submit("", durationSeconds: 30)
                        store.recordReview(wordID: word.id, cleanRecall: false, reactionSeconds: 30)
                    }
                    inputFocused = true
                } label: {
                    Label("看答案", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LumaSecondaryButtonStyle())
                .accessibilityIdentifier("dictation.reveal")
                .disabled(session.phase != .awaitingAnswer)

                Button {
                    replay()
                } label: {
                    Label("再听", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LumaSecondaryButtonStyle())
        }
    }

    private var footer: some View {
        Button {
            submit()
        } label: {
            Label(session.phase == .correcting ? "继续" : "提交", systemImage: "arrow.right.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LumaPrimaryButtonStyle())
        .accessibilityIdentifier("dictation.submit")
        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: 行为

    private func startCurrentWord() {
        guard let word = session.current else { return }
        input = ""
        revealTarget = session.phase == .correcting
        // 反馈留到下一次提交再换，避免「快速过词」跳过下一词时刚出现的提示立刻被清掉。
        wordStartedAt = Date()
        speech.accent = store.speechAccent
        speech.rate = store.speechRate
        speech.repeatCount = store.speechRepeatCount
        speech.speak(word.word)
        inputFocused = true
    }

    private func replay() {
        guard let word = session.current else { return }
        speech.speak(word.word)
    }

    private func submit() {
        guard let word = session.current else { return }
        let typed = input
        missedAnswer = nil
        revealedAnswer = nil
        let latency = max(0.6, Date().timeIntervalSince(speech.finishedSpeakingAt ?? wordStartedAt))
        let outcome = session.submit(typed, durationSeconds: latency)
        persistLogs()
        guard let outcome else { return }
        if outcome == .skippedIncorrect {
            // 快速过词：这个词已经插回后面，先把正确答案留在屏幕上。
            let count = max(1, session.errorCountByWordID[word.id, default: 1])
            feedback = .wrong(count: count)
            missedAnswer = word.word
            store.recordReview(wordID: word.id, cleanRecall: false, reactionSeconds: latency)
            input = ""
            speech.speak(word.word)
            return
        }

        switch outcome {
        case .correct:
            feedback = .correct
            store.recordReview(wordID: word.id, cleanRecall: true, reactionSeconds: latency)
            input = ""
        case .needsCorrection(let count):
            feedback = .wrong(count: count)
            revealTarget = true
            store.recordReview(wordID: word.id, cleanRecall: false, reactionSeconds: latency)
            speech.speak(word.word)
            input = ""
        case .requeuedForRetry(let count, _):
            feedback = .wrong(count: count)
            revealTarget = true
            store.recordReview(wordID: word.id, cleanRecall: false, reactionSeconds: latency)
            input = ""
        case .needsPhraseFix(let fragment):
            feedback = .phraseFix(fragment: fragment)
            revealTarget = true
            input = ""
        case .promotedToStubbornWords(let count):
            feedback = .stubborn
            revealTarget = true
            store.markStubborn(word: word, missCount: count)
            store.recordReview(wordID: word.id, cleanRecall: false, reactionSeconds: latency)
            input = ""
        case .skippedIncorrect:
            break
        }
    }

    private func persistLogs() {
        for log in session.drainLogs() { store.appendLog(log) }
    }

    private func finish() {
        persistLogs()
        var wrong: [String] = []
        var seen = Set<String>()
        for log in store.wrongWords(inRound: session.sessionID, deckID: session.deckID) where !seen.contains(log.wordID) {
            seen.insert(log.wordID)
            wrong.append(log.word)
        }
        let elapsed = Date().timeIntervalSince(session.startedAt)
        onFinish(DictationSummary(deckTitle: session.deckTitle,
                                  correct: session.correctCount,
                                  wrongCount: wrong.count,
                                  elapsed: elapsed,
                                  wrongWords: wrong,
                                  finished: session.completedWordIDs.count,
                                  total: session.completedWordIDs.count + session.remainingCount))
    }
}

// MARK: - 结果

struct DictationSummary: Identifiable {
    let id = UUID()
    let deckTitle: String
    let correct: Int
    let wrongCount: Int
    let elapsed: TimeInterval
    let wrongWords: [String]
    let finished: Int
    let total: Int

    var minutesPerWord: Double {
        let per = total > 0 ? elapsed / Double(total) : 0
        return per / 60
    }
}

private struct DictationSummarySheet: View {
    let summary: DictationSummary
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(summary.deckTitle).font(.headline)
                    HStack(spacing: 20) {
                        metric("毕业", "\(summary.finished)")
                        metric("错词", "\(summary.wrongCount)")
                        metric("用时", durationText)
                    }
                    if !summary.wrongWords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("本轮错词").font(.subheadline.weight(.semibold))
                            ForEach(summary.wrongWords, id: \.self) { word in
                                Text(word).font(.callout)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lumaSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Text("这些错词明天会排在队首。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("本轮结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { onClose() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var durationText: String {
        let total = Int(summary.elapsed.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}


