import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
#if canImport(SwiftUI) && canImport(AppKit)

@MainActor
public struct LumaStudyCenterHostView: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var mode: String

    @MainActor
    final class HostStateModel: ObservableObject {
        @Published var storageError: String?
        let speech = MacOSSpeechSynthesisManager()
        var clockOwner: UUID?
        var examClockTask: Task<Void, Never>?
        var isExamClockActive: Bool = false
        var persistence: StudyPersistenceManager?
        init(storageDirectory: URL? = nil) {
            do {
                let directory: URL
                if let storageDirectory { directory = storageDirectory }
                else { directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("LumaReader/StudyCenter", isDirectory: true) }
                let manager = try StudyPersistenceManager(storageDirectory: directory)
                let saved = try manager.loadAndMigrateIfNeeded()
                persistence = manager; storeSnapshot = saved
                selectedAccent = TTSVoiceAccent(rawValue: saved.preferredAccent) ?? .british
                speechRateMultiplier = saved.preferredSpeechRate < 0.7 ? saved.preferredSpeechRate * 2 : saved.preferredSpeechRate
                if let workspaceDeck = saved.workspace?.selectedDeckID, !workspaceDeck.isEmpty {
                    selectedDeck = workspaceDeck
                }
                if let session = saved.dictationSession {
                    selectedDeck = saved.workspace?.selectedDeckID ?? session.currentWord?.deckID ?? session.attemptLogs.last?.deckID ?? selectedDeck
                    if session.dateString == LumaStudyCenterHostView.todayDateString() {
                        dictationMachine = session
                    } else {
                        dictationMachine = DictationSessionStateMachine(
                            mode: session.mode,
                            dateString: LumaStudyCenterHostView.todayDateString(),
                            initialWords: session.pendingQueue,
                            existingStubbornWordsForToday: saved.stubbornWords
                        )
                    }
                }
                if let state = saved.workspace {
                    let currentKey = Self.sessionKey(mode: dictationMachine.mode, date: dictationMachine.dateString, deck: selectedDeck)
                    if let currentWordID = dictationMachine.currentWord?.id {
                        if state.inputWordID == currentWordID {
                            dictationInput = state.dictationInput
                            showMeaning = state.showMeaning
                            revealedWordID = state.revealedWordID
                        } else if state.deckInputWordIDs?[currentKey] == currentWordID {
                            dictationInput = state.deckInputs?[currentKey] ?? ""
                            showMeaning = state.deckShowMeaning?[currentKey] ?? false
                            revealedWordID = state.deckRevealedWordIDs?[currentKey]
                        }
                    }
                    if let id = state.writingDraftID,
                       let draft = saved.activeWritingDrafts.values.first(where: { $0.id == id }),
                       let question = LumaStudyCenterHostView.builtInPracticeQuestions.first(where: { $0.id == draft.questionID }) {
                        currentDraft = draft
                        selectedExamQuestion = question
                    }
                }
                if manager.recoveryPerformed { storageError = "检测到学习记录损坏，已恢复上次有效备份；损坏原文件保存在备份目录中。" }
            } catch { storageError = "学习记录读取失败，原文件已保留：\(error.localizedDescription)" }
        }

        func remember(_ mode: String) {
            var state = storeSnapshot.workspace ?? StudyWorkspaceState()
            if mode.hasPrefix("学习_听力") {
                state.listeningMode = mode
                if mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" {
                    state.activePracticeListeningMode = mode
                }
            }
            if mode.contains("写作") || mode == "学习_草稿" || mode == "学习_模拟机考" {
                state.writingMode = mode
                if mode.contains("模拟机考") {
                    state.activePracticeWritingMode = mode
                }
            }
            storeSnapshot.workspace = state
            save()
        }

        static func sessionKey(mode: DictationSessionMode, date: String, deck: String) -> String {
            mode.rawValue + "|" + date + "|" + deck
        }

        func tickExamClock(seconds: Int = 1) {
            guard seconds > 0, isExamClockActive, !currentDraft.isPaused, currentDraft.remainingSeconds > 0 else { return }
            let isSubmitted = storeSnapshot.writingSubmissions.contains { $0.draftSessionID == currentDraft.id }
            guard !isSubmitted else {
                isExamClockActive = false
                return
            }
            let used = min(seconds, currentDraft.remainingSeconds)
            currentDraft.remainingSeconds -= used
            currentDraft.elapsedSeconds += used
            currentDraft.lastSavedAt = Date()
            storeDraft(currentDraft)
        }

        func startContinuousExamClockIfNeeded(onExpire: @escaping @MainActor (WritingExamDraftState) -> Void) {
            isExamClockActive = true
            guard examClockTask == nil else { return }
            examClockTask = Task { @MainActor [weak self] in
                var previous = ContinuousClock.now
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { break }
                    guard let self else { break }
                    let now = ContinuousClock.now
                    let elapsed = previous.duration(to: now)
                    let secs = Int(elapsed.components.seconds)
                    guard secs > 0 else { continue }
                    previous = previous.advanced(by: .seconds(secs))
                    if self.isExamClockActive && !self.currentDraft.isPaused && self.currentDraft.remainingSeconds > 0 {
                        self.tickExamClock(seconds: secs)
                        if self.currentDraft.remainingSeconds == 0 {
                            self.isExamClockActive = false
                            onExpire(self.currentDraft)
                        }
                    }
                }
            }
        }

        func storeDraft(_ draft: WritingExamDraftState) {
            storeSnapshot.activeWritingDrafts = storeSnapshot.activeWritingDrafts.filter { $0.value.id != draft.id }
            storeSnapshot.activeWritingDrafts[draft.id.uuidString] = draft
            save()
        }

        func existingUnsubmittedDraft(for questionID: String) -> WritingExamDraftState? {
            let submittedIDs = Set(storeSnapshot.writingSubmissions.map(\.draftSessionID))
            if currentDraft.questionID == questionID && !submittedIDs.contains(currentDraft.id) &&
               (!currentDraft.part1EssayText.isEmpty || !currentDraft.part2EssayText.isEmpty || currentDraft.elapsedSeconds > 0 || storeSnapshot.activeWritingDrafts.values.contains(where: { $0.id == currentDraft.id })) {
                return currentDraft
            }
            return storeSnapshot.activeWritingDrafts.values
                .filter { $0.questionID == questionID && !submittedIDs.contains($0.id) }
                .sorted { $0.lastSavedAt > $1.lastSavedAt }
                .first
        }

        @discardableResult func save() -> Bool {
            guard let persistence else { return false }
            var workspace = storeSnapshot.workspace ?? StudyWorkspaceState()
            workspace.selectedDeckID = selectedDeck
            workspace.dictationInput = dictationInput
            workspace.inputWordID = dictationMachine.currentWord?.id
            workspace.showMeaning = showMeaning
            workspace.revealedWordID = revealedWordID

            let deck = dictationMachine.currentWord?.deckID ?? dictationMachine.attemptLogs.last?.deckID ?? selectedDeck
            let key = Self.sessionKey(mode: dictationMachine.mode, date: dictationMachine.dateString, deck: deck)
            var deckInputs = workspace.deckInputs ?? [:]
            var deckInputWordIDs = workspace.deckInputWordIDs ?? [:]
            var deckShowMeaning = workspace.deckShowMeaning ?? [:]
            var deckRevealedWordIDs = workspace.deckRevealedWordIDs ?? [:]
            deckInputs[key] = dictationInput
            if let wordID = dictationMachine.currentWord?.id {
                deckInputWordIDs[key] = wordID
            } else {
                deckInputWordIDs.removeValue(forKey: key)
            }
            deckShowMeaning[key] = showMeaning
            if let revealedWordID {
                deckRevealedWordIDs[key] = revealedWordID
            } else {
                deckRevealedWordIDs.removeValue(forKey: key)
            }
            workspace.deckInputs = deckInputs
            workspace.deckInputWordIDs = deckInputWordIDs
            workspace.deckShowMeaning = deckShowMeaning
            workspace.deckRevealedWordIDs = deckRevealedWordIDs

            let isCurrentSubmitted = storeSnapshot.writingSubmissions.contains { $0.draftSessionID == currentDraft.id }
            let hasDraftProgress = !currentDraft.part1EssayText.isEmpty || !currentDraft.part2EssayText.isEmpty || currentDraft.elapsedSeconds > 0
            if !isCurrentSubmitted && (hasDraftProgress || storeSnapshot.activeWritingDrafts.values.contains(where: { $0.id == currentDraft.id })) {
                storeSnapshot.activeWritingDrafts = storeSnapshot.activeWritingDrafts.filter { $0.value.id != currentDraft.id }
                storeSnapshot.activeWritingDrafts[currentDraft.id.uuidString] = currentDraft
                workspace.writingDraftID = currentDraft.id
            }
            storeSnapshot.workspace = workspace
            storeSnapshot.dictationSession = dictationMachine
            if storeSnapshot.dictationSessions == nil { storeSnapshot.dictationSessions = [:] }
            storeSnapshot.dictationSessions?[key] = dictationMachine
            storeSnapshot.preferredAccent = selectedAccent.rawValue
            storeSnapshot.preferredSpeechRate = speechRateMultiplier
            do { try persistence.save(storeSnapshot); return true }
            catch { storageError = "学习记录保存失败：\(error.localizedDescription)"; return false }
        }

        @Published var storeSnapshot: StudyStoreSnapshot = StudyStoreSnapshot()
        @Published var selectedExamQuestion: Task1QuestionItem = LumaStudyCenterHostView.builtInPracticeQuestions[2]
        @Published var currentDraft: WritingExamDraftState = WritingExamDraftState(
            id: UUID(),
            questionID: "ORIG-003",
            examTitle: "原创写作练习 · 岛屿改造",
            activePart: .part1,
            part1EssayText: "",
            part2EssayText: "",
            remainingSeconds: 3600,
            elapsedSeconds: 0,
            isPaused: false,
            isSingleTaskMode: false,
            lastSavedAt: Date(),
            containsLegacyNonEnglishNotice: false
        )
        @Published var dictationMachine = DictationSessionStateMachine(
            mode: .newTask,
            dateString: LumaStudyCenterHostView.todayDateString(),
            initialWords: LumaStudyCenterHostView.builtInVocabularyWords
        )
        @Published var dictationInput: String = ""
        @Published var dictationFeedback: String = "答错后必须拼对才能继续。订正后随机插入后续复习，第 6 次答错进入顽固单词，订正后不再循环。"
        @Published var selectedAccent: TTSVoiceAccent = .british
        @Published var speechRateMultiplier: Float = 1.0
        @Published var showMeaning = false
        @Published var revealedWordID: String? = nil
        @Published var selectedDeck = "vocab_daily"
        @Published var practiceSeconds = 3600
        @Published var speechSettingsShown = false
        @Published var evaluatingSubmission: UUID?
        @Published var statsScope: StudyStatisticsScope = .all
        @Published var statsTimeWindow: StudyStatsTimeWindow = .allTime
    }

    @State private var clockToken = UUID()
    @StateObject private var vm: HostStateModel
    @StateObject private var audio = SpeechAudioPipeline()
    @State private var importDraft: VocabularyImportDraft?
    @State private var reviewSession: WritingReviewSession?
    @State private var importShown = false
    @State private var deckSearch = ""
    @FocusState private var answerFocused: Bool
    private var allWords: [VocabularyWord] { Self.builtInVocabularyWords + (vm.storeSnapshot.importedWords ?? []) }

    private var ttsEngine: MacOSSpeechSynthesisManager { vm.speech }
    private let evaluateWriting: (@MainActor (WritingSubmissionRecord, Task1QuestionItem) async throws -> IELTSFourCriteriaEstimate)?

    public init(mode: Binding<String>, storageDirectory: URL? = nil, session: LumaStudySession? = nil, evaluateWriting: (@MainActor (WritingSubmissionRecord, Task1QuestionItem) async throws -> IELTSFourCriteriaEstimate)? = nil) {
        self._vm = StateObject(wrappedValue: session?.model ?? HostStateModel(storageDirectory: storageDirectory))
        self._mode = mode
        self.evaluateWriting = evaluateWriting
    }

    private var isPractice: Bool { mode.contains("模拟机考") || (mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习") }

    private var hasUnfinishedListeningSession: Bool {
        !vm.dictationMachine.isSessionFinished &&
        (!vm.dictationMachine.completedWordIDs.isEmpty ||
         !vm.dictationMachine.attemptLogs.isEmpty ||
         !vm.dictationInput.isEmpty ||
         vm.dictationMachine.requiresCorrection)
    }

    private var hasUnfinishedWritingDraft: Bool {
        let submittedIDs = Set(vm.storeSnapshot.writingSubmissions.map(\.draftSessionID))
        guard !submittedIDs.contains(vm.currentDraft.id) else { return false }
        return !vm.currentDraft.part1EssayText.isEmpty || !vm.currentDraft.part2EssayText.isEmpty || vm.currentDraft.elapsedSeconds > 0
    }

    public var body: some View {
        ZStack {
            appearance.paper.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Left Reader-matched Glass Capsule Cluster
                    HStack(spacing: 8) {
                        Button { mode = "学习" } label: {
                            Label("学习中心", systemImage: "square.grid.2x2")
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习", horizontalPadding: 12, height: 32))
                        .help("返回学习中心主页")

                        if mode.contains("听力") {
                            if mode != "学习_听力_今日计划" && mode != "学习_听力_错词复习" && hasUnfinishedListeningSession {
                                Button("继续听写 (\(vm.dictationMachine.completedWordIDs.count)/\(vm.dictationMachine.completedWordIDs.count + vm.dictationMachine.pendingQueue.count))") {
                                    mode = vm.dictationMachine.mode == .wrongWordReview ? "学习_听力_错词复习" : "学习_听力_今日计划"
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                            }
                            Button("词库") { mode = "学习_听力" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_听力" || mode == "学习_听力_我的词库", horizontalPadding: 12, height: 32))
                            Button("错词") { selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .wrongWordReview, resume: true); mode = "学习_听力_错词复习" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_听力_错词复习", horizontalPadding: 12, height: 32))
                            Button("顽固单词") { mode = "学习_听力_顽固单词" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_听力_顽固单词", horizontalPadding: 12, height: 32))
                            Button("记录") { mode = "学习_听力_学习记录" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_听力_学习记录", horizontalPadding: 12, height: 32))
                        } else if mode.contains("写作") || mode == "学习_草稿" {
                            if !mode.contains("模拟机考") && hasUnfinishedWritingDraft {
                                Button("继续写作 · \(vm.currentDraft.examTitle)") {
                                    mode = "学习_写作_模拟机考"
                                }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                            }
                            Button("Task 1") { mode = "学习_写作_Task1题库" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_写作_Task1题库", horizontalPadding: 12, height: 32))
                            Button("Task 2") { mode = "学习_写作_Task2题库" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_写作_Task2题库", horizontalPadding: 12, height: 32))
                            if !mode.contains("模拟机考") {
                                Picker("模式", selection: $vm.practiceSeconds) {
                                    Text("完整模拟 · 60 分钟").tag(3600)
                                    Text("Task 1 · 20 分钟").tag(1200)
                                    Text("Task 2 · 40 分钟").tag(2400)
                                }
                                .frame(maxWidth: 220)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .studyGlassCapsule(cornerRadius: 16)
                            }
                            Button("草稿") { mode = "学习_草稿" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_草稿", horizontalPadding: 12, height: 32))
                            Button("历史作文") { mode = "学习_写作_历史作文" }
                                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == "学习_写作_历史作文" || mode == "学习_写作_评分反馈", horizontalPadding: 12, height: 32))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .studyGlassCapsule(cornerRadius: 22)

                    Spacer()

                    // Right Reader-matched Glass Capsule Cluster (听力 ↔ 写作 ↔ 看书独立切换)
                    HStack(spacing: 8) {
                        if mode.contains("听力") {
                            Button {
                                vm.save()
                                if hasUnfinishedWritingDraft {
                                    mode = "学习_写作_模拟机考"
                                } else {
                                    mode = vm.storeSnapshot.workspace?.writingMode ?? "学习_写作_Task1题库"
                                }
                            } label: {
                                Label(hasUnfinishedWritingDraft ? "继续写作" : "去写作", systemImage: "pencil")
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                        } else if mode.contains("写作") || mode == "学习_草稿" {
                            Button {
                                vm.save()
                                if hasUnfinishedListeningSession {
                                    mode = vm.dictationMachine.mode == .wrongWordReview ? "学习_听力_错词复习" : "学习_听力_今日计划"
                                } else {
                                    mode = vm.storeSnapshot.workspace?.listeningMode ?? "学习_听力"
                                }
                            } label: {
                                Label(hasUnfinishedListeningSession ? "继续听写" : "去听力", systemImage: "headphones")
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                        }
                        Button {
                            vm.save()
                            NotificationCenter.default.post(name: Notification.Name("LumaReader.ResumeReadingWorkspace"), object: nil)
                        } label: {
                            Label("继续看书", systemImage: "book.pages")
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                        .help("切换到看书工作区并保留当前练习进度 · ⌥⌘5")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .studyGlassCapsule(cornerRadius: 22)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .padding(.top, isPractice ? 26 : 0)

                if let error = vm.storageError {
                    HStack {
                        Text(error).foregroundStyle(.red).textSelection(.enabled)
                        Spacer()
                        Button("关闭提示") { vm.storageError = nil }
                    }.padding(.horizontal, 24)
                }

                switch mode {
                case "学习": studyHome
                case "学习_听力", "学习_听力_我的词库": listeningHome
                case "学习_草稿":
                    List(Array(vm.storeSnapshot.activeWritingDrafts.values).sorted { $0.lastSavedAt > $1.lastSavedAt }, id: \.id) { draft in
                        Button("\(draft.examTitle) · 剩余 \(draft.remainingSeconds / 60) 分钟") {
                            if let question = Self.builtInPracticeQuestions.first(where: { $0.id == draft.questionID }) {
                                vm.selectedExamQuestion = question; vm.currentDraft = draft; vm.save(); mode = "学习_写作_模拟机考"
                            }
                        }
                    }
                case "学习_听力_今日计划":
                    listeningCenterView(submode: .newTask)
                case "学习_听力_错词复习":
                    listeningCenterView(submode: .wrongWordReview)
                case "学习_听力_顽固单词":
                    stubbornWordsDedicatedView
                case "学习_听力_学习记录":
                    listeningRecordsDedicatedView
                case "学习_模拟机考", "学习_写作_模拟机考":
                    VStack(spacing: 0) {
                        HStack {
                            Text("正在练习：\(vm.currentDraft.examTitle)（草稿实时自动保存，倒计时按真实时间连续运行）")
                                .font(.caption)
                                .foregroundStyle(appearance.ink.opacity(0.72))
                            Spacer()
                            Button("重新开始本篇") {
                                launchExam(for: vm.selectedExamQuestion, singleTask: vm.currentDraft.isSingleTaskMode, forceNew: true)
                            }
                            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 26))
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 4)

                        IELTSWritingExamSplitPaneView(
                            question: vm.selectedExamQuestion,
                            draft: $vm.currentDraft,
                            onAutoSave: { updated in
                                vm.storeDraft(updated)
                            },
                            onSubmitExam: { submittedDraft in
                                submitWritingExam(submittedDraft)
                            },
                            onNavigateBack: {
                                vm.storeDraft(vm.currentDraft)
                                // Remember that the user intentionally returned to Task 1 bank while keeping draft saved
                                mode = "学习_写作_Task1题库"
                            }
                        )
                    }
                case "学习_写作_Task2题库":
                    task2QuestionBankView
                case "学习_写作_历史作文", "学习_写作_评分反馈":
                    writingHistoryAndFeedbackView
                case "学习_统计":
                    studyStatisticsView
                default:
                    Task1QuestionBankHomeView(
                        allCatalogItems: Self.builtInPracticeQuestions,
                        onLaunchExam: { chosen in
                            launchExam(for: chosen, singleTask: false)
                        }
                    )
                }
            }
        }
        .fileImporter(isPresented: $importShown, allowedContentTypes: [.plainText, .utf8PlainText, .tabSeparatedText, .commaSeparatedText, .json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                importDraft = try VocabularyImportDraft(data: data, filename: url.lastPathComponent)
            } catch { vm.storageError = "导入失败，现有词库和记录未更改：\(error.localizedDescription)" }
        }
        .sheet(item: $importDraft) { draft in
            VocabularyImportReview(draft: draft, existing: allWords, onConfirm: saveImportedWords)
        }
        .sheet(item: $reviewSession) { session in
            WritingReviewPanel(session: session, onSave: saveWritingRevision)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: mode)
        .onAppear {
            vm.remember(mode)
            if mode == "学习_模拟机考" || mode == "学习_写作_模拟机考" {
                vm.startContinuousExamClockIfNeeded { expiredDraft in
                    submitWritingExam(expiredDraft)
                }
            }
        }
        .onChange(of: vm.dictationInput) { _, _ in vm.save() }
        .onChange(of: vm.currentDraft) { _, updated in vm.storeDraft(updated) }
        .onChange(of: vm.speechRateMultiplier) { _, _ in
            vm.save()
            if mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" {
                speakCurrentWord()
            }
        }
        .onChange(of: vm.selectedAccent) { _, _ in
            vm.save()
            if mode == "学习_听力_今日计划" || mode == "学习_听力_错词复习" {
                speakCurrentWord()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in vm.save() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in vm.save() }
        .onDisappear { if vm.clockOwner == clockToken { vm.clockOwner = nil }; vm.save(); ttsEngine.stop(); audio.stop() }
        .onChange(of: mode) { _, destination in
            vm.remember(destination)
            ttsEngine.stop()
            audio.stop()
            if destination == "学习_模拟机考" || destination == "学习_写作_模拟机考" {
                vm.startContinuousExamClockIfNeeded { expiredDraft in
                    submitWritingExam(expiredDraft)
                }
            }
        }
        .onReceive(audio.$errorMessage) { message in if let message { vm.dictationFeedback = message } }
        .task {
            if let service = vm.storeSnapshot.speechService, service.enabled { await audio.connect(service) }
        }
    }

    private func launchExam(for chosen: Task1QuestionItem, singleTask: Bool, forceNew: Bool = false) {
        vm.save()
        vm.selectedExamQuestion = chosen
        if !forceNew, let existing = vm.existingUnsubmittedDraft(for: chosen.id) {
            vm.currentDraft = existing
            vm.storeDraft(vm.currentDraft)
            mode = "学习_写作_模拟机考"
            return
        }
        vm.currentDraft = WritingExamDraftState(
            id: UUID(),
            questionID: chosen.id,
            examTitle: "\(chosen.id) · \(chosen.shortTitle)",
            activePart: vm.practiceSeconds == 2400 ? .part2 : .part1,
            part1EssayText: "",
            part2EssayText: "",
            remainingSeconds: vm.practiceSeconds,
            elapsedSeconds: 0,
            isPaused: false,
            isSingleTaskMode: vm.practiceSeconds != 3600,
            lastSavedAt: Date(),
            containsLegacyNonEnglishNotice: false
        )
        vm.storeDraft(vm.currentDraft)
        vm.startContinuousExamClockIfNeeded { expiredDraft in
            submitWritingExam(expiredDraft)
        }
        mode = "学习_写作_模拟机考"
    }

    private func submitWritingExam(_ submittedDraft: WritingExamDraftState) {
        guard !vm.storeSnapshot.writingSubmissions.contains(where: { $0.draftSessionID == submittedDraft.id }) else { mode = "学习_写作_历史作文"; return }
        let policy = ExamEnglishInputPolicy()
        let p1Words = policy.countIELTSWords(in: submittedDraft.part1EssayText)
        let p2Words = policy.countIELTSWords(in: submittedDraft.part2EssayText)
        let record = WritingSubmissionRecord(
            id: UUID(),
            draftSessionID: submittedDraft.id,
            questionID: submittedDraft.questionID,
            examTitle: submittedDraft.examTitle,
            part1EssayText: submittedDraft.part1EssayText,
            part2EssayText: submittedDraft.part2EssayText,
            part1WordCount: p1Words,
            part2WordCount: p2Words,
            durationSeconds: submittedDraft.elapsedSeconds,
            submittedAt: Date(),
            dateString: Self.todayDateString(),
            aiEvaluation: nil
        )
        vm.storeDraft(submittedDraft)
        vm.storeSnapshot.writingSubmissions.insert(record, at: 0)
        vm.save()
        mode = "学习_写作_评分反馈"
    }

    // MARK: - 1. Listening Shelf & Dictation Pod

    private func listeningCenterView(submode: DictationSessionMode) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Picker("词库", selection: Binding(
                        get: { vm.selectedDeck },
                        set: { newDeck in
                            selectDeckAndStartDictation(deck: newDeck, mode: vm.dictationMachine.mode, resume: true)
                        }
                    )) {
                        ForEach(Array(Set(allWords.map(\.deckID))).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Button(hasUnfinishedListeningSession ? "继续听写" : "开始听写") {
                        selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .newTask, resume: true)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                    Button("重新开始本轮") {
                        selectDeckAndStartDictation(deck: vm.selectedDeck, mode: vm.dictationMachine.mode, resume: false)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                    Button("错词复习") {
                        selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .wrongWordReview, resume: true)
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: vm.dictationMachine.mode == .wrongWordReview, horizontalPadding: 12, height: 32))
                    Button("停止播放") { ttsEngine.stop(); audio.stop() }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                    Button("听写专项设置", systemImage: "slider.horizontal.3") { vm.speechSettingsShown = true }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                        .sheet(isPresented: $vm.speechSettingsShown) {
                            SpeechSettingsPanel(audio: audio, settings: Binding(get: { vm.storeSnapshot.speechService ?? SpeechServiceSettings() }, set: { vm.storeSnapshot.speechService = $0; vm.save() }), voiceID: Binding(get: { vm.storeSnapshot.selectedVoiceIdentifier ?? "" }, set: { vm.storeSnapshot.selectedVoiceIdentifier = $0; vm.save() }), accent: Binding(get: { vm.selectedAccent }, set: { vm.selectedAccent = $0; vm.save() }), rate: Binding(get: { vm.speechRateMultiplier }, set: { vm.speechRateMultiplier = $0; vm.save() }), repeats: Binding(get: { vm.storeSnapshot.speechRepeatCount ?? 1 }, set: { vm.storeSnapshot.speechRepeatCount = $0; vm.save() }), interval: Binding(get: { vm.storeSnapshot.speechInterval ?? 0.5 }, set: { vm.storeSnapshot.speechInterval = $0; vm.save() }), voices: ttsEngine.availableVoices(for: vm.selectedAccent), onClose: { vm.save(); vm.speechSettingsShown = false })
                        }
                }.padding(.horizontal, 32)
                Text("今日已听写 \(DictationSessionStateMachine.todayDictatedWordCount(from: vm.storeSnapshot.dictationLogs, on: Self.todayDateString())) 个单词")
                    .font(.headline).padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text(vm.dictationMachine.mode == .wrongWordReview ? "错词复习" : vm.dictationMachine.mode == .stubbornWordReview ? "顽固单词复习" : "词汇听写")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(appearance.ink)
                        Spacer()
                        Picker("口音", selection: $vm.selectedAccent) {
                            Text("英式 (en-GB)").tag(TTSVoiceAccent.british)
                            Text("美式 (en-US)").tag(TTSVoiceAccent.american)
                        }
                        .frame(width: 175)

                        Picker("语速", selection: $vm.speechRateMultiplier) {
                            Text("0.85x 慢速").tag(Float(0.85))
                            Text("1.0x 标准").tag(Float(1.0))
                            Text("1.15x 进阶").tag(Float(1.15))
                            Text("1.5x").tag(Float(1.5))
                            Text("1.8x").tag(Float(1.8))
                        }
                        .frame(width: 125)

                        Button("重播声音") { speakCurrentWord() }.keyboardShortcut("r", modifiers: [.command])
                            .buttonStyle(.borderedProminent)
                            .tint(appearance.accent)
                    }

                    if let word = vm.dictationMachine.currentWord {
                        let errorCount = vm.dictationMachine.sessionErrorCounts[word.id, default: 0]
                        Button("不熟悉 · 显示中文") { vm.showMeaning = true; vm.save() }
                        if vm.showMeaning { Text(word.definitionZH) }
                        if vm.dictationMachine.requiresCorrection {
                            Button("查看拼写后订正") { vm.revealedWordID = word.id; vm.save() }
                            if vm.revealedWordID == word.id { Text(word.word).font(.headline).textSelection(.enabled) }
                        }
                        Text("今日累计错误：\(errorCount) 次 · 第 6 次进入顽固单词").font(.system(size: 13))
                            .foregroundStyle(appearance.ink.opacity(0.85))

                        HStack(spacing: 12) {
                            TextField("听音后输入英文单词...", text: $vm.dictationInput)
                                .focused($answerFocused)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    submitCurrentDictation()
                                }

                            Button("提交核对") {
                                submitCurrentDictation()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        ProgressView(value: Double(vm.dictationMachine.completedWordIDs.count), total: Double(max(1, vm.dictationMachine.completedWordIDs.count + vm.dictationMachine.pendingQueue.count)))
                        Text("剩余 \(vm.dictationMachine.pendingQueue.count) 个 · 已完成 \(vm.dictationMachine.completedWordIDs.count) 个（切换看书或写作后返回将自动继续本进度）").font(.caption).foregroundStyle(.secondary)
                    } else {
                        DictationReportView(session: vm.dictationMachine)
                    }

                    Text(vm.dictationFeedback)
                        .font(.system(size: 12.5))
                        .foregroundStyle(appearance.ink.opacity(0.78))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(appearance.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(appearance.line, lineWidth: 1))
                )
                .padding(.horizontal, 32)
            }
        }
        .background(appearance.paper)
    }

    private var stubbornWordsDedicatedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("顽固单词")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(appearance.ink)
            Text("当日累计第 6 次答错进入顽固单词，当前词订正后不再自动循环；按错误次数从高到低排序，独立记录复习会话。")
                .font(.system(size: 13))
                .foregroundStyle(appearance.ink.opacity(0.7))

            if vm.storeSnapshot.stubbornWords.isEmpty {
                Text("暂无顽固单词记录。")
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.ink.opacity(0.6))
                    .padding(.top, 20)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(vm.storeSnapshot.stubbornWords.sorted { $0.errorCount > $1.errorCount }) { rec in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rec.word)
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundStyle(appearance.ink)
                                    Text("所属原词库：\(rec.sourceDeckTitle) · 记录日期：\(rec.dateString)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(appearance.ink.opacity(0.65))
                                }
                                Spacer()
                                Button("复习此词库") {
                                    selectDeckAndStartDictation(deck: rec.sourceDeckID, mode: .stubbornWordReview, resume: true)
                                    mode = "学习_听力_今日计划"
                                }
                                Text("错误 \(rec.errorCount) 次")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(appearance.accent)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 10).fill(appearance.surface))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(appearance.paper)
    }

    private var listeningRecordsDedicatedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("听力学习记录")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(appearance.ink)
            if vm.storeSnapshot.dictationLogs.isEmpty {
                Text("今日尚无听写记录，前往「听力 -> 今日计划」开始练习后将自动记录。")
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.ink.opacity(0.65))
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.storeSnapshot.dictationLogs) { log in
                            HStack {
                                Text(log.word)
                                    .font(.system(size: 15, weight: .semibold, design: .serif))
                                    .foregroundStyle(appearance.ink)
                                Text("输入:\(log.userTyped)")
                                    .font(.system(size: 12.5, design: .monospaced))
                                    .foregroundStyle(appearance.ink.opacity(0.75))
                                Spacer()
                                Text(log.isCorrect ? "✓ 正确" : "✕ 错误 (第\(log.sessionErrorCountForWord)次)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(log.isCorrect ? .green : .pink)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(appearance.surface))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(appearance.paper)
    }

    // MARK: - 2. Task 2 Bank & Writing History / AI Feedback Views

    private var task2QuestionBankView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Task 2 议论文题库")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(appearance.ink)
            Text("双击任意题目进入 40 分钟 / 250 词纯英文无纠错写作机考（如有未交卷草稿将自动恢复继续写作）")
                .font(.system(size: 13))
                .foregroundStyle(appearance.ink.opacity(0.68))

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Self.builtInPracticeQuestions) { item in
                        let existingDraft = vm.existingUnsubmittedDraft(for: item.id)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(item.companionTask2ID ?? "T2") · \(item.shortTitle)")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundStyle(appearance.accent)
                                Spacer()
                                if let existingDraft {
                                    Text("进行中 · 剩余 \(existingDraft.remainingSeconds / 60) 分钟（双击继续）")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(appearance.accent)
                                } else {
                                    Text("建议 40 分钟 · 至少 250 词")
                                        .font(.system(size: 12))
                                        .foregroundStyle(appearance.ink.opacity(0.6))
                                }
                            }
                            Text(item.companionTask2Prompt ?? "")
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(appearance.ink.opacity(0.92))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(appearance.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(appearance.line, lineWidth: 1))
                        )
                        .onTapGesture(count: 2) {
                            let hadExisting = vm.existingUnsubmittedDraft(for: item.id) != nil
                            launchExam(for: item, singleTask: false)
                            if !hadExisting {
                                vm.currentDraft.activePart = .part2
                                vm.storeDraft(vm.currentDraft)
                            }
                        }
                    }
                }
            }
        }
        .padding(32)
        .background(appearance.paper)
    }

    private var writingHistoryAndFeedbackView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("历史作文与 AI 评分反馈")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(appearance.ink)
            Text("作文优先保存到本机。评分需主动发送至已配置的 AI 服务，结果仅供练习参考。")
                .font(.system(size: 12.5))
                .foregroundStyle(.yellow.opacity(0.9))

            if vm.storeSnapshot.writingSubmissions.isEmpty {
                Text("暂无已提交的历史作文。双击 Task 1 题卡完成练习并点击「交卷」后在此查看四项评分与逐句纠错。")
                    .font(.system(size: 14))
                    .foregroundStyle(appearance.ink.opacity(0.65))
                    .padding(.top, 16)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(vm.storeSnapshot.writingSubmissions) { sub in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(sub.examTitle)
                                        .font(.system(size: 17, weight: .bold, design: .serif))
                                        .foregroundStyle(appearance.ink)
                                    Spacer()
                                    if sub.aiEvaluation == nil { Text("待评分") }
                                    if let eval = sub.aiEvaluation {
                                        Text(String(format: "AI 估计总分: Band %.1f", eval.overallEstimatedBand))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(appearance.accent)
                                    }
                                }
                                HStack {
                                    Button("修改对照与重写") {
                                        let saved = vm.storeSnapshot.writingRevisions?.filter { $0.submissionID == sub.id }.max { $0.updatedAt < $1.updatedAt }
                                        reviewSession = WritingReviewSession(original: sub, revision: saved ?? WritingRevision(original: sub))
                                    }
                                    Button("新建重写版本") { reviewSession = WritingReviewSession(original: sub, revision: WritingRevision(original: sub)) }
                                    Text("\((vm.storeSnapshot.writingRevisions ?? []).filter { $0.submissionID == sub.id }.count) 个重写版本").font(.caption)
                                }
                                ForEach((vm.storeSnapshot.writingRevisions ?? []).filter { $0.submissionID == sub.id }.sorted { $0.updatedAt > $1.updatedAt }) { revision in
                                    Button("打开重写 · \(revision.updatedAt.formatted(date: .abbreviated, time: .shortened))") {
                                        reviewSession = WritingReviewSession(original: sub, revision: revision)
                                    }
                                }
                                Text(sub.part1EssayText + "\n\n" + sub.part2EssayText).textSelection(.enabled)
                                if let evaluateWriting, let question = Self.builtInPracticeQuestions.first(where: { $0.id == sub.questionID }) {
                                    Button(vm.evaluatingSubmission == sub.id ? "评估中..." : "发送此作文至已配置 AI 评估") {
                                        vm.evaluatingSubmission = sub.id
                                        Task {
                                            defer { vm.evaluatingSubmission = nil }
                                            do {
                                                let evaluation = try await evaluateWriting(sub, question)
                                                if let index = vm.storeSnapshot.writingSubmissions.firstIndex(where: { $0.id == sub.id }) {
                                                    vm.storeSnapshot.writingSubmissions[index].aiEvaluation = evaluation; vm.save()
                                                }
                                            } catch { vm.storageError = "评分未完成，原作已保留：\(error.localizedDescription)" }
                                        }
                                    }.disabled(vm.evaluatingSubmission == sub.id)
                                }
                                if let evaluation = sub.aiEvaluation {
                                    Text(String(format: "TA/TR %.1f · CC %.1f · LR %.1f · GRA %.1f", evaluation.taskAchievementOrResponse, evaluation.coherenceAndCohesion, evaluation.lexicalResource, evaluation.grammaticalRangeAndAccuracy)).font(.caption)
                                    Text("AI 练习估分，非官方成绩。").font(.caption).foregroundStyle(.secondary)
                                    ForEach(Array(evaluation.sentenceCorrections.enumerated()), id: \.offset) { _, correction in
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(correction.originalSentence).foregroundStyle(.secondary)
                                            Text(correction.correctedSentence)
                                            Text(correction.explanationZH).font(.callout)
                                        }.textSelection(.enabled).padding(.vertical, 6)
                                    }
                                }
                                Text("提交日期：\(sub.dateString) · Part 1 字数：\(sub.part1WordCount) · Part 2 字数：\(sub.part2WordCount) · 用时：\(sub.durationSeconds / 60) 分钟")
                                    .font(.system(size: 12))
                                    .foregroundStyle(appearance.ink.opacity(0.7))
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(appearance.surface))
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .background(appearance.paper)
    }

    private var studyHome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("学习").font(.largeTitle)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 20) {
                homeCard(
                    hasUnfinishedListeningSession ? "词汇听写（继续练习）" : "词汇听写",
                    symbol: "headphones",
                    destination: hasUnfinishedListeningSession ? (vm.dictationMachine.mode == .wrongWordReview ? "学习_听力_错词复习" : "学习_听力_今日计划") : "学习_听力"
                )
                homeCard("学习统计", symbol: "chart.bar", destination: "学习_统计")
                homeCard(
                    hasUnfinishedWritingDraft ? "雅思写作（继续草稿）" : "雅思写作",
                    symbol: "pencil",
                    destination: hasUnfinishedWritingDraft ? "学习_写作_模拟机考" : "学习_写作_Task1题库"
                )
            }
            Spacer()
        }.padding(32)
    }

    private func homeCard(_ title: String, symbol: String, destination: String) -> some View {
        Button { mode = destination } label: {
            VStack(spacing: 20) { Image(systemName: symbol).font(.largeTitle); Text(title).font(.headline) }
                .frame(maxWidth: .infinity, minHeight: 180).background(appearance.surface, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }

    private var listeningHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) { Text("听力").font(.largeTitle); Text("选择词库，听音默写（未完成词库点击自动继续上次进度）").foregroundStyle(.secondary) }
                    Spacer()
                    TextField("搜索词库", text: $deckSearch).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    Button("导入 TXT / 词库", systemImage: "square.and.arrow.down") { importShown = true }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 34))
                }
                Text("支持 TXT 智能中英文识别（正向/反向/混合分隔符/跨行配对/自动过滤标题与例句）、UTF-8/BOM/GB18030 编码、TSV 及 JSON 导入；导入前提供可编辑预览。")
                    .font(.caption)
                    .foregroundStyle(appearance.ink.opacity(0.68))
                HStack {
                    Picker("复习词库", selection: $vm.selectedDeck) {
                        ForEach(Array(Set(allWords.map(\.deckID))).sorted(), id: \.self) { deck in
                            Text(allWords.first { $0.deckID == deck }?.deckTitle ?? deck).tag(deck)
                        }
                    }.frame(maxWidth: 260)
                    Text("到期 \(dueReviewCount) 个").font(.caption)
                    Button("开始到期复习") {
                        selectDeckAndStartDictation(deck: vm.selectedDeck, mode: .wrongWordReview, resume: true, dueOnly: true)
                        mode = "学习_听力_错词复习"
                    }.disabled(dueReviewCount == 0)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 24)], alignment: .leading, spacing: 24) {
                    ForEach(Array(Set(allWords.map(\.deckID))).sorted(), id: \.self) { deck in
                        let words = allWords.filter { $0.deckID == deck }
                        let title = words.first?.deckTitle ?? deck
                        let key = HostStateModel.sessionKey(mode: .newTask, date: Self.todayDateString(), deck: deck)
                        let savedSession = (vm.dictationMachine.mode == .newTask && (vm.dictationMachine.currentWord?.deckID ?? vm.selectedDeck) == deck) ? vm.dictationMachine : vm.storeSnapshot.dictationSessions?[key]
                        if deckSearch.isEmpty || title.localizedStandardContains(deckSearch) {
                            Button {
                                selectDeckAndStartDictation(deck: deck, mode: .newTask, resume: true)
                                mode = "学习_听力_今日计划"
                                answerFocused = true
                            } label: {
                                VStack(alignment: .leading, spacing: 16) {
                                    Image(systemName: "headphones").font(.system(size: 30, weight: .light))
                                    Spacer()
                                    Text(title).font(.title3.weight(.medium)).multilineTextAlignment(.leading)
                                    if let savedSession, !savedSession.isSessionFinished, (!savedSession.completedWordIDs.isEmpty || !savedSession.attemptLogs.isEmpty) {
                                        Text("进行中：已完成 \(savedSession.completedWordIDs.count)/\(savedSession.completedWordIDs.count + savedSession.pendingQueue.count) 词 · 点击继续")
                                            .font(.caption)
                                            .foregroundStyle(appearance.accent)
                                    } else {
                                        Text("\(words.count) 个词").font(.caption)
                                    }
                                    if deck == "vocab_daily" { Text("内置示例词库").font(.caption2).foregroundStyle(.secondary) }
                                }.padding(22).frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
                                    .background(appearance.secondaryGradient, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(appearance.line, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(32)
        }.background(appearance.paper)
    }

    private var dueReviewCount: Int {
        let wrong = Set(vm.storeSnapshot.dictationLogs.filter { !$0.isCorrect }.map(\.wordID))
        let quarantined = Set(vm.storeSnapshot.stubbornWords.filter { $0.dateString == Self.todayDateString() }.map(\.wordID))
        return allWords.filter { $0.deckID == vm.selectedDeck && wrong.contains($0.id) && !quarantined.contains($0.id) && (vm.storeSnapshot.reviewSchedule?[$0.id]?.dueAt ?? .distantPast) <= Date() }.count
    }

    private func selectDeckAndStartDictation(deck: String, mode: DictationSessionMode, resume: Bool = true, dueOnly: Bool = false) {
        // Save the outgoing deck/session BEFORE changing vm.selectedDeck so we never clobber the target deck's session!
        vm.save()
        let activeDeck = vm.dictationMachine.currentWord?.deckID ?? vm.dictationMachine.attemptLogs.last?.deckID ?? vm.selectedDeck
        if resume && activeDeck == deck && vm.dictationMachine.mode == mode && vm.dictationMachine.dateString == Self.todayDateString() && !vm.dictationMachine.isSessionFinished {
            vm.selectedDeck = deck
            vm.save()
            speakCurrentWord()
            return
        }
        vm.selectedDeck = deck
        startDictation(mode: mode, resume: resume, dueOnly: dueOnly)
    }

    private func startDictation(mode: DictationSessionMode, resume: Bool = false, dueOnly: Bool = false) {
        let key = HostStateModel.sessionKey(mode: mode, date: Self.todayDateString(), deck: vm.selectedDeck)
        if resume, let saved = vm.storeSnapshot.dictationSessions?[key], !saved.isSessionFinished {
            vm.dictationMachine = saved
            let state = vm.storeSnapshot.workspace
            if let currentWordID = saved.currentWord?.id {
                if state?.deckInputWordIDs?[key] == currentWordID {
                    vm.dictationInput = state?.deckInputs?[key] ?? ""
                    vm.showMeaning = state?.deckShowMeaning?[key] ?? false
                    vm.revealedWordID = state?.deckRevealedWordIDs?[key]
                } else if state?.inputWordID == currentWordID {
                    vm.dictationInput = state?.dictationInput ?? ""
                    vm.showMeaning = state?.showMeaning ?? false
                    vm.revealedWordID = state?.revealedWordID
                } else {
                    vm.dictationInput = ""
                    vm.showMeaning = false
                    vm.revealedWordID = nil
                }
            } else {
                vm.dictationInput = ""
                vm.showMeaning = false
                vm.revealedWordID = nil
            }
            vm.save()
            speakCurrentWord()
            return
        }
        let stubbornIDs = Set(vm.storeSnapshot.stubbornWords.map(\.wordID))
        let wrongIDs = Set(vm.storeSnapshot.dictationLogs.filter { !$0.isCorrect }.map(\.wordID))
        let words = allWords.filter {
            $0.deckID == vm.selectedDeck &&
            (mode == .newTask || (mode == .stubbornWordReview ? stubbornIDs.contains($0.id) : wrongIDs.contains($0.id))) &&
            (!dueOnly || (vm.storeSnapshot.reviewSchedule?[$0.id]?.dueAt ?? .distantPast) <= Date())
        }
        vm.dictationMachine = DictationSessionStateMachine(
            mode: mode,
            dateString: Self.todayDateString(),
            initialWords: words,
            existingStubbornWordsForToday: vm.storeSnapshot.stubbornWords,
            previousLogs: vm.storeSnapshot.dictationLogs
        )
        vm.showMeaning = false
        vm.revealedWordID = nil
        vm.dictationInput = ""
        vm.save()
        speakCurrentWord()
    }

    private func speakCurrentWord() {
        guard let word = vm.dictationMachine.currentWord else { return }
        if let service = vm.storeSnapshot.speechService, service.enabled {
            ttsEngine.stop()
            let next = vm.dictationMachine.pendingQueue.dropFirst().map(\.word)
            audio.play(text: word.word, next: Array(next), settings: service, speed: vm.speechRateMultiplier, repeats: vm.storeSnapshot.speechRepeatCount ?? 1, interval: vm.storeSnapshot.speechInterval ?? 0.5)
            return
        }
        audio.stop()
        let voices = ttsEngine.availableVoices(for: vm.selectedAccent)
        let selected = voices.first { $0.id == vm.storeSnapshot.selectedVoiceIdentifier }
        let voice = selected ?? ttsEngine.selectBestFemaleVoice(
            preferredVoiceID: vm.storeSnapshot.selectedVoiceIdentifier,
            accent: vm.selectedAccent
        )
        ttsEngine.repeatCount = vm.storeSnapshot.speechRepeatCount ?? 1
        ttsEngine.repeatInterval = vm.storeSnapshot.speechInterval ?? 0.5
        ttsEngine.speak(text: word.word, voice: voice, requestedRate: vm.speechRateMultiplier)
    }

    private func submitCurrentDictation() {
        guard !vm.dictationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { vm.dictationFeedback = "请输入听到的单词后提交。"; return }
        guard let word = vm.dictationMachine.currentWord, let outcome = vm.dictationMachine.submitAnswer(vm.dictationInput) else { return }
        if let log = vm.dictationMachine.attemptLogs.last {
            vm.storeSnapshot.dictationLogs.append(log)
            if !log.isCorrect || vm.dictationMachine.completedWordIDs.contains(word.id) {
                var progress = vm.storeSnapshot.reviewSchedule?[word.id] ?? WordReviewProgress(dueAt: Date())
                progress.record(cleanRecall: log.isCorrect, at: Date())
                if vm.storeSnapshot.reviewSchedule == nil { vm.storeSnapshot.reviewSchedule = [:] }
                vm.storeSnapshot.reviewSchedule?[word.id] = progress
            }
        }
        for record in vm.dictationMachine.sortedStubbornWords {
            vm.storeSnapshot.stubbornWords.removeAll { $0.wordID == record.wordID && $0.dateString == record.dateString }
            vm.storeSnapshot.stubbornWords.append(record)
        }
        vm.showMeaning = false
        vm.revealedWordID = nil
        vm.dictationInput = ""
        vm.save()
        answerFocused = true
        switch outcome {
        case .needsCorrection(let count):
            vm.dictationFeedback = "拼写有误，今日第 \(count) 次。请订正当前词，拼对后才能继续。"
        case .correct(let exited):
            vm.dictationFeedback = exited ? "✓ 独立拼对，已通过本轮复习。" : "✓ 拼写正确。"
            speakCurrentWord()
        case .requeuedForRetry(_, let offset):
            vm.dictationFeedback = "✓ 已订正；随机安排在后续第 \(offset + 1) 个任务，再次独立拼对才能通过。"
            speakCurrentWord()
        case .promotedToStubbornWords:
            vm.dictationFeedback = "今日已超过 5 次错误，已进入顽固单词。拼对当前词后继续，不再自动循环。"
        }
    }

    private func saveImportedWords(_ words: [VocabularyWord]) -> String? {
        guard !words.isEmpty else { return "没有可导入的词条，原词库保持不变。" }
        var existing = vm.storeSnapshot.importedWords ?? []
        let existingKeys = Set(existing.map { "\($0.deckID)|\($0.word.lowercased())" })
        for w in words {
            let key = "\(w.deckID)|\(w.word.lowercased())"
            if !existingKeys.contains(key) {
                existing.append(w)
            } else if let idx = existing.firstIndex(where: { $0.deckID == w.deckID && $0.word.lowercased() == w.word.lowercased() }) {
                // Update definition while preserving original word ID so wrong-word records and review progress stay linked
                let preservedID = existing[idx].id
                existing[idx] = VocabularyWord(id: preservedID, word: w.word, definitionZH: w.definitionZH, deckID: w.deckID, deckTitle: w.deckTitle)
            }
        }
        vm.storeSnapshot.importedWords = existing
        if let firstDeck = words.first?.deckID {
            vm.selectedDeck = firstDeck
            // Refresh current dictation session for the imported deck while preserving wrong-word records & history
            startDictation(mode: .newTask, resume: false)
        }
        return vm.save() ? nil : (vm.storageError ?? "保存失败，请重试。")
    }

    private func saveWritingRevision(_ revision: WritingRevision) -> String? {
        var revisions = vm.storeSnapshot.writingRevisions ?? []
        revisions.removeAll { $0.id == revision.id }; revisions.append(revision)
        vm.storeSnapshot.writingRevisions = revisions
        return vm.save() ? nil : (vm.storageError ?? "重写稿保存失败，请重试。")
    }

    // MARK: - 3. Study Statistics View (全部 | 听力 | 写作 + 今天 | 7天 | 30天 | 全部时间)

    private var studyStatisticsView: some View {
        let allowedDates: Set<String>? = {
            let count: Int
            switch vm.statsTimeWindow { case .allTime: return nil; case .today: count = 1; case .last7Days: count = 7; case .last30Days: count = 30 }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
            return Set((0..<count).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }.map { formatter.string(from: $0) })
        }()
        let overview = StudyStatisticsCalculator.computeOverview(
            dictationLogs: vm.storeSnapshot.dictationLogs,
            writingSubmissions: vm.storeSnapshot.writingSubmissions, allowedDates: allowedDates
        )
        let listeningStats = StudyStatisticsCalculator.computeListening(
            dictationLogs: vm.storeSnapshot.dictationLogs,
            stubbornWords: vm.storeSnapshot.stubbornWords.sorted { $0.errorCount > $1.errorCount }, allowedDates: allowedDates
        )
        let writingStats = StudyStatisticsCalculator.computeWriting(
            submissions: vm.storeSnapshot.writingSubmissions, allowedDates: allowedDates
        )

        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("学习统计")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(appearance.ink)
                Spacer()
                Picker("模块", selection: $vm.statsScope) {
                    ForEach(StudyStatisticsScope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)

                Picker("时间范围", selection: $vm.statsTimeWindow) {
                    ForEach(StudyStatsTimeWindow.allCases, id: \.self) { w in
                        Text(w.rawValue).tag(w)
                    }
                }
                .frame(width: 150)
            }

            if vm.statsScope == .all {
                HStack(spacing: 16) {
                    statCard(title: "真实总学习时长", value: "\(overview.totalStudySeconds / 60) 分钟", subtitle: "听力 \(overview.listeningStudySeconds / 60) 分钟 + 写作 \(overview.writingStudySeconds / 60) 分钟 (绝不把单词数动作文数) ")
                    statCard(title: "连续学习天数", value: "\(overview.streakDays) 天", subtitle: overview.isEmpty ? "暂无学习会话记录" : "基于本地持久化会话计算")
                }
            } else if vm.statsScope == .listening {
                HStack(spacing: 16) {
                    statCard(title: "听写完成单词数", value: "\(listeningStats.completedUniqueWordsCount) 词", subtitle: "总错误次数：\(listeningStats.totalErrorCount)")
                    statCard(title: "首次正确率", value: String(format: "%.1f%%", listeningStats.firstAttemptAccuracyPercent), subtitle: "顽固单词数：\(listeningStats.stubbornWordsCount)")
                }
            } else {
                HStack(spacing: 16) {
                    statCard(title: "完成作文篇数", value: "\(writingStats.totalSubmissionsCount) 篇", subtitle: "Task 1: \(writingStats.task1Count) 篇 · Task 2: \(writingStats.task2Count) 篇")
                    statCard(title: "平均字数与 AI 估计均分", value: "\(writingStats.averageWordCount) 词", subtitle: "AI 估计均分：\(writingStats.averageEstimatedBand.map { String(format: "Band %.1f", $0) } ?? "暂无数据")")
                }
            }

            Spacer()
        }
        .padding(32)
        .background(appearance.paper)
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(appearance.ink.opacity(0.7))
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(appearance.ink)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(appearance.ink.opacity(0.65))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(appearance.surface))
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Built-in Data

    public static let builtInVocabularyWords: [VocabularyWord] = [
        VocabularyWord(id: "vw-001", word: "abandon", definitionZH: "v. 放弃，遗弃", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-002", word: "capacity", definitionZH: "n. 容量；能力", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-003", word: "fluctuate", definitionZH: "v. 波动，起伏", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-004", word: "sustainable", definitionZH: "adj. 可持续的", deckID: "vocab_daily", deckTitle: "每日必备核心词"),
        VocabularyWord(id: "vw-005", word: "inevitable", definitionZH: "adj. 不可避免的", deckID: "vocab_daily", deckTitle: "每日必备核心词")
    ]

    public static let builtInPracticeQuestions: [Task1QuestionItem] = [
        Task1QuestionItem(
            id: "ORIG-001",
            shortTitle: "城市用电量",
            category: .lineGraph,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The line graph below shows electricity consumption (in gigawatt-hours) in four different cities from 2010 to 2024. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2010", "2015", "2020", "2024"],
                series: [
                    ChartSeries(name: "Metropolis A", unit: "GWh", values: [450, 520, 610, 680]),
                    ChartSeries(name: "Coastal City B", unit: "GWh", values: [300, 310, 330, 360]),
                    ChartSeries(name: "Industrial Hub C", unit: "GWh", values: [600, 580, 540, 510]),
                    ChartSeries(name: "Town D", unit: "GWh", values: [120, 150, 210, 290])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-001",
            companionTask2Prompt: "Some people believe that governments should heavily tax high-energy-consuming industries to reduce overall consumption. To what extent do you agree or disagree?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-002",
            shortTitle: "家庭预算支出分布",
            category: .pieChart,
            difficultyBand: "Band 6.0-7.0",
            promptText: "The pie chart illustrates the average proportion of monthly expenditure spent by households in Country X in 2023. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: [
                    "Housing & Utilities": 32,
                    "Food & Groceries": 22,
                    "Transport": 15,
                    "Leisure & Entertainment": 12,
                    "Savings & Investments": 11,
                    "Other": 8
                ],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-002",
            companionTask2Prompt: "In many countries, people are spending a larger share of their income on housing. What are the causes of this trend, and what effects does it have on society?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-003",
            shortTitle: "岛屿改造对比",
            category: .map,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The maps show a small island before and after the construction of tourist facilities. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeTitle: "Before Development (2010)",
                    afterTitle: "After Development (2024)",
                    beforeFeatures: [
                        MapStageFeature(label: "Natural palm trees & beach", region: "West Coast", status: "retained"),
                        MapStageFeature(label: "Empty central grassland", region: "Center", status: "modified"),
                        MapStageFeature(label: "Small fishing pier", region: "South Coast", status: "removed")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Reception building & restaurant", region: "Center", status: "added"),
                        MapStageFeature(label: "Western accommodation huts with footpaths", region: "West Coast", status: "added"),
                        MapStageFeature(label: "Eastern luxury villas with vehicle track", region: "East Coast", status: "added"),
                        MapStageFeature(label: "Expanded marina & boat slipway", region: "South Coast", status: "added"),
                        MapStageFeature(label: "Swimming zone & water sports center", region: "North Coast", status: "added")
                    ]
                ),
                processSteps: nil
            ),
            companionTask2ID: "T2-003",
            companionTask2Prompt: "Tourism brings economic benefits to remote island communities, but it can also harm local environments. Do the advantages of island tourism outweigh its disadvantages?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-004",
            shortTitle: "咖啡豆加工全流程",
            category: .processDiagram,
            difficultyBand: "Band 6.0-7.0",
            promptText: "The diagram below illustrates the stages involved in the production of commercial roasted coffee from raw cherries. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Hand Harvesting", detail: "Ripe red coffee cherries are hand-picked in high-altitude orchards.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Pulping & Fermentation", detail: "Outer skin removed; beans fermented in water tanks for 24 hours.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Sun Drying", detail: "Beans spread on raised beds and dried in sunlight for 7-10 days.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Hulling & Sorting", detail: "Parchment layer removed; green beans sorted by size and color.", nextStepNumber: 5),
                    ProcessStepPayload(stepNumber: 5, title: "Industrial Roasting", detail: "Beans roasted at 220°C until dark brown, then rapidly cooled.", nextStepNumber: 6),
                    ProcessStepPayload(stepNumber: 6, title: "Vacuum Packaging", detail: "Roasted whole beans packaged in sealed bags for international export.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-004",
            companionTask2Prompt: "Fair-trade initiatives advocate paying higher prices to agricultural producers in developing nations. Is this an effective approach to tackling global inequality?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-005",
            shortTitle: "4国图书馆资源对比",
            category: .table,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The table below compares public library resources and annual visits per capita across four different countries in 2022. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Print Books (per 1k)", "Digital Titles (per 1k)", "Annual Visits per Capita", "PC Workstations (per branch)"],
                series: [
                    ChartSeries(name: "Country Alpha", unit: "count", values: [3200, 1800, 6.2, 24]),
                    ChartSeries(name: "Country Beta", unit: "count", values: [2100, 2900, 7.8, 40]),
                    ChartSeries(name: "Country Gamma", unit: "count", values: [4500, 800, 3.9, 12]),
                    ChartSeries(name: "Country Delta", unit: "count", values: [1900, 3400, 8.4, 48])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: ["Average": 2925, "Median": 2650],
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-005",
            companionTask2Prompt: "With the widespread availability of digital media, some people argue that traditional public libraries are a waste of taxpayer money. Do you agree or disagree?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-006",
            shortTitle: "全流程复合图 · 水循环与供水系统",
            category: .mixedChart,
            difficultyBand: "Band 7.0-8.0",
            promptText: "The line chart shows annual rainfall (mm) in a region over five years, while the process diagram shows the water purification and distribution system. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2019", "2020", "2021", "2022", "2023"],
                series: [
                    ChartSeries(name: "Annual Rainfall", unit: "mm", values: [820, 640, 910, 750, 580])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Reservoir Collection", detail: "Surface runoff captured in primary mountain reservoir.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Flocculation & Sand Filtration", detail: "Chemical coagulants added; water passed through multi-layer sand beds.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Chlorination & Storage", detail: "Disinfected with chlorine gas and pumped to elevated municipal storage towers.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Mains Supply", detail: "Distributed via gravity-fed underground pipe network to residential and industrial users.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-006",
            companionTask2Prompt: "Water scarcity is becoming a global issue. Should water consumption be strictly rationed by law, or should market pricing be used to manage demand?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-007",
            shortTitle: "风力发电与化石能源占比",
            category: .lineGraph,
            difficultyBand: "Band 6.5-7.5",
            promptText: "The line graph shows the percentage of electricity generated from wind power compared to fossil fuels in Country Y between 2005 and 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2005", "2010", "2015", "2020", "2025"],
                series: [
                    ChartSeries(name: "Wind Power", unit: "%", values: [3, 9, 21, 38, 54]),
                    ChartSeries(name: "Fossil Fuels", unit: "%", values: [82, 74, 59, 42, 28])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-007",
            companionTask2Prompt: "Some argue that renewable energy generation is unreliable and governments should continue investing in nuclear power. Discuss both views and give your opinion.",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-008",
            shortTitle: "大学毕业生就业分布",
            category: .pieChart,
            difficultyBand: "Band 6.0-7.0",
            promptText: "The pie charts illustrate the career outcomes of university graduates from University Z in 2015 and 2023. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: [
                    "Full-time Employment": 58,
                    "Further Study / Research": 18,
                    "Part-time Employment": 10,
                    "Self-employed / Freelance": 9,
                    "Unemployed / Seeking Work": 5
                ],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-008",
            companionTask2Prompt: "Many university graduates are unable to find jobs related to their degree fields. Why is this happening, and what measures can universities take to address this problem?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-009",
            shortTitle: "城市海滨公园规划变迁",
            category: .map,
            difficultyBand: "Band 7.0-8.0",
            promptText: "The maps show the layout of a coastal city park in 1980 and the proposed redevelopment plan for 2026. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: [],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeTitle: "Existing Park Layout (1980)",
                    afterTitle: "Proposed Redevelopment (2026)",
                    beforeFeatures: [
                        MapStageFeature(label: "Surface car park", region: "North-West", status: "removed"),
                        MapStageFeature(label: "Open lawn & rose garden", region: "Center", status: "retained"),
                        MapStageFeature(label: "Disused Bandstand", region: "East", status: "removed")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Underground parking & EV chargers", region: "North-West", status: "added"),
                        MapStageFeature(label: "Open-air amphitheatre", region: "East", status: "added"),
                        MapStageFeature(label: "Expanded wetlands pond & boardwalk", region: "South", status: "expanded"),
                        MapStageFeature(label: "Playground & fitness zone", region: "East", status: "added"),
                        MapStageFeature(label: "Community cafe & cycle racks", region: "North", status: "added")
                    ]
                ),
                processSteps: nil
            ),
            companionTask2ID: "T2-010",
            companionTask2Prompt: "Public parks and green spaces are essential for urban residents' physical and mental wellbeing. How can city planners balance green spaces with the need for commercial and residential buildings?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-011",
            shortTitle: "Solar panel recycling",
            category: .processDiagram,
            difficultyBand: "Band 7.0-8.0",
            promptText: "The diagram below illustrates the closed-loop industrial process for recycling end-of-life photovoltaic solar panels into purified raw materials. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://howtodoielts.com/ielts-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1", "2", "3", "4", "5"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Frame Dismantling", detail: "Aluminum frames and junction boxes are detached.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Thermal Delamination", detail: "500°C furnace evaporates encapsulating polymer.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Optical Glass Separation", detail: "95% glass cullet separated on vibrating conveyors.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Chemical Metal Leaching", detail: "Acid leaching extracts silver and copper.", nextStepNumber: 5),
                    ProcessStepPayload(stepNumber: 5, title: "Wafer Ingot Recasting", detail: "Purified silicon melted into new solar ingots.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-011",
            companionTask2Prompt: "While renewable energy technologies reduce carbon emissions, their manufacturing and disposal also create environmental challenges. To what extent should manufacturers be legally responsible for recycling their products?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-012",
            shortTitle: "Renewable energy & storage",
            category: .mixedChart,
            difficultyBand: "Band 7.5-8.5",
            promptText: "The line graph below shows renewable electricity generation (in TWh) from wind, solar, and hydro in a Nordic country from 2010 to 2025, while the pie chart shows the share of grid battery storage capacity by sector in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["2010", "2015", "2020", "2025"],
                series: [
                    ChartSeries(name: "Hydropower", unit: "TWh", values: [62, 65, 68, 70]),
                    ChartSeries(name: "Wind Power", unit: "TWh", values: [6, 16, 29, 44]),
                    ChartSeries(name: "Solar PV", unit: "TWh", values: [0.5, 2.0, 6.5, 15.0])
                ],
                pieSlicePercentages: ["Utility Grid": 52, "Industrial": 28, "Residential": 20],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-012",
            companionTask2Prompt: "Some people argue that transitioning completely to renewable energy is too expensive for developing economies. Discuss both views and give your own opinion.",
            notes: nil
        )
    ]
}
#endif
