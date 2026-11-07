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
        var persistence: StudyPersistenceManager?
        init(storageDirectory:URL? = nil) {
            do {
                let directory:URL
                if let storageDirectory { directory = storageDirectory }
                else { directory = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("LumaReader/StudyCenter",isDirectory:true) }
                let manager = try StudyPersistenceManager(storageDirectory:directory)
                let saved = try manager.loadAndMigrateIfNeeded()
                persistence = manager; storeSnapshot = saved
                selectedAccent = TTSVoiceAccent(rawValue:saved.preferredAccent) ?? .british
                speechRateMultiplier = saved.preferredSpeechRate < 0.7 ? saved.preferredSpeechRate * 2 : saved.preferredSpeechRate
                if let session = saved.dictationSession {
                    selectedDeck=session.currentWord?.deckID ?? session.attemptLogs.last?.deckID ?? selectedDeck
                    if session.dateString==LumaStudyCenterHostView.todayDateString() {dictationMachine=session}
                    else {dictationMachine=DictationSessionStateMachine(mode:session.mode,dateString:LumaStudyCenterHostView.todayDateString(),initialWords:session.pendingQueue,existingStubbornWordsForToday:saved.stubbornWords)}
                }
                if manager.recoveryPerformed {storageError="检测到学习记录损坏，已恢复上次有效备份；损坏原文件保存在备份目录中。"}
            } catch { storageError = "学习记录读取失败，原文件已保留：\(error.localizedDescription)" }
        }
        static func sessionKey(mode:DictationSessionMode,date:String,deck:String)->String {mode.rawValue+"|"+date+"|"+deck}
        func storeDraft(_ draft:WritingExamDraftState) {
            storeSnapshot.activeWritingDrafts=storeSnapshot.activeWritingDrafts.filter{$0.value.id != draft.id}
            storeSnapshot.activeWritingDrafts[draft.id.uuidString]=draft
            save()
        }
        @discardableResult func save()->Bool {
            guard let persistence else { return false }
            storeSnapshot.dictationSession = dictationMachine
            if storeSnapshot.dictationSessions==nil {storeSnapshot.dictationSessions=[:]}
            let deck=dictationMachine.currentWord?.deckID ?? dictationMachine.attemptLogs.last?.deckID ?? selectedDeck
            storeSnapshot.dictationSessions?[Self.sessionKey(mode:dictationMachine.mode,date:dictationMachine.dateString,deck:deck)]=dictationMachine
            storeSnapshot.preferredAccent = selectedAccent.rawValue
            storeSnapshot.preferredSpeechRate = speechRateMultiplier
            do { try persistence.save(storeSnapshot); return true }
            catch { storageError = "学习记录保存失败：\(error.localizedDescription)";return false }
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
        @Published var selectedDeck = "vocab_daily"
        @Published var practiceSeconds = 3600
        @Published var speechSettingsShown = false
        @Published var evaluatingSubmission:UUID?
        @Published var statsScope: StudyStatisticsScope = .all
        @Published var statsTimeWindow: StudyStatsTimeWindow = .allTime
    }
    @StateObject private var vm:HostStateModel
    @StateObject private var audio = SpeechAudioPipeline()
    @State private var revealedWordID:String?
    @State private var importDraft:VocabularyImportDraft?
    @State private var reviewSession:WritingReviewSession?
    @State private var importShown=false
    @State private var deckSearch=""
    @FocusState private var answerFocused:Bool
    private var allWords:[VocabularyWord] {Self.builtInVocabularyWords + (vm.storeSnapshot.importedWords ?? [])}

    private var ttsEngine:MacOSSpeechSynthesisManager { vm.speech }
    private let evaluateWriting:(@MainActor (WritingSubmissionRecord,Task1QuestionItem) async throws->IELTSFourCriteriaEstimate)?

    public init(mode: Binding<String>, storageDirectory:URL? = nil,evaluateWriting:(@MainActor (WritingSubmissionRecord,Task1QuestionItem) async throws->IELTSFourCriteriaEstimate)? = nil) {
        self._vm = StateObject(wrappedValue:HostStateModel(storageDirectory:storageDirectory))
        self._mode = mode
        self.evaluateWriting=evaluateWriting
    }

    private var isPractice:Bool {mode.contains("模拟机考") || (mode=="学习_听力_今日计划" || mode=="学习_听力_错词复习")}
    public var body: some View {
        ZStack {
            appearance.paper.ignoresSafeArea()

            VStack(spacing:12) {
            HStack(spacing:12) {
                Button {mode="学习"} label:{Image(systemName:"square.grid.2x2")}.help("学习主页")
                if mode.contains("听力") {
                    Button("词库") {mode="学习_听力"}
                    Button("错词") {startDictation(mode:.wrongWordReview,resume:true);mode="学习_听力_错词复习"}
                    Button("顽固单词") {mode="学习_听力_顽固单词"}
                    Button("记录") {mode="学习_听力_学习记录"}
                } else if mode.contains("写作") || mode=="学习_草稿" {
                    Button("Task 1") {mode="学习_写作_Task1题库"}
                    Button("Task 2") {mode="学习_写作_Task2题库"}
                    if !mode.contains("模拟机考") {
                        Picker("模式",selection:$vm.practiceSeconds) {
                            Text("完整模拟 · 60 分钟").tag(3600)
                            Text("Task 1 · 20 分钟").tag(1200)
                            Text("Task 2 · 40 分钟").tag(2400)
                        }.frame(maxWidth:230)
                    }
                    Button("草稿") {mode="学习_草稿"}
                    Button("历史作文") {mode="学习_写作_历史作文"}
                }
                Spacer()
            }.buttonStyle(.borderless).padding(.horizontal,32).padding(.vertical,10)
                .padding(.top,isPractice ? 26:0)
            if let error = vm.storageError {HStack {Text(error).foregroundStyle(.red).textSelection(.enabled);Spacer();Button("关闭提示"){vm.storageError=nil}}.padding(.horizontal,24)}
            switch mode {
            case "学习": studyHome
            case "学习_听力", "学习_听力_我的词库": listeningHome
            case "学习_草稿":
                List(Array(vm.storeSnapshot.activeWritingDrafts.values).sorted{$0.lastSavedAt>$1.lastSavedAt},id:\.id) { draft in
                    Button(draft.examTitle) {
                        if let question = Self.builtInPracticeQuestions.first(where: { $0.id == draft.questionID }) {
                            vm.selectedExamQuestion = question; vm.currentDraft = draft; mode = "学习_写作_模拟机考"
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
                IELTSWritingExamSplitPaneView(
                    question: vm.selectedExamQuestion,
                    draft: $vm.currentDraft,
                    onAutoSave: { updated in
                        vm.storeDraft(updated)
                    },
                    onSubmitExam: { submittedDraft in
                        submitWritingExam(submittedDraft)
                    }
                )
            case "学习_写作_Task2题库":
                task2QuestionBankView
            case "学习_写作_历史作文", "学习_写作_评分反馈":
                writingHistoryAndFeedbackView
            case "学习_统计":
                studyStatisticsView
            default:
                // Default: "学习_Task1题库" / "学习_写作_Task1题库"
                Task1QuestionBankHomeView(
                    allCatalogItems: Self.builtInPracticeQuestions,
                    onLaunchExam: { chosen in
                        launchExam(for: chosen, singleTask: false)
                    }
                )
            }
        }
        }
        .fileImporter(isPresented:$importShown,allowedContentTypes:[.json,.tabSeparatedText,.plainText]) { result in
            do {
                let url=try result.get();let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
                let data=try Data(contentsOf:url)
                importDraft=try VocabularyImportDraft(data:data,filename:url.lastPathComponent)
            } catch {vm.storageError="导入失败，现有词库和记录未更改：\(error.localizedDescription)"}
        }
        .sheet(item:$importDraft){draft in
            VocabularyImportReview(draft:draft,existing:allWords,onConfirm:saveImportedWords)
        }
        .sheet(item:$reviewSession){session in
            WritingReviewPanel(session:session,onSave:saveWritingRevision)
        }
        .animation(reduceMotion ? nil:.easeInOut(duration:0.18),value:mode)
        .onDisappear { vm.save(); ttsEngine.stop(); audio.stop() }
        .onChange(of:mode) { _,_ in ttsEngine.stop();audio.stop() }
        .onReceive(audio.$errorMessage) { message in if let message { vm.dictationFeedback = message } }
        .task {
            if let service = vm.storeSnapshot.speechService, service.enabled { await audio.connect(service) }
        }
        .task {
            var previous = ContinuousClock.now
            while !Task.isCancelled {
                do { try await Task.sleep(for:.seconds(1)) } catch { return }
                let now = ContinuousClock.now
                let elapsed = previous.duration(to:now)
                let seconds = Int(elapsed.components.seconds)
                guard seconds > 0 else { continue }
                previous = previous.advanced(by:.seconds(seconds))
                if (mode == "学习_模拟机考" || mode == "学习_写作_模拟机考"), !vm.currentDraft.isPaused, vm.currentDraft.remainingSeconds > 0 {
                    let used = min(seconds,vm.currentDraft.remainingSeconds)
                    vm.currentDraft.remainingSeconds -= used; vm.currentDraft.elapsedSeconds += used
                    vm.storeDraft(vm.currentDraft)
                    if vm.currentDraft.remainingSeconds == 0 { submitWritingExam(vm.currentDraft) }
                }
            }
        }
    }

    private func launchExam(for chosen: Task1QuestionItem, singleTask: Bool) {
        vm.selectedExamQuestion = chosen
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
        mode = "学习_写作_模拟机考"
    }

    private func submitWritingExam(_ submittedDraft: WritingExamDraftState) {
        guard !vm.storeSnapshot.writingSubmissions.contains(where:{$0.draftSessionID==submittedDraft.id}) else {mode="学习_写作_历史作文";return}
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
        vm.storeDraft(submittedDraft) // Original answer is durable before submission/evaluation.
        vm.storeSnapshot.writingSubmissions.insert(record, at: 0)
        vm.save()
        mode = "学习_写作_评分反馈"
    }

    // MARK: - 1. Listening Shelf & Dictation Pod

    private func listeningCenterView(submode: DictationSessionMode) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Picker("词库",selection:$vm.selectedDeck) {
                        ForEach(Array(Set(allWords.map(\.deckID))).sorted(),id:\.self) { Text($0).tag($0) }
                    }
                    Button("开始听写") { startDictation(mode:.newTask) }
                    Button("错词复习") { startDictation(mode:.wrongWordReview) }
                    Button("停止播放") { ttsEngine.stop();audio.stop() }
                    Button("听写专项设置",systemImage:"slider.horizontal.3") { vm.speechSettingsShown = true }
                        .sheet(isPresented:$vm.speechSettingsShown) {
                            SpeechSettingsPanel(audio:audio,settings:Binding(get:{vm.storeSnapshot.speechService ?? SpeechServiceSettings()},set:{vm.storeSnapshot.speechService=$0;vm.save()}),voiceID:Binding(get:{vm.storeSnapshot.selectedVoiceIdentifier ?? ""},set:{vm.storeSnapshot.selectedVoiceIdentifier=$0;vm.save()}),accent:Binding(get:{vm.selectedAccent},set:{vm.selectedAccent=$0;vm.save()}),rate:Binding(get:{vm.speechRateMultiplier},set:{vm.speechRateMultiplier=$0;vm.save()}),repeats:Binding(get:{vm.storeSnapshot.speechRepeatCount ?? 1},set:{vm.storeSnapshot.speechRepeatCount=$0;vm.save()}),interval:Binding(get:{vm.storeSnapshot.speechInterval ?? 0.5},set:{vm.storeSnapshot.speechInterval=$0;vm.save()}),voices:ttsEngine.availableVoices(for:vm.selectedAccent),onClose:{vm.save();vm.speechSettingsShown=false})
                        }
                }.padding(.horizontal,32)
                Text("今日已听写 \(DictationSessionStateMachine.todayDictatedWordCount(from:vm.storeSnapshot.dictationLogs,on:Self.todayDateString())) 个单词")
                    .font(.headline).padding(.horizontal,32)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text(vm.dictationMachine.mode == .wrongWordReview ? "错词复习" : vm.dictationMachine.mode == .stubbornWordReview ? "顽固单词复习":"词汇听写")
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

                        Button("重播声音") {speakCurrentWord()}.keyboardShortcut("r",modifiers:[.command])
                        .buttonStyle(.borderedProminent)
                        .tint(appearance.accent)
                    }

                    if let word = vm.dictationMachine.currentWord {
                        let errorCount = vm.dictationMachine.sessionErrorCounts[word.id, default: 0]
                        Button("不熟悉 · 显示中文") { vm.showMeaning = true }
                        if vm.showMeaning { Text(word.definitionZH) }
                        if vm.dictationMachine.requiresCorrection {
                            Button("查看拼写后订正") {revealedWordID=word.id}
                            if revealedWordID==word.id {Text(word.word).font(.headline).textSelection(.enabled)}
                        }
                        Text("今日累计错误：\(errorCount) 次 · 第 6 次进入顽固单词").font(.system(size: 13))
                            .foregroundStyle(appearance.ink.opacity(0.85))

                        HStack(spacing: 12) {
                            TextField("听音后输入英文单词…", text: $vm.dictationInput)
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
                        ProgressView(value:Double(vm.dictationMachine.completedWordIDs.count),total:Double(max(1,vm.dictationMachine.completedWordIDs.count+vm.dictationMachine.pendingQueue.count)))
                        Text("剩余 \(vm.dictationMachine.pendingQueue.count) 个 · 已完成 \(vm.dictationMachine.completedWordIDs.count) 个").font(.caption).foregroundStyle(.secondary)
                    } else {
                        DictationReportView(session:vm.dictationMachine)
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
                                    vm.selectedDeck=rec.sourceDeckID;startDictation(mode:.stubbornWordReview,resume:true);mode="学习_听力_今日计划"
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
                Text("今日尚无听写记录，前往「听力 → 今日计划」开始练习后将自动记录。")
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
                                Text("输入：\(log.userTyped)")
                                    .font(.system(size: 12.5, design: .monospaced))
                                    .foregroundStyle(appearance.ink.opacity(0.75))
                                Spacer()
                                Text(log.isCorrect ? "✓ 正确" : "✗ 错误 (第\(log.sessionErrorCountForWord)次)")
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
            Text("双击任意题目进入 40 分钟 / 250 词纯英文无纠错写作机考")
                .font(.system(size: 13))
                .foregroundStyle(appearance.ink.opacity(0.68))

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Self.builtInPracticeQuestions) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(item.companionTask2ID ?? "T2") · \(item.shortTitle)")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundStyle(appearance.accent)
                                Spacer()
                                Text("建议 40 分钟 · 至少 250 词")
                                    .font(.system(size: 12))
                                    .foregroundStyle(appearance.ink.opacity(0.6))
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
                            launchExam(for: item, singleTask: false)
                            vm.currentDraft.activePart = .part2
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
            Text("作文先保存到本机。评分需主动发送至已配置的 AI 服务，结果仅供练习参考。")
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
                                        Text(String(format: "AI 估计总分：Band %.1f", eval.overallEstimatedBand))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(appearance.accent)
                                    }
                                }
                                HStack {
                                    Button("修改对照与重写") {
                                        let saved=vm.storeSnapshot.writingRevisions?.filter{$0.submissionID==sub.id}.max{$0.updatedAt<$1.updatedAt}
                                        reviewSession=WritingReviewSession(original:sub,revision:saved ?? WritingRevision(submissionID:sub.id))
                                    }
                                    Button("新建重写版本") {reviewSession=WritingReviewSession(original:sub,revision:WritingRevision(submissionID:sub.id))}
                                    Text("\((vm.storeSnapshot.writingRevisions ?? []).filter{$0.submissionID==sub.id}.count) 个重写版本").font(.caption)
                                }
                                ForEach((vm.storeSnapshot.writingRevisions ?? []).filter{$0.submissionID==sub.id}.sorted{$0.updatedAt>$1.updatedAt}){revision in
                                    Button("打开重写 · \(revision.updatedAt.formatted(date:.abbreviated,time:.shortened))") {reviewSession=WritingReviewSession(original:sub,revision:revision)}
                                }
                                Text(sub.part1EssayText + "\n\n" + sub.part2EssayText).textSelection(.enabled)
                                if let evaluateWriting,let question=Self.builtInPracticeQuestions.first(where:{$0.id==sub.questionID}) {
                                    Button(vm.evaluatingSubmission==sub.id ? "评估中…":"发送此作文至已配置 AI 评估") {
                                        vm.evaluatingSubmission=sub.id
                                        Task {
                                            defer{vm.evaluatingSubmission=nil}
                                            do {
                                                let evaluation=try await evaluateWriting(sub,question)
                                                if let index=vm.storeSnapshot.writingSubmissions.firstIndex(where:{$0.id==sub.id}) {
                                                    vm.storeSnapshot.writingSubmissions[index].aiEvaluation=evaluation;vm.save()
                                                }
                                            } catch {vm.storageError="评分未完成，原作文已保留：\(error.localizedDescription)"}
                                        }
                                    }.disabled(vm.evaluatingSubmission != nil)
                                }
                                if let evaluation=sub.aiEvaluation {
                                    Text(String(format:"TA/TR %.1f · CC %.1f · LR %.1f · GRA %.1f",evaluation.taskAchievementOrResponse,evaluation.coherenceAndCohesion,evaluation.lexicalResource,evaluation.grammaticalRangeAndAccuracy)).font(.caption)
                                    Text("AI 练习估分，非官方成绩。").font(.caption).foregroundStyle(.secondary)
                                    ForEach(Array(evaluation.sentenceCorrections.enumerated()),id:\.offset) {_,correction in
                                        VStack(alignment:.leading,spacing:5) {
                                            Text(correction.originalSentence).foregroundStyle(.secondary)
                                            Text(correction.correctedSentence)
                                            Text(correction.explanationZH).font(.callout)
                                        }.textSelection(.enabled).padding(.vertical,6)
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
        VStack(alignment:.leading,spacing:24) {
            Text("学习").font(.largeTitle)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:190))],spacing:20) {
                homeCard("词汇听写",symbol:"headphones",destination:"学习_听力")
                homeCard("学习统计",symbol:"chart.bar",destination:"学习_统计")
                homeCard("雅思写作",symbol:"pencil",destination:"学习_写作_Task1题库")
            }
            Spacer()
        }.padding(32)
    }
    private func homeCard(_ title:String,symbol:String,destination:String)->some View {
        Button { mode = destination } label: {
            VStack(spacing:20) { Image(systemName:symbol).font(.largeTitle); Text(title).font(.headline) }
                .frame(maxWidth:.infinity,minHeight:180).background(appearance.surface,in:RoundedRectangle(cornerRadius:16))
        }.buttonStyle(.plain)
    }
    private var listeningHome:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack {
                    VStack(alignment:.leading,spacing:6) {Text("听力").font(.largeTitle);Text("选择词库，听音默写").foregroundStyle(.secondary)}
                    Spacer()
                    TextField("搜索词库",text:$deckSearch).textFieldStyle(.roundedBorder).frame(maxWidth:240)
                    Button("到期复习") {startDictation(mode:.wrongWordReview,dueOnly:true);mode="学习_听力_错词复习"}
                    Button("导入词库",systemImage:"square.and.arrow.down") {importShown=true}
                }
                Text("支持 UTF-8 TSV（英文、中文两列）或 JSON 数组（word、meaning）。").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:170,maximum:220),spacing:24)],alignment:.leading,spacing:24) {
                    ForEach(Array(Set(allWords.map(\.deckID))).sorted(),id:\.self) {deck in
                        let words=allWords.filter{$0.deckID==deck}
                        let title=words.first?.deckTitle ?? deck
                        if deckSearch.isEmpty || title.localizedStandardContains(deckSearch) {
                            Button {
                                vm.selectedDeck=deck;startDictation(mode:.newTask,resume:true);mode="学习_听力_今日计划";answerFocused=true
                            } label: {
                                VStack(alignment:.leading,spacing:16) {
                                    Image(systemName:"headphones").font(.system(size:30,weight:.light))
                                    Spacer()
                                    Text(title).font(.title3.weight(.medium)).multilineTextAlignment(.leading)
                                    Text("\(words.count) 个词").font(.caption)
                                    if deck=="vocab_daily" {Text("内置示例词库").font(.caption2).foregroundStyle(.secondary)}
                                }.padding(22).frame(maxWidth:.infinity,minHeight:220,alignment:.leading)
                                    .background(appearance.secondaryGradient,in:RoundedRectangle(cornerRadius:16))
                                    .overlay(RoundedRectangle(cornerRadius:16).stroke(appearance.line,lineWidth:1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(32)
        }.background(appearance.paper)
    }

    private func startDictation(mode:DictationSessionMode,resume:Bool=false,dueOnly:Bool=false) {
        vm.save()
        let key=HostStateModel.sessionKey(mode:mode,date:Self.todayDateString(),deck:vm.selectedDeck)
        if resume,let saved=vm.storeSnapshot.dictationSessions?[key],!saved.isSessionFinished {
            vm.dictationMachine=saved;vm.showMeaning=false;vm.dictationInput="";vm.save();speakCurrentWord();return
        }
        let stubbornIDs=Set(vm.storeSnapshot.stubbornWords.map(\.wordID))
        let wrongIDs = Set(vm.storeSnapshot.dictationLogs.filter { !$0.isCorrect }.map(\.wordID))
        let words = allWords.filter { $0.deckID == vm.selectedDeck && (mode == .newTask || (mode == .stubbornWordReview ? stubbornIDs.contains($0.id):wrongIDs.contains($0.id))) && (!dueOnly || (vm.storeSnapshot.reviewSchedule?[$0.id]?.dueAt ?? .distantPast)<=Date()) }
        vm.dictationMachine = DictationSessionStateMachine(mode:mode,dateString:Self.todayDateString(),initialWords:words,existingStubbornWordsForToday:vm.storeSnapshot.stubbornWords,previousLogs:vm.storeSnapshot.dictationLogs)
        vm.showMeaning = false; vm.dictationInput = ""; vm.save(); speakCurrentWord()
    }

    private func speakCurrentWord() {
        guard let word = vm.dictationMachine.currentWord else { return }
        if let service = vm.storeSnapshot.speechService,service.enabled {
            ttsEngine.stop()
            let next = vm.dictationMachine.pendingQueue.dropFirst().map(\.word)
            audio.play(text:word.word,next:Array(next),settings:service,speed:vm.speechRateMultiplier,repeats:vm.storeSnapshot.speechRepeatCount ?? 1,interval:vm.storeSnapshot.speechInterval ?? 0.5)
            return
        }
        audio.stop()
        let voices = ttsEngine.availableVoices(for:vm.selectedAccent)
        let selected = voices.first { $0.id == vm.storeSnapshot.selectedVoiceIdentifier && $0.localeIdentifier == vm.selectedAccent.rawValue }
        let voice = selected ?? ttsEngine.selectBestFemaleVoice(
            preferredVoiceID: vm.storeSnapshot.selectedVoiceIdentifier,
            accent: vm.selectedAccent
        )
        guard ttsEngine.availableVoices(for:vm.selectedAccent).contains(where: { $0.id == voice.id }) else {
            vm.dictationFeedback = "没有已安装的英语女声，请在 macOS 辅助功能的朗读声音中安装英语女声。"; return
        }
        ttsEngine.repeatCount = vm.storeSnapshot.speechRepeatCount ?? 1
        ttsEngine.repeatInterval = vm.storeSnapshot.speechInterval ?? 0.5
        ttsEngine.speak(text: word.word, voice: voice, requestedRate: vm.speechRateMultiplier)
    }

    private func submitCurrentDictation() {
        guard !vm.dictationInput.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{vm.dictationFeedback="请输入听到的单词后提交。";return}
        guard let word=vm.dictationMachine.currentWord,let outcome=vm.dictationMachine.submitAnswer(vm.dictationInput) else{return}
        if let log=vm.dictationMachine.attemptLogs.last {
            vm.storeSnapshot.dictationLogs.append(log)
            if !log.isCorrect || vm.dictationMachine.completedWordIDs.contains(word.id) {
                var progress=vm.storeSnapshot.reviewSchedule?[word.id] ?? WordReviewProgress(dueAt:Date())
                progress.record(cleanRecall:log.isCorrect,at:Date())
                if vm.storeSnapshot.reviewSchedule==nil{vm.storeSnapshot.reviewSchedule=[:]}
                vm.storeSnapshot.reviewSchedule?[word.id]=progress
            }
        }
        for record in vm.dictationMachine.sortedStubbornWords {
            vm.storeSnapshot.stubbornWords.removeAll{$0.wordID==record.wordID && $0.dateString==record.dateString}
            vm.storeSnapshot.stubbornWords.append(record)
        }
        vm.save();vm.showMeaning=false;revealedWordID=nil;vm.dictationInput="";answerFocused=true
        switch outcome {
        case .needsCorrection(let count):
            vm.dictationFeedback="拼写有误，今日第 \(count) 次。请订正当前词，拼对后才能继续。"
        case .correct(let exited):
            vm.dictationFeedback=exited ? "✓ 独立拼对，已通过本轮复习。":"✓ 拼写正确。"
            speakCurrentWord()
        case .requeuedForRetry(_,let offset):
            vm.dictationFeedback="✓ 已订正；随机安排在后续第 \(offset+1) 个任务，再次独立拼对才能通过。"
            speakCurrentWord()
        case .promotedToStubbornWords:
            vm.dictationFeedback="今日已超过 5 次错误，已进入顽固单词。拼对当前词后继续，不再自动循环。"
        }
    }
    private func saveImportedWords(_ words:[VocabularyWord])->String? {
        var existing=vm.storeSnapshot.importedWords ?? []
        let ids=Set(existing.map(\.id));existing.append(contentsOf:words.filter{!ids.contains($0.id)})
        vm.storeSnapshot.importedWords=existing
        return vm.save() ? nil:(vm.storageError ?? "保存失败，请重试。")
    }
    private func saveWritingRevision(_ revision:WritingRevision)->String? {
        var revisions=vm.storeSnapshot.writingRevisions ?? []
        revisions.removeAll{$0.id==revision.id};revisions.append(revision)
        vm.storeSnapshot.writingRevisions=revisions
        return vm.save() ? nil:(vm.storageError ?? "重写稿保存失败，请重试。")
    }

    // MARK: - 3. Study Statistics View (全部｜听力｜写作 + 今天｜7天｜30天｜全部时间)

    private var studyStatisticsView: some View {
        let allowedDates:Set<String>? = {
            let count:Int
            switch vm.statsTimeWindow {case .allTime:return nil;case .today:count=1;case .last7Days:count=7;case .last30Days:count=30}
            let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.dateFormat="yyyy-MM-dd"
            return Set((0..<count).compactMap{Calendar.current.date(byAdding:.day,value: -$0,to:Date())}.map{formatter.string(from:$0)})
        }()
        let overview = StudyStatisticsCalculator.computeOverview(
            dictationLogs: vm.storeSnapshot.dictationLogs,
            writingSubmissions: vm.storeSnapshot.writingSubmissions,allowedDates:allowedDates
        )
        let listeningStats = StudyStatisticsCalculator.computeListening(
            dictationLogs: vm.storeSnapshot.dictationLogs,
            stubbornWords: vm.storeSnapshot.stubbornWords.sorted { $0.errorCount > $1.errorCount },allowedDates:allowedDates
        )
        let writingStats = StudyStatisticsCalculator.computeWriting(
            submissions: vm.storeSnapshot.writingSubmissions,allowedDates:allowedDates
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
                    statCard(title: "真实总学习时长", value: "\(overview.totalStudySeconds / 60) 分钟", subtitle: "听力 \(overview.listeningStudySeconds / 60) 分钟 + 写作 \(overview.writingStudySeconds / 60) 分钟（绝不把单词数加作文数）")
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
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(appearance.ink)
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(appearance.ink.opacity(0.55))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(appearance.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(appearance.line, lineWidth: 1))
        )
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Built-In Vocabulary & 12 Original Task 1 Questions

    public static let builtInVocabularyWords: [VocabularyWord] = [
        VocabularyWord(id: "w1", word: "accommodation", phoneticUK: "/əˌkɒm.əˈdeɪ.ʃən/", phoneticUS: "/əˌkɑː.məˈdeɪ.ʃən/", partOfSpeech: "n.", definitionZH: "住宿；膳宿设施", exampleSentence: "New tourist accommodation was constructed.", deckID: "vocab_daily", deckTitle: "词汇练习"),
        VocabularyWord(id: "w2", word: "infrastructure", phoneticUK: "/ˈɪn.frəˌstrʌk.tʃər/", phoneticUS: "/ˈɪn.frəˌstrʌk.tʃɚ/", partOfSpeech: "n.", definitionZH: "基础设施", exampleSentence: "Public transport infrastructure expanded.", deckID: "vocab_daily", deckTitle: "词汇练习"),
        VocabularyWord(id: "w3", word: "fluctuate", phoneticUK: "/ˈflʌk.tʃu.eɪt/", phoneticUS: "/ˈflʌk.tʃu.eɪt/", partOfSpeech: "v.", definitionZH: "波动；涨落", exampleSentence: "Attendance figures fluctuated wildly.", deckID: "vocab_daily", deckTitle: "词汇练习"),
        VocabularyWord(id: "w4", word: "sustainable", phoneticUK: "/səˈsteɪ.nə.bəl/", phoneticUS: "/səˈsteɪ.nə.bəl/", partOfSpeech: "adj.", definitionZH: "可持续的", exampleSentence: "Sustainable energy production increased.", deckID: "vocab_daily", deckTitle: "词汇练习")
    ]

    public static let builtInPracticeQuestions: [Task1QuestionItem] = [
        Task1QuestionItem(
            id: "ORIG-001",
            shortTitle: "Car ownership",
            category: .lineGraph,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The line graph below shows the percentage of households owning zero, one, or two or more cars in a European country between 1980 and 2020. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ielts-simon.study/ielts-writing-task-1-academic/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1980", "1990", "2000", "2010", "2020"],
                series: [
                    ChartSeries(name: "No car", unit: "%", values: [48, 38, 30, 25, 22]),
                    ChartSeries(name: "One car", unit: "%", values: [42, 46, 48, 47, 46]),
                    ChartSeries(name: "Two or more cars", unit: "%", values: [10, 16, 22, 28, 32])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-001",
            companionTask2Prompt: "Some people believe that governments should invest heavily in public transport rather than building new roads for private cars. To what extent do you agree or disagree?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-002",
            shortTitle: "Household spending",
            category: .pieChart,
            difficultyBand: "Band 6.0–7.0",
            promptText: "The pie chart below illustrates the average proportion of monthly household expenditure across six categories in a coastal city in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-sample-chart-for-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Housing", "Food", "Transport", "Healthcare", "Leisure", "Savings"],
                series: [],
                pieSlicePercentages: ["Housing": 34, "Food": 22, "Transport": 15, "Healthcare": 11, "Leisure": 10, "Savings": 8],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-002",
            companionTask2Prompt: "In many countries, the cost of living is rising rapidly. What are the primary causes of this trend, and what measures can individuals and governments take to address it?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-003",
            shortTitle: "Island redevelopment",
            category: .map,
            difficultyBand: "Band 7.0–8.0",
            promptText: "The two maps below show an island before and after the construction of tourist facilities. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-map-comparison/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Before", "After"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeYearLabel: "Before Development",
                    afterYearLabel: "After Eco-Resort Development",
                    beforeFeatures: [
                        MapStageFeature(label: "Natural sandy beach", region: "West", status: "unmodified"),
                        MapStageFeature(label: "Scattered palm groves", region: "East & North", status: "natural"),
                        MapStageFeature(label: "Undeveloped interior", region: "Center", status: "vacant")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Swimming area at beach", region: "West", status: "added"),
                        MapStageFeature(label: "Reception & restaurant block", region: "Center", status: "constructed"),
                        MapStageFeature(label: "Guest accommodation huts", region: "West & Center", status: "constructed"),
                        MapStageFeature(label: "Southern boat pier", region: "South", status: "constructed")
                    ]
                ),
                processSteps: nil
            ),
            companionTask2ID: "T2-003",
            companionTask2Prompt: "Developing remote natural areas for international tourism brings economic benefits, but it often damages the local environment. Discuss both views and give your own opinion.",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-004",
            shortTitle: "Coffee production",
            category: .processDiagram,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The diagram below shows the stages involved in the dry-method production of roasted coffee beans from harvesting to commercial packaging. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-sample-chart-for-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1", "2", "3", "4"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: [
                    ProcessStepPayload(stepNumber: 1, title: "Hand Picking & Sun Drying", detail: "Ripe cherries are harvested and sun-dried for 2–3 weeks.", nextStepNumber: 2),
                    ProcessStepPayload(stepNumber: 2, title: "Mechanical Hulling", detail: "Dried outer husks are removed in a mill.", nextStepNumber: 3),
                    ProcessStepPayload(stepNumber: 3, title: "Grading & Roasting", detail: "Beans are sorted and roasted at 200°C–220°C.", nextStepNumber: 4),
                    ProcessStepPayload(stepNumber: 4, title: "Cooling & Vacuum Packing", detail: "Roasted beans are cooled and sealed into commercial bags.", nextStepNumber: nil)
                ]
            ),
            companionTask2ID: "T2-004",
            companionTask2Prompt: "Modern automated manufacturing has reduced the price of everyday consumer goods, yet many traditional skills are disappearing. Do the advantages of automation outweigh the disadvantages?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-005",
            shortTitle: "Museum attendance",
            category: .barChart,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The bar chart below compares annual visitor numbers (in thousands) across four public museums in a capital city in 2015, 2020, and 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://howtodoielts.com/ielts-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["National Gallery", "Science Museum", "Maritime Museum", "Modern Art Hub"],
                series: [
                    ChartSeries(name: "2015", unit: "k", values: [820, 640, 310, 490]),
                    ChartSeries(name: "2020", unit: "k", values: [410, 380, 180, 290]),
                    ChartSeries(name: "2025", unit: "k", values: [950, 890, 340, 760])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-005",
            companionTask2Prompt: "Some people think that all public museums and art galleries should be free of charge, while others believe visitors should pay an admission fee. Discuss both views and give your opinion.",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-006",
            shortTitle: "Population trends",
            category: .table,
            difficultyBand: "Band 7.0–8.0",
            promptText: "The table below gives data on the population distribution (in millions) across three age brackets in four regions in 2025, along with total regional populations. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://www.ielts.org/take-a-test/preparation-resources/sample-test-questions/academic-test",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["North Metro", "Central Valley", "Coastal District", "Highland Province"],
                series: [
                    ChartSeries(name: "Aged 0–14", unit: "M", values: [2.4, 1.8, 3.1, 0.9]),
                    ChartSeries(name: "Aged 15–64", unit: "M", values: [9.6, 6.5, 11.4, 3.2]),
                    ChartSeries(name: "Aged 65+", unit: "M", values: [3.0, 2.2, 2.5, 1.4])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: [15.0, 10.5, 17.0, 5.5],
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-006",
            companionTask2Prompt: "In many countries, the proportion of older people is steadily increasing. Does this demographic shift bring more positive or negative effects to society?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-007",
            shortTitle: "House prices",
            category: .barChart,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The bar chart below shows the average residential property price (in thousand USD) for apartments, townhouses, and detached homes in three cities in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://takeielts.britishcouncil.org/prepare/ielts-free-practice-mock-tests/academic/writing",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Harborview", "Oakridge", "Riverdale"],
                series: [
                    ChartSeries(name: "Apartments", unit: "k USD", values: [420, 310, 260]),
                    ChartSeries(name: "Townhouses", unit: "k USD", values: [680, 490, 390]),
                    ChartSeries(name: "Detached", unit: "k USD", values: [950, 670, 520])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-007",
            companionTask2Prompt: "In many major cities, young adults find it increasingly difficult to purchase their first home. What are the reasons for this, and how can governments help?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-008",
            shortTitle: "Water usage",
            category: .pieChart,
            difficultyBand: "Band 6.0–7.0",
            promptText: "The pie chart below shows the breakdown of municipal freshwater consumption across five sectors in an Australian metropolitan region in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://howtodoielts.com/ielts-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["Houses", "Apartments", "Industrial", "Commercial", "Parks"],
                series: [],
                pieSlicePercentages: ["Houses": 46, "Apartments": 18, "Industrial": 16, "Commercial": 12, "Parks": 8],
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-008",
            companionTask2Prompt: "Fresh water is becoming a scarce resource in many parts of the world. What are the causes of water scarcity, and what steps should be taken to conserve water?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-009",
            shortTitle: "City populations",
            category: .lineGraph,
            difficultyBand: "Band 6.5–7.5",
            promptText: "The line graph below illustrates the urban population growth (in millions) of three Asian metropolitan areas from 1990 to 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-sample-chart-for-writing-task-1/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1990", "2000", "2010", "2020", "2025"],
                series: [
                    ChartSeries(name: "Metro Alpha", unit: "M", values: [3.2, 4.8, 6.9, 8.7, 9.4]),
                    ChartSeries(name: "Metro Beta", unit: "M", values: [5.1, 5.6, 6.2, 6.8, 7.0]),
                    ChartSeries(name: "Metro Gamma", unit: "M", values: [1.8, 2.9, 5.4, 7.9, 9.1])
                ],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: nil,
                processSteps: nil
            ),
            companionTask2ID: "T2-009",
            companionTask2Prompt: "Rapid urbanization creates severe housing and traffic pressures in large cities. What problems does overpopulation in cities cause, and how can they be solved?",
            notes: nil
        ),
        Task1QuestionItem(
            id: "ORIG-010",
            shortTitle: "Park plans",
            category: .map,
            difficultyBand: "Band 7.0–8.0",
            promptText: "The two plans below show a municipal community park in 1995 and its redesigned layout in 2025. Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
            minimumWords: 150,
            recommendedMinutes: 20,
            sourceName: "LumaReader Original Academic Bank",
            sourceURL: "https://ieltsliz.com/ielts-map-comparison/",
            licenseStatus: .originalSelfAuthored,
            chartDataset: Task1ChartDataset(
                xAxisLabels: ["1995", "2025"],
                series: [],
                pieSlicePercentages: nil,
                tableRowTotals: nil,
                mapComparison: MapComparisonPayload(
                    beforeYearLabel: "1995 Layout",
                    afterYearLabel: "2025 Redesigned Layout",
                    beforeFeatures: [
                        MapStageFeature(label: "Central duck pond", region: "Center", status: "original"),
                        MapStageFeature(label: "Gravel path & benches", region: "North", status: "original"),
                        MapStageFeature(label: "Open grass meadow", region: "East", status: "undeveloped")
                    ],
                    afterFeatures: [
                        MapStageFeature(label: "Expanded wetland pond & deck", region: "Center", status: "expanded"),
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
            difficultyBand: "Band 7.0–8.0",
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
            difficultyBand: "Band 7.5–8.5",
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
