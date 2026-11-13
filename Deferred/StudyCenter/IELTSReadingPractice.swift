import AppKit
import Combine
import SwiftUI

private struct IELTSReadingSample: Decodable, Identifiable {
    struct Group: Decodable, Identifiable {
        struct Question: Decodable, Identifiable {
            let id: Int
            let prompt: String
            let answer: String
            let options: [[String]]
            let requiredSelections: Int?
            let acceptableAnswers: [String]?

            func isCorrect(_ response: String) -> Bool {
                func normalize(_ text: String) -> String {
                    text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
                }
                if (requiredSelections ?? 1) > 1 {
                    return Set(normalize(response).split(separator: ",").map { normalize(String($0)) })
                        == Set(normalize(answer).split(separator: ",").map { normalize(String($0)) })
                }
                let normalized = normalize(response)
                return !normalized.isEmpty && ([answer] + (acceptableAnswers ?? [])).contains { normalize($0) == normalized }
            }
        }

        struct DiagramLabel: Decodable, Identifiable {
            let id: Int
            let x: Double
            let y: Double
        }

        var id: Int { questions.first?.id ?? 0 }
        let type: String
        let instruction: String
        let options: [[String]]
        let context: String?
        let table: [[String]]?
        let diagramAsset: String?
        let diagramLabels: [DiagramLabel]?
        let questions: [Question]
    }

    let id: Int
    let title: String
    let pages: String
    let text: String
    let notes: String
    let groups: [Group]

    static let layoutSample: Self? = {
        guard let url = Bundle.module.url(forResource: "IELTSReadingLayoutSample", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }()

    static let catalog: [Self]? = {
        guard let url = Bundle.module.url(forResource: "IELTSReadingSamples", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Self].self, from: data)
    }()
}

private struct IELTSReadingDraft: Codable {
    let sampleID: Int
    let groups: Set<Int>
    let answers: [Int: String]
    let marked: Set<Int>
    let elapsed: TimeInterval
}

struct IELTSReadingPractice: View {
    @Environment(\.studyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var type = "全部"
    @State private var search = ""
    @State private var focusedQuestion: Int?
    @State private var pickedMatch: String?
    @State private var passageJump: PassageJump?
    @State private var splitRatio: CGFloat = 0.50
    @State private var dragStartRatio: CGFloat? = nil
    @State private var isWindowFullScreen: Bool = false

    fileprivate struct PassageJump: Equatable {
        let paragraph: String
        let request = UUID()
    }

    @State private var confirmSubmission = false
    @AppStorage("luma.ieltsReading.drafts") private var draftData = Data()

    private var drafts: [IELTSReadingDraft] {
        (try? JSONDecoder().decode([IELTSReadingDraft].self, from: draftData)) ?? []
    }

    private func storeDrafts(_ updated: [IELTSReadingDraft]) {
        if let data = try? JSONEncoder().encode(updated) { draftData = data }
    }

    private func saveDraft() {
        guard practicing, !submitted, let selected, selected.id != IELTSReadingSample.layoutSample?.id else { return }
        let duration = elapsed + (startedAt.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0)
        let value = IELTSReadingDraft(sampleID: selected.id, groups: enabledGroups,
                                      answers: answers, marked: markedQuestions, elapsed: duration)
        storeDrafts([value] + drafts.filter { $0.sampleID != selected.id })
    }

    private func resume(_ draft: IELTSReadingDraft, sample: IELTSReadingSample) {
        selected = sample
        enabledGroups = draft.groups.intersection(Set(sample.groups.map(\.id)))
        guard !enabledGroups.isEmpty else { return }
        answers = draft.answers
        markedQuestions = draft.marked
        elapsed = draft.elapsed
        submitted = false
        focusedQuestion = sample.groups.filter { enabledGroups.contains($0.id) }.flatMap(\.questions).first?.id
        pickedMatch = nil
        passageJump = nil
        setPracticingState(true)
        resumeClock()
    }

    @State private var selected: IELTSReadingSample?
    @State private var enabledGroups: Set<Int> = []
    @State private var practicing = false
    @State private var submitted = false
    @State private var answers: [Int: String] = [:]

    @AppStorage("luma.ieltsReading.passageFont") private var passageFont = 16.0
    @AppStorage("luma.ieltsReading.questionFont") private var questionFont = 15.0
    @AppStorage("luma.ieltsReading.annotations") private var annotationData = Data()
    @State private var showFontControls = false
    @State private var markedQuestions: Set<Int> = []
    @State private var elapsed: TimeInterval = 0
    @State private var startedAt: TimeInterval?

    private func setPracticingState(_ active: Bool) {
        practicing = active
        NotificationCenter.default.post(
            name: Notification.Name("LumaReader.IELTSReadingPracticeStateChanged"),
            object: nil,
            userInfo: ["practicing": active]
        )
    }

    private func toggleNativeFullScreen() {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            window.toggleFullScreen(nil)
        } else {
            NotificationCenter.default.post(name: Notification.Name("LumaReader.ToggleWindowFullScreen"), object: nil)
        }
    }

    private func syncFullScreenFlag() {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            isWindowFullScreen = window.styleMask.contains(.fullScreen)
        }
    }

    private func pauseClock() {
        if let startedAt { elapsed += ProcessInfo.processInfo.systemUptime - startedAt }
        startedAt = nil
        saveDraft()
    }

    private func resumeClock() {
        guard NSApp.isActive, startedAt == nil, !submitted else { return }
        startedAt = ProcessInfo.processInfo.systemUptime
    }

    private func annotations(for id: Int) -> Binding<[StudyTextHighlight]> {
        Binding {
            ((try? JSONDecoder().decode([Int: [StudyTextHighlight]].self, from: annotationData)) ?? [:])[id] ?? []
        } set: { marks in
            var all = (try? JSONDecoder().decode([Int: [StudyTextHighlight]].self, from: annotationData)) ?? [:]
            all[id] = marks
            if let data = try? JSONEncoder().encode(all) { annotationData = data }
        }
    }

    // 严格遵循用户的主题配色系统（日漫小清新、千与千寻、Monet、暗黑模式）
    private var paper: Color { appearance.paper }
    private var ink: Color { appearance.ink }
    private var surface: Color { appearance.surface }
    private var accent: Color { appearance.accent }

    private let types = ["段落标题匹配", "段落信息匹配", "特征匹配", "单选题", "摘要填空",
                         "TRUE / FALSE / NOT GIVEN", "YES / NO / NOT GIVEN", "多选题", "句尾匹配",
                         "句子填空", "笔记填空", "表格填空", "流程图填空", "图示标注", "简答题"]

    var body: some View {
        ZStack {
            appearance.background.ignoresSafeArea()

            Group {
                if let sample = selected {
                    if practicing { practice(sample) } else { selection(sample) }
                } else {
                    catalog
                }
            }
            .padding(practicing ? 0 : 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(ink)
        .tint(accent)
        .onAppear { syncFullScreenFlag() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in isWindowFullScreen = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in isWindowFullScreen = false }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in pauseClock() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.AppDidResignActive"))) { _ in pauseClock() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in pauseClock() }
        .onDisappear {
            pauseClock()
            if practicing {
                NotificationCenter.default.post(
                    name: Notification.Name("LumaReader.IELTSReadingPracticeStateChanged"),
                    object: nil,
                    userInfo: ["practicing": false]
                )
            }
        }
        .onChange(of: answers) { _, _ in saveDraft() }
        .onChange(of: markedQuestions) { _, _ in saveDraft() }
    }

    // MARK: - 题库目录页 (Theme-Integrated Bento Catalog)
    private var catalog: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IELTS Academic Reading · 雅思机考阅读")
                        .lumaFont(size: 28, weight: .bold)
                        .foregroundStyle(ink)
                    Text("1:1 还原官方 Inspera 机考界面 · 支持 15 种题型专属交互与全屏沉浸模考")
                        .lumaFont(size: 13)
                        .foregroundStyle(ink.opacity(0.62))
                }
                Spacer()
                if let sample = IELTSReadingSample.layoutSample {
                    Button {
                        enabledGroups = Set(sample.groups.map(\.id))
                        selected = sample
                    } label: {
                        Label("全题型官方布局样例", systemImage: "rectangle.split.2x1.fill")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: false, horizontalPadding: 14, height: 34))
                }
                Button {
                    toggleNativeFullScreen()
                } label: {
                    Label(isWindowFullScreen ? "退出全屏" : "全屏模式",
                          systemImage: isWindowFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: isWindowFullScreen, horizontalPadding: 14, height: 34))
            }

            if let samples = IELTSReadingSample.catalog {
                if let draft = drafts.first, let sample = samples.first(where: { $0.id == draft.sampleID }) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("未完成的机考进度：\(sample.title)")
                                .lumaFont(size: 14, weight: .semibold)
                            Text("已答 \(draft.answers.values.filter { !$0.isEmpty }.count) 题 · 用时 \(Int(draft.elapsed) / 60) 分 \(Int(draft.elapsed) % 60) 秒")
                                .lumaFont(size: 12)
                                .foregroundStyle(ink.opacity(0.65))
                        }
                        Spacer()
                        Button {
                            resume(draft, sample: sample)
                        } label: {
                            Label("继续全屏机考", systemImage: "play.fill")
                        }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 16, height: 32))
                    }
                    .padding(14)
                    .studyGlassCapsule(cornerRadius: 14, selected: true)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ink.opacity(0.5))
                        TextField("搜索文章标题或篇目编号...", text: $search)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(ink.opacity(0.12), lineWidth: 1))

                    Picker("题型筛选", selection: $type) {
                        Text("全部 15 种题型").tag("全部")
                        ForEach(types.filter { kind in samples.contains { $0.groups.contains { $0.type == kind } } }, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
                let matches = samples.filter { sample in
                    let matchesType = type == "全部" || sample.groups.contains { $0.type == type }
                    return matchesType && (query.isEmpty || sample.title.localizedCaseInsensitiveContains(query) || String(sample.id) == query)
                }

                Text("共 \(matches.count) 篇真题篇章").lumaFont(size: 12, weight: .medium).foregroundStyle(ink.opacity(0.55))

                if matches.isEmpty {
                    ContentUnavailableView("没有符合筛选条件的文章", systemImage: "text.magnifyingglass")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 520), spacing: 14)], spacing: 14) {
                            ForEach(matches) { sample in
                                Button { open(sample) } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("PASSAGE \(sample.id)")
                                                .lumaFont(size: 11, weight: .bold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(accent.opacity(0.16), in: Capsule())
                                                .foregroundStyle(accent)
                                            Spacer()
                                            Text("\(sample.groups.flatMap(\.questions).count) Questions")
                                                .lumaFont(size: 12, weight: .medium)
                                                .foregroundStyle(ink.opacity(0.6))
                                        }
                                        Text(sample.title)
                                            .lumaFont(size: 17, weight: .semibold)
                                            .foregroundStyle(ink)
                                            .lineLimit(1)
                                        HStack(spacing: 6) {
                                            ForEach(Array(Set(sample.groups.map(\.type))).sorted(), id: \.self) { kind in
                                                Text(kind)
                                                    .lumaFont(size: 11)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                                                    .foregroundStyle(ink.opacity(0.78))
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .studyGlassCapsule(cornerRadius: 14)
                                }
                                .buttonStyle(StudyFluidPressStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                ContentUnavailableView("无法读取阅读题库", systemImage: "exclamationmark.triangle")
            }
        }
    }

    // MARK: - 题组选择页
    private func selection(_ sample: IELTSReadingSample) -> some View {
        let isLayoutSample = sample.id == IELTSReadingSample.layoutSample?.id
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    selected = nil
                } label: {
                    Label("返回题库", systemImage: "chevron.left")
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                Spacer()
                Button {
                    toggleNativeFullScreen()
                } label: {
                    Label(isWindowFullScreen ? "退出全屏" : "全屏模式",
                          systemImage: isWindowFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: isWindowFullScreen, horizontalPadding: 14, height: 32))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isLayoutSample ? "官方机考 15 种题型全集样例" : sample.title)
                    .lumaFont(size: 26, weight: .bold)
                if !isLayoutSample {
                    Text("PDF 页码：第 \(sample.pages) 页 · 选中下方要训练的题组后进入全屏分屏机考界面")
                        .lumaFont(size: 13)
                        .foregroundStyle(ink.opacity(0.62))
                }
            }

            HStack(spacing: 10) {
                Button("全选所有题组") { enabledGroups = Set(sample.groups.map(\.id)) }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                Button("清空选择") { enabledGroups.removeAll() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                Spacer()
                Text("已选 \(sample.groups.filter { enabledGroups.contains($0.id) }.flatMap(\.questions).count) 道题")
                    .lumaFont(size: 13, weight: .semibold)
                    .foregroundStyle(accent)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sample.groups) { group in
                        let isSelected = enabledGroups.contains(group.id)
                        Button {
                            if isSelected { enabledGroups.remove(group.id) }
                            else { enabledGroups.insert(group.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isSelected ? accent : ink.opacity(0.4))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(groupTitle(group))
                                        .lumaFont(size: 14.5, weight: .semibold)
                                    Text(group.instruction)
                                        .lumaFont(size: 12)
                                        .foregroundStyle(ink.opacity(0.65))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(officialTypeBadge(group.type))
                                    .lumaFont(size: 11, weight: .medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(accent.opacity(0.14), in: Capsule())
                                    .foregroundStyle(accent)
                            }
                            .padding(12)
                            .studyGlassCapsule(cornerRadius: 12, selected: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 380)

            HStack(spacing: 12) {
                if let draft = drafts.first(where: { $0.sampleID == sample.id }) {
                    Button {
                        resume(draft, sample: sample)
                    } label: {
                        Label("继续上次练习", systemImage: "play.fill")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 36))
                }
                Button {
                    answers = [:]
                    submitted = false
                    elapsed = 0
                    markedQuestions.removeAll()
                    let activeQuestions = sample.groups.filter { enabledGroups.contains($0.id) }.flatMap(\.questions)
                    focusedQuestion = activeQuestions.first?.id
                    pickedMatch = nil
                    passageJump = nil
                    resumeClock()
                    setPracticingState(true)
                    saveDraft()
                } label: {
                    Label(drafts.contains { $0.sampleID == sample.id } ? "重新开始机考" : "进入官方机考界面",
                          systemImage: "desktopcomputer")
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: !drafts.contains { $0.sampleID == sample.id }, horizontalPadding: 18, height: 36))
                .disabled(enabledGroups.isEmpty)
            }
        }
    }

    // MARK: - 1:1 官方 Inspera 机考主界面 (全屏沉浸 + 左右可调分屏 + 底部题号导航轨)
    private func practice(_ sample: IELTSReadingSample) -> some View {
        let groups = sample.groups.filter { enabledGroups.contains($0.id) }
        let questions = groups.flatMap(\.questions)
        let activeFocus = focusedQuestion ?? questions.first?.id
        let headingGroup = groups.first { $0.type == "段落标题匹配" }

        return VStack(spacing: 0) {
            // 1. 顶部官方机考状态栏（避开左侧红绿灯，与听力模块胶囊风格统一）
            officialTopHeaderBar(sample: sample, questions: questions)

            // 2. 官方机考 Reading Passage 指令横幅
            officialPassageInstructionBanner(sample: sample, questions: questions)

            // 3. 中央双栏独立滚动区 + 中央可拖拽比例分割器 (Resizable Splitter)
            GeometryReader { geo in
                let totalW = max(600, geo.size.width)
                let splitterW: CGFloat = 12
                let leftW = max(280, min(totalW - 320, (totalW - splitterW) * splitRatio))
                let rightW = max(300, totalW - leftW - splitterW)

                HStack(spacing: 0) {
                    // 左栏：阅读原文 + 嵌入式段落标题拖拽槽（当题组含“段落标题匹配”时自动激活）
                    leftPassagePane(sample: sample, headingGroup: headingGroup)
                        .frame(width: leftW)
                        .frame(maxHeight: .infinity)

                    // 中央官方机考分割手柄（支持左右自由拖拽改变文章与题目屏占比，双击恢复 50:50）
                    officialSplitterHandle(totalWidth: totalW)
                        .frame(width: splitterW)
                        .frame(maxHeight: .infinity)

                    // 右栏：按官方 15 种题型差异化渲染的答题区
                    ScrollViewReader { reader in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 26) {
                                ForEach(groups) { group in
                                    questionGroup(group, activeFocus: activeFocus)
                                }
                                if submitted && !sample.notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("官方解析与笔记", systemImage: "doc.text.magnifyingglass")
                                            .lumaFont(size: questionFont + 1, weight: .bold)
                                            .foregroundStyle(accent)
                                        Text(sample.notes)
                                            .lumaFont(size: questionFont)
                                            .foregroundStyle(ink.opacity(0.85))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .studyGlassCapsule(cornerRadius: 12)
                                }
                            }
                            .font(.system(size: questionFont))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(22)
                        }
                        .frame(width: rightW)
                        .frame(maxHeight: .infinity)
                        .background(paper.opacity(appearance.isDark ? 0.92 : 0.97))
                        .onChange(of: focusedQuestion) { _, newID in
                            if let newID {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88)) {
                                    reader.scrollTo(newID, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 4. 底部官方 Inspera 机考题号导航栏 (Review Checkbox + 分组题号方块 + 底部已答横条 + 前后切题箭头)
            officialBottomNavigatorBar(groups: groups, questions: questions, activeFocus: activeFocus)
        }
        .confirmationDialog("还有 \(questions.filter { !hasAnswer($0.id) }.count) 道题未作答", isPresented: $confirmSubmission, titleVisibility: .visible) {
            Button("仍然交卷", role: .destructive) { submit() }
            Button("返回继续作答", role: .cancel) {}
        }
    }

    // MARK: - 顶部机考控制栏（与听力练习页胶囊视觉完全对齐，支持全屏切换）
    private func officialTopHeaderBar(sample: IELTSReadingSample, questions: [IELTSReadingSample.Group.Question]) -> some View {
        let answeredCount = questions.filter { hasAnswer($0.id) }.count
        return HStack(spacing: 12) {
            // 为 macOS 原生窗口红绿灯预留安全区（非全屏时留白 74pt）
            if !isWindowFullScreen {
                Color.clear.frame(width: 74, height: 1).allowsHitTesting(false)
            }

            Button {
                pauseClock()
                setPracticingState(false)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("返回题组")
                        .lumaFont(size: 13, weight: .semibold)
                }
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 13, height: 32))

            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(sample.title)
                    .lumaFont(size: 14, weight: .semibold)
                    .lineLimit(1)
                Text("\(answeredCount) / \(questions.count)")
                    .lumaFont(size: 12.5, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(accent)
            }

            Spacer(minLength: 12)

            // 倒计时/正计时器（最后阶段高亮提醒）
            clockCapsule

            // 字号与分屏比例调节
            fontAndLayoutControls

            // 全屏切换按钮（像听力部分一样沉浸全屏）
            Button {
                toggleNativeFullScreen()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isWindowFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text(isWindowFullScreen ? "退出全屏" : "全屏")
                        .lumaFont(size: 12, weight: .semibold)
                }
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(selected: isWindowFullScreen, horizontalPadding: 12, height: 32))
            .help("切换全屏幕沉浸机考模式 (⌃⌘F)")

            if submitted {
                let score = questions.filter { $0.isCorrect(answers[$0.id, default: ""]) }.count
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(accent)
                    Text("得分 \(score) / \(questions.count)")
                        .lumaFont(size: 13, weight: .bold)
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .studyGlassCapsule(cornerRadius: 16, prominent: true)
            } else {
                Button {
                    if questions.allSatisfy({ hasAnswer($0.id) }) { submit() }
                    else { confirmSubmission = true }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("交卷 Submit")
                            .lumaFont(size: 12.5, weight: .semibold)
                    }
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 15, height: 32))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(surface.opacity(0.88))
        .overlay(alignment: .bottom) {
            Rectangle().fill(ink.opacity(0.10)).frame(height: 1)
        }
    }

    // MARK: - 官方 Inspera 机考 Reading Passage 横幅
    private func officialPassageInstructionBanner(sample: IELTSReadingSample, questions: [IELTSReadingSample.Group.Question]) -> some View {
        let firstQ = questions.first?.id ?? 1
        let lastQ = questions.last?.id ?? questions.count
        let passageNum = max(1, min(3, sample.id))
        return HStack(spacing: 12) {
            Text("Part \(passageNum)")
                .lumaFont(size: 13.5, weight: .bold)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(accent)

            Text("Read the text below and answer Questions \(firstQ)–\(lastQ).")
                .lumaFont(size: 13.5, weight: .medium)
                .foregroundStyle(ink.opacity(0.88))

            Spacer()

            Text("选中原文或题干任意词句即可高亮 (Highlight) 或添加笔记 (Notes)")
                .lumaFont(size: 11.5)
                .foregroundStyle(ink.opacity(0.52))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(surface.opacity(0.45))
        .overlay(alignment: .bottom) {
            Rectangle().fill(ink.opacity(0.10)).frame(height: 1)
        }
    }

    // MARK: - 中央可拖拽分屏器 (Official Draggable Splitter)
    private func officialSplitterHandle(totalWidth: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(surface.opacity(0.75))
            HStack(spacing: 0) {
                Rectangle().fill(ink.opacity(0.14)).frame(width: 1)
                Spacer(minLength: 0)
                Rectangle().fill(ink.opacity(0.14)).frame(width: 1)
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(accent.opacity(0.65))
                .frame(width: 4, height: 42)
        }
        .contentShape(Rectangle())
        .help("左右拖动调节文章与题目占屏比例（双击恢复 50:50）")
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                splitRatio = 0.50
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStartRatio == nil { dragStartRatio = splitRatio }
                    let base = dragStartRatio ?? splitRatio
                    let delta = value.translation.width / max(1, totalWidth)
                    splitRatio = min(0.72, max(0.28, base + delta))
                }
                .onEnded { _ in
                    dragStartRatio = nil
                }
        )
    }

    // MARK: - 左侧阅读原文面板（含段落标题匹配题型的嵌入式 Drop Zone 头部）
    @ViewBuilder
    private func leftPassagePane(sample: IELTSReadingSample, headingGroup: IELTSReadingSample.Group?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 如果当前练习包含“段落标题匹配（Matching Headings）”，在左侧原文顶部提供官方嵌入式段落标题投放栏
            if let headingGroup {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("官方段落标题槽 · 可直接将右侧 Heading 拖入对应段落", systemImage: "arrow.left.and.right.square")
                            .lumaFont(size: 12, weight: .semibold)
                            .foregroundStyle(accent)
                        Spacer()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(headingGroup.questions) { q in
                                let chosen = answers[q.id, default: ""]
                                let matchedOption = headingGroup.options.first { $0.count == 2 && $0[0] == chosen }
                                let paraLetter = q.prompt.split(separator: " ").last.map(String.init) ?? q.prompt
                                Button {
                                    focusedQuestion = q.id
                                    passageJump = PassageJump(paragraph: paraLetter)
                                    if let pickedMatch {
                                        _ = assignMatch(pickedMatch, to: q.id, group: headingGroup, reusable: false)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("\(q.id). Section \(paraLetter)")
                                            .lumaFont(size: 12, weight: .bold)
                                        Text(matchedOption.map { "\($0[0]) (\($0[1]))" } ?? (pickedMatch != nil ? "点击放入标题" : "拖放 Heading 至此"))
                                            .lumaFont(size: 11.5)
                                            .lineLimit(1)
                                            .frame(maxWidth: 180, alignment: .leading)
                                            .foregroundStyle(matchedOption != nil ? accent : ink.opacity(0.55))
                                        if matchedOption != nil && !submitted {
                                            Button {
                                                answers.removeValue(forKey: q.id)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(ink.opacity(0.45))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(matchedOption != nil ? accent.opacity(0.14) : paper)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .strokeBorder(
                                                focusedQuestion == q.id ? accent : ink.opacity(0.28),
                                                style: matchedOption != nil ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1, dash: [4, 3])
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let first = items.first else { return false }
                                    focusedQuestion = q.id
                                    passageJump = PassageJump(paragraph: paraLetter)
                                    return assignMatch(first, to: q.id, group: headingGroup, reusable: false)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(surface.opacity(0.55))
                .overlay(alignment: .bottom) { Divider() }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sample.title)
                    .font(.system(size: passageFont + 5, weight: .bold, design: .serif))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(paper)
            .overlay(alignment: .bottom) { Divider() }

            IELTSReadingPassage(
                text: sample.text,
                highlights: annotations(for: sample.id),
                appearance: appearance,
                fontSize: CGFloat(passageFont),
                jump: passageJump
            )
            .id(sample.id)
        }
        .background(paper)
    }

    // MARK: - 底部官方 Inspera 题号导航栏 (Bottom Palette Bar)
    private func officialBottomNavigatorBar(
        groups: [IELTSReadingSample.Group],
        questions: [IELTSReadingSample.Group.Question],
        activeFocus: Int?
    ) -> some View {
        let currentID = activeFocus ?? questions.first?.id ?? 1
        let isCurrentMarked = markedQuestions.contains(currentID)

        return HStack(spacing: 14) {
            // 1. 官方左下角 Review 复选框
            Button {
                if !markedQuestions.insert(currentID).inserted {
                    markedQuestions.remove(currentID)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCurrentMarked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isCurrentMarked ? accent : ink.opacity(0.65))
                    Text("Review")
                        .lumaFont(size: 13, weight: .semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isCurrentMarked ? accent.opacity(0.14) : surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(ink.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("将当前第 \(currentID) 题标记为待复查 (Review)")

            Divider().frame(height: 24)

            // 2. 中央 40 题题号矩阵（带顶部已答横条、复查圆点/旗标、交卷后红绿正误指示）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(groups) { group in
                        HStack(spacing: 4) {
                            ForEach(group.questions) { question in
                                let answered = hasAnswer(question.id)
                                let isFocused = currentID == question.id
                                let isFlagged = markedQuestions.contains(question.id)
                                let isWrong = submitted && !question.isCorrect(answers[question.id, default: ""])

                                Button {
                                    focusedQuestion = question.id
                                } label: {
                                    VStack(spacing: 2) {
                                        // 官方机考题号上方的已答指示线
                                        Capsule()
                                            .fill(submitted ? (isWrong ? Color.red : Color.green) : (answered ? accent : ink.opacity(0.18)))
                                            .frame(width: 20, height: 3)

                                        ZStack(alignment: .topTrailing) {
                                            Text(question.id.formatted())
                                                .lumaFont(size: 12.5, weight: isFocused ? .bold : .semibold)
                                                .monospacedDigit()
                                                .foregroundStyle(isFocused ? paper : ink)
                                                .frame(width: 28, height: 26)
                                                .background(
                                                    RoundedRectangle(cornerRadius: isFlagged ? 13 : 5)
                                                        .fill(isFocused ? accent : (answered ? accent.opacity(0.14) : paper))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: isFlagged ? 13 : 5)
                                                        .strokeBorder(
                                                            submitted ? (isWrong ? Color.red : Color.green.opacity(0.75)) : (isFocused ? accent : ink.opacity(0.22)),
                                                            lineWidth: isFocused ? 1.8 : 1
                                                        )
                                                )

                                            if isFlagged {
                                                Circle()
                                                    .fill(Color.orange)
                                                    .frame(width: 7, height: 7)
                                                    .offset(x: 2, y: -2)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("第 \(question.id) 题，\(answered ? "已答" : "未答")\(isFlagged ? "，待复查" : "")")
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 4)

            // 3. 右侧官方上一题 / 下一题导航箭头与未答快速定位
            HStack(spacing: 6) {
                if !submitted {
                    Button("未答题") {
                        if let question = questions.first(where: { !hasAnswer($0.id) }) {
                            focusedQuestion = question.id
                        }
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 28))
                    .disabled(questions.allSatisfy { hasAnswer($0.id) })
                }

                Button {
                    if let idx = questions.firstIndex(where: { $0.id == currentID }), idx > 0 {
                        focusedQuestion = questions[idx - 1].id
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(surface, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(ink.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(questions.first?.id == currentID)
                .help("上一题")

                Button {
                    if let idx = questions.firstIndex(where: { $0.id == currentID }), idx + 1 < questions.count {
                        focusedQuestion = questions[idx + 1].id
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(accent, in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(paper)
                }
                .buttonStyle(.plain)
                .disabled(questions.last?.id == currentID)
                .help("下一题")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(surface.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(ink.opacity(0.12)).frame(height: 1)
        }
    }

    private func hasAnswer(_ id: Int) -> Bool {
        let value = answers[id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let count = selected?.groups.lazy.flatMap(\.questions).first(where: { $0.id == id })?.requiredSelections ?? 1
        return count <= 1 || value.split(separator: ",").count == count
    }

    private func submit() {
        pauseClock()
        submitted = true
        if let selected, selected.id != IELTSReadingSample.layoutSample?.id {
            storeDrafts(drafts.filter { $0.sampleID != selected.id })
        }
    }

    private var clockCapsule: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let running = startedAt != nil
            let seconds = Int(elapsed + (startedAt.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0))
            let isUrgent = seconds >= 19 * 60 && !submitted
            Button {
                if running { pauseClock() } else { resumeClock() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: running ? "timer" : "pause.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isUrgent ? Color.red : accent)
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .lumaFont(size: 13, weight: .semibold, design: .rounded)
                        .monospacedDigit()
                        .foregroundStyle(isUrgent ? Color.red : ink)
                }
            }
            .buttonStyle(StudyGlassCapsuleButtonStyle(selected: isUrgent, horizontalPadding: 12, height: 32))
            .disabled(submitted)
            .help(running ? "点击暂停计时" : "点击继续计时")
        }
    }

    private var fontAndLayoutControls: some View {
        Button { showFontControls.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 12, weight: .semibold))
                Text("字号与分屏")
                    .lumaFont(size: 12, weight: .semibold)
            }
        }
        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: showFontControls, horizontalPadding: 12, height: 32))
        .accessibilityLabel("字号与分屏")
        .popover(isPresented: $showFontControls) {
            VStack(alignment: .leading, spacing: 14) {
                Text("机考显示设置").lumaFont(size: 13, weight: .bold)
                HStack {
                    Text("原文大小 \(Int(passageFont))pt").frame(width: 95, alignment: .leading)
                    Slider(value: $passageFont, in: 13...26, step: 1)
                }
                HStack {
                    Text("题目大小 \(Int(questionFont))pt").frame(width: 95, alignment: .leading)
                    Slider(value: $questionFont, in: 13...24, step: 1)
                }
                Divider()
                HStack(spacing: 8) {
                    Text("分屏比例").frame(width: 65, alignment: .leading)
                    Button("4:6") { splitRatio = 0.40 }.buttonStyle(.bordered)
                    Button("5:5 标准") { splitRatio = 0.50 }.buttonStyle(.borderedProminent)
                    Button("6:4") { splitRatio = 0.60 }.buttonStyle(.bordered)
                }
                .controlSize(.small)
            }
            .padding(16)
            .frame(width: 290)
        }
    }

    // MARK: - 15 种官方题型路由与差异化布局
    private func questionGroup(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        let firstID = group.id
        let lastID = group.questions.last.map { $0.id + max(0, ($0.requiredSelections ?? 1) - 1) } ?? group.id

        return VStack(alignment: .leading, spacing: 14) {
            // 官方题组头部横幅
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(verbatim: firstID == lastID ? "Question \(firstID)" : "Questions \(firstID)–\(lastID)")
                        .font(.system(size: questionFont + 3, weight: .bold))
                        .foregroundStyle(ink)
                    Spacer()
                    Text(officialTypeBadge(group.type))
                        .lumaFont(size: 11.5, weight: .semibold)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(accent)
                }
                Text(group.instruction)
                    .font(.system(size: questionFont, weight: .medium))
                    .foregroundStyle(ink.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(0.10), lineWidth: 1))

            // 按 15 种不同题型分发到各自的官方专属布局组件
            switch group.type {
            case "段落标题匹配":
                matchingHeadingsOfficialLayout(group, activeFocus: activeFocus)

            case "特征匹配", "句尾匹配":
                dragAndDropMatchingOfficialLayout(group, activeFocus: activeFocus)

            case "段落信息匹配":
                matchingInformationMatrixLayout(group, activeFocus: activeFocus)

            case "TRUE / FALSE / NOT GIVEN":
                tfngOfficialAccordionLayout(
                    group,
                    choices: [["TRUE", "TRUE"], ["FALSE", "FALSE"], ["NOT GIVEN", "NOT GIVEN"]],
                    activeFocus: activeFocus
                )

            case "YES / NO / NOT GIVEN":
                tfngOfficialAccordionLayout(
                    group,
                    choices: [["YES", "YES"], ["NO", "NO"], ["NOT GIVEN", "NOT GIVEN"]],
                    activeFocus: activeFocus
                )

            case "单选题":
                singleChoiceOfficialAccordionLayout(group, activeFocus: activeFocus)

            case "多选题":
                multipleSelectionOfficialLayout(group, activeFocus: activeFocus)

            case "表格填空":
                if let table = group.table, !table.isEmpty {
                    tableCompletionOfficialLayout(table, group: group, activeFocus: activeFocus)
                } else {
                    completion(group, activeFocus: activeFocus)
                }

            case "流程图填空":
                if let context = group.context, !context.isEmpty {
                    flowchartCompletionOfficialLayout(context, group: group, activeFocus: activeFocus)
                } else {
                    completion(group, activeFocus: activeFocus)
                }

            case "笔记填空":
                if let context = group.context, !context.isEmpty {
                    noteCompletionOfficialLayout(context, group: group, activeFocus: activeFocus)
                } else {
                    completion(group, activeFocus: activeFocus)
                }

            case "图示标注":
                if let asset = group.diagramAsset, let image = diagramImage(asset), let labels = group.diagramLabels,
                   Set(labels.map(\.id)) == Set(group.questions.map(\.id)),
                   labels.allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) }) {
                    diagramCompletion(image, labels: labels, group: group)
                } else {
                    if let asset = group.diagramAsset, let image = diagramImage(asset) {
                        Image(nsImage: image).resizable().scaledToFit().cornerRadius(8)
                    }
                    completion(group, activeFocus: activeFocus)
                }

            case "句子填空":
                sentenceCompletionOfficialLayout(group, activeFocus: activeFocus)

            case "简答题":
                shortAnswerOfficialLayout(group, activeFocus: activeFocus)

            default: // 摘要填空 (Summary Completion - 含带词库拖拽与无词库直填两种官方形态)
                completion(group, activeFocus: activeFocus)
            }
        }
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func officialTypeBadge(_ kind: String) -> String {
        switch kind {
        case "段落标题匹配": return "Matching Headings · 拖拽配对"
        case "段落信息匹配": return "Matching Information · 矩阵表格"
        case "特征匹配": return "Matching Features · 分类配对"
        case "句尾匹配": return "Matching Sentence Endings · 句尾拖拽"
        case "单选题": return "Multiple Choice · 手风琴单选"
        case "多选题": return "Multiple Selection · 组合多选"
        case "摘要填空": return "Summary Completion · 摘要填空"
        case "笔记填空": return "Note Completion · 层级大纲笔记"
        case "表格填空": return "Table Completion · 表格内联填空"
        case "流程图填空": return "Flow-chart Completion · 流程图填空"
        case "图示标注": return "Diagram Label Completion · 图示坐标"
        case "句子填空": return "Sentence Completion · 行内填空"
        case "简答题": return "Short-answer Questions · 简答输入"
        default: return kind
        }
    }

    // MARK: 题型 1：段落标题匹配 (Matching Headings)
    private func matchingHeadingsOfficialLayout(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 官方 List of Headings 卡片池
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("List of Headings")
                        .font(.system(size: questionFont + 1, weight: .bold))
                    Spacer()
                    Text("可拖拽到左侧原文段落上方或下方虚线框")
                        .lumaFont(size: 11.5)
                        .foregroundStyle(ink.opacity(0.55))
                }
                ForEach(group.options.filter { $0.count == 2 }, id: \.self) { option in
                    let token = matchToken(group, option[0])
                    let usedByQuestion = group.questions.first { answers[$0.id] == option[0] }
                    let isPicked = pickedMatch == token
                    Button {
                        pickedMatch = isPicked ? nil : token
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(ink.opacity(0.45))
                            Text(verbatim: option[0])
                                .font(.system(size: questionFont, weight: .bold))
                                .frame(minWidth: 26, alignment: .leading)
                                .foregroundStyle(accent)
                            Text(verbatim: option[1])
                                .fixedSize(horizontal: false, vertical: true)
                                .strikethrough(usedByQuestion != nil, color: ink.opacity(0.45))
                                .foregroundStyle(usedByQuestion != nil ? ink.opacity(0.45) : ink)
                            Spacer(minLength: 0)
                            if let usedByQuestion {
                                Text("Q\(usedByQuestion.id)")
                                    .lumaFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.18), in: Capsule())
                                    .foregroundStyle(accent)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isPicked ? accent.opacity(0.22) : (usedByQuestion != nil ? ink.opacity(0.03) : paper))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(isPicked ? accent : ink.opacity(0.16), lineWidth: isPicked ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .draggable(token)
                    .disabled(submitted)
                }
            }
            .padding(14)
            .background(surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.12), lineWidth: 1))

            // 对应段落的虚线放置槽（与左侧原文联动定位）
            ForEach(group.questions) { question in
                let chosen = answers[question.id, default: ""]
                let choice = group.options.first { $0.count == 2 && $0[0] == chosen }
                let isFocused = activeFocus == question.id
                let paragraph = question.prompt.split(separator: " ").last.map(String.init) ?? question.prompt

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        questionNumberBadge(question.id, isFocused: isFocused)
                        Button {
                            focusedQuestion = question.id
                            passageJump = PassageJump(paragraph: paragraph)
                        } label: {
                            HStack(spacing: 4) {
                                Text(question.prompt)
                                    .font(.system(size: questionFont, weight: .semibold))
                                Image(systemName: "arrow.up.left.square")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .help("点击定位到左侧原文段落 \(paragraph)")

                        Spacer(minLength: 4)
                        reviewFlag(question.id)
                    }

                    HStack(spacing: 8) {
                        Button {
                            focusedQuestion = question.id
                            if let pickedMatch {
                                _ = assignMatch(pickedMatch, to: question.id, group: group, reusable: false)
                            }
                        } label: {
                            HStack {
                                if let choice {
                                    Text(verbatim: choice[0])
                                        .font(.system(size: questionFont, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(accent)
                                    Text(verbatim: choice[1])
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundStyle(ink)
                                } else {
                                    Image(systemName: "plus.square.dashed")
                                        .foregroundStyle(ink.opacity(0.45))
                                    Text(pickedMatch != nil ? "点击将已选 Heading 放入此槽" : "将上方 Heading 拖放到此处 (Drop Heading here)")
                                        .foregroundStyle(ink.opacity(0.48))
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(choice != nil ? accent.opacity(0.08) : paper, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(
                                        isFocused ? accent : ink.opacity(0.32),
                                        style: choice != nil ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1.2, dash: [5, 3])
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .dropDestination(for: String.self) { items, _ in
                            guard let item = items.first else { return false }
                            focusedQuestion = question.id
                            return assignMatch(item, to: question.id, group: group, reusable: false)
                        }
                        .disabled(submitted)

                        if choice != nil && !submitted {
                            Button("清除答案", systemImage: "xmark.circle.fill") {
                                answers.removeValue(forKey: question.id)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .foregroundStyle(ink.opacity(0.45))
                        }
                    }

                    if submitted { feedback(question, options: group.options) }
                }
                .padding(10)
                .background(isFocused ? accent.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .id(question.id)
            }
        }
    }

    // MARK: 题型 2 & 3：特征匹配 (Matching Features) 与 句尾匹配 (Matching Sentence Endings)
    private func dragAndDropMatchingOfficialLayout(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        let reusable = group.instruction.localizedCaseInsensitiveContains("more than once")
            || group.instruction.localizedCaseInsensitiveContains("more than one time")
        let boxTitle = group.type == "句尾匹配" ? "List of Sentence Endings" : "List of Options / Features"

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(boxTitle).font(.system(size: questionFont + 1, weight: .bold))
                    Spacer()
                    if reusable {
                        Text("NB: 选项可重复使用 (May be used more than once)")
                            .lumaFont(size: 11.5, weight: .semibold)
                            .foregroundStyle(accent)
                    }
                }
                ForEach(group.options.filter { $0.count == 2 }, id: \.self) { option in
                    let token = matchToken(group, option[0])
                    let used = !reusable && group.questions.contains { answers[$0.id] == option[0] }
                    let isPicked = pickedMatch == token
                    Button {
                        pickedMatch = isPicked ? nil : token
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(ink.opacity(0.45))
                            Text(verbatim: option[0]).bold().foregroundStyle(accent)
                            Text(verbatim: option[1])
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(used ? ink.opacity(0.45) : ink)
                            Spacer(minLength: 0)
                            if used { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                        }
                        .padding(8)
                        .background(isPicked ? accent.opacity(0.22) : paper, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isPicked ? accent : ink.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .draggable(token)
                    .disabled(submitted)
                }
            }
            .padding(12)
            .background(surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(ink.opacity(0.12), lineWidth: 1))

            ForEach(group.questions) { question in
                let chosen = answers[question.id, default: ""]
                let choice = group.options.first { $0.count == 2 && $0[0] == chosen }
                let isFocused = activeFocus == question.id

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        questionNumberBadge(question.id, isFocused: isFocused)
                        Text(verbatim: question.prompt)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture { focusedQuestion = question.id }
                        Spacer(minLength: 4)
                        reviewFlag(question.id)
                    }
                    HStack(spacing: 8) {
                        Button {
                            focusedQuestion = question.id
                            if let pickedMatch { _ = assignMatch(pickedMatch, to: question.id, group: group, reusable: reusable) }
                        } label: {
                            HStack {
                                Text(verbatim: choice.map { "\($0[0]). \($0[1])" } ?? "将选项拖入此处或先点击上方选项再点此框")
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundStyle(choice != nil ? ink : ink.opacity(0.45))
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .padding(.horizontal, 10)
                            .background(choice != nil ? accent.opacity(0.08) : paper, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(isFocused ? accent : ink.opacity(0.32),
                                                  style: choice != nil ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            )
                        }
                        .buttonStyle(.plain)
                        .dropDestination(for: String.self) { items, _ in
                            guard let item = items.first else { return false }
                            focusedQuestion = question.id
                            return assignMatch(item, to: question.id, group: group, reusable: reusable)
                        }
                        .disabled(submitted)

                        if choice != nil && !submitted {
                            Button("清除答案", systemImage: "xmark.circle.fill") { answers.removeValue(forKey: question.id) }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                                .foregroundStyle(ink.opacity(0.45))
                        }
                    }
                    if submitted { feedback(question, options: group.options) }
                }
                .padding(8)
                .background(isFocused ? accent.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .id(question.id)
            }
        }
    }

    // MARK: 题型 4：段落信息匹配 (Matching Information - 官方矩阵网格表 Matrix Table)
    private func matchingInformationMatrixLayout(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        let letters = group.options.filter { $0.count == 2 }.map { $0[0] }
        return VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    // 表头行：题干 + 段落字母列 (A, B, C, D...)
                    GridRow {
                        Text("Statement")
                            .lumaFont(size: questionFont - 1, weight: .bold)
                            .padding(10)
                            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
                            .background(surface)
                        ForEach(letters, id: \.self) { letter in
                            Button {
                                passageJump = PassageJump(paragraph: letter)
                            } label: {
                                Text(letter)
                                    .lumaFont(size: questionFont, weight: .bold)
                                    .foregroundStyle(accent)
                                    .frame(width: 38, height: 38)
                                    .background(surface)
                            }
                            .buttonStyle(.plain)
                            .help("点击跳转到原文段落 \(letter)")
                        }
                    }
                    Divider()

                    ForEach(group.questions) { question in
                        let isFocused = activeFocus == question.id
                        let selectedLetter = answers[question.id, default: ""]
                        GridRow {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                questionNumberBadge(question.id, isFocused: isFocused)
                                Text(verbatim: question.prompt)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                reviewFlag(question.id)
                            }
                            .padding(10)
                            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
                            .background(isFocused ? accent.opacity(0.07) : paper)
                            .onTapGesture { focusedQuestion = question.id }

                            ForEach(letters, id: \.self) { letter in
                                let isChosen = selectedLetter == letter
                                Button {
                                    focusedQuestion = question.id
                                    answers[question.id] = letter
                                } label: {
                                    Image(systemName: isChosen ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(isChosen ? accent : ink.opacity(0.35))
                                        .frame(width: 38, height: 38)
                                        .background(isChosen ? accent.opacity(0.12) : (isFocused ? accent.opacity(0.05) : paper))
                                }
                                .buttonStyle(.plain)
                                .disabled(submitted)
                                .accessibilityLabel("第 \(question.id) 题，段落 \(letter)")
                            }
                        }
                        .id(question.id)
                        Divider()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(0.16), lineWidth: 1))
            }

            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    // MARK: 题型 5 & 6：判断题 (TRUE/FALSE/NOT GIVEN & YES/NO/NOT GIVEN - 官方手风琴展开布局)
    private func tfngOfficialAccordionLayout(
        _ group: IELTSReadingSample.Group,
        choices: [[String]],
        activeFocus: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(group.questions) { question in
                let isFocused = activeFocus == question.id
                let currentAns = answers[question.id, default: ""]

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                            focusedQuestion = question.id
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            questionNumberBadge(question.id, isFocused: isFocused)
                            Text(verbatim: question.prompt)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if !currentAns.isEmpty {
                                Text(currentAns)
                                    .lumaFont(size: 11.5, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(accent.opacity(0.16), in: Capsule())
                                    .foregroundStyle(accent)
                            }
                            reviewFlag(question.id)
                        }
                    }
                    .buttonStyle(.plain)

                    // 聚焦或已交卷时展开完整官方竖排 Radio 选项；非聚焦时也允许一键快捷点选
                    if isFocused || submitted || currentAns.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(choices, id: \.self) { option in
                                let selected = currentAns == option[0]
                                Button {
                                    focusedQuestion = question.id
                                    answers[question.id] = option[0]
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(selected ? accent : ink.opacity(0.45))
                                        Text(option[0])
                                            .font(.system(size: questionFont, weight: selected ? .semibold : .regular))
                                            .foregroundStyle(ink)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selected ? accent.opacity(0.12) : paper, in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? accent : ink.opacity(0.12), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(submitted)
                            }
                        }
                        .padding(.leading, 32)
                    }

                    if submitted { feedback(question, options: choices) }
                }
                .padding(12)
                .background(isFocused ? accent.opacity(0.06) : surface.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isFocused ? accent : ink.opacity(0.12), lineWidth: isFocused ? 1.5 : 1))
                .id(question.id)
            }
        }
    }

    // MARK: 题型 7：单选题 (Multiple Choice - 官方手风琴折叠卡片)
    private func singleChoiceOfficialAccordionLayout(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(group.questions) { question in
                let options = question.options.isEmpty ? group.options : question.options
                let isFocused = activeFocus == question.id
                let currentAns = answers[question.id, default: ""]

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        focusedQuestion = question.id
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            questionNumberBadge(question.id, isFocused: isFocused)
                            Text(verbatim: question.prompt)
                                .font(.system(size: questionFont, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 6)
                            if !currentAns.isEmpty {
                                Text(currentAns)
                                    .lumaFont(size: 12, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.18), in: Capsule())
                                    .foregroundStyle(accent)
                            }
                            reviewFlag(question.id)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(options.filter { $0.count == 2 }, id: \.self) { option in
                            let selected = currentAns == option[0]
                            Button {
                                focusedQuestion = question.id
                                answers[question.id] = option[0]
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(selected ? accent : ink.opacity(0.45))
                                    Text(verbatim: "\(option[0]).")
                                        .font(.system(size: questionFont, weight: .bold))
                                        .foregroundStyle(selected ? accent : ink)
                                    Text(verbatim: option[1])
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundStyle(ink)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selected ? accent.opacity(0.12) : paper, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? accent : ink.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(submitted)
                        }
                    }
                    .padding(.leading, 30)

                    if submitted { feedback(question, options: options) }
                }
                .padding(12)
                .background(isFocused ? accent.opacity(0.06) : surface.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isFocused ? accent : ink.opacity(0.12), lineWidth: isFocused ? 1.5 : 1))
                .id(question.id)
            }
        }
    }

    // MARK: 题型 8：多选题 (Multiple Selection - Choose TWO/THREE letters)
    private func multipleSelectionOfficialLayout(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(group.questions) { question in
                let options = question.options.isEmpty ? group.options : question.options
                let choices = Set(answers[question.id, default: ""].split(separator: ",").map(String.init))
                let limit = max(1, question.requiredSelections ?? 2)
                let isFocused = activeFocus == question.id

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        questionNumberBadge(question.id, isFocused: isFocused)
                        Text(verbatim: question.prompt)
                            .font(.system(size: questionFont, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        Text("已选 \(choices.count)/\(limit)")
                            .lumaFont(size: 11.5, weight: .bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(choices.count == limit ? accent.opacity(0.18) : ink.opacity(0.08), in: Capsule())
                            .foregroundStyle(choices.count == limit ? accent : ink.opacity(0.65))
                        reviewFlag(question.id)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(options.filter { $0.count == 2 }, id: \.self) { option in
                            let isChecked = choices.contains(option[0])
                            let isLocked = !isChecked && choices.count >= limit
                            Button {
                                focusedQuestion = question.id
                                var next = choices
                                if isChecked { next.remove(option[0]) }
                                else if next.count < limit { next.insert(option[0]) }
                                answers[question.id] = next.sorted().joined(separator: ",")
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(isChecked ? accent : ink.opacity(isLocked ? 0.22 : 0.45))
                                    Text(verbatim: "\(option[0]).")
                                        .font(.system(size: questionFont, weight: .bold))
                                        .foregroundStyle(isChecked ? accent : ink.opacity(isLocked ? 0.4 : 1))
                                    Text(verbatim: option[1])
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundStyle(ink.opacity(isLocked ? 0.4 : 1))
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isChecked ? accent.opacity(0.12) : paper, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isChecked ? accent : ink.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(submitted || isLocked)
                        }
                    }
                    .padding(.leading, 30)

                    if submitted { feedback(question, options: options) }
                }
                .padding(12)
                .background(isFocused ? accent.opacity(0.06) : surface.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isFocused ? accent : ink.opacity(0.12), lineWidth: isFocused ? 1.5 : 1))
                .id(question.id)
            }
        }
    }

    // MARK: 题型 9：摘要填空 (Summary Completion - 支持带词库拖拽槽与无词库行内输入框两种官方模式)
    @ViewBuilder
    private func completion(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        if let context = group.context,
           group.questions.allSatisfy({ context.contains("[\($0.id)]") }) {
            summary(context, group: group, activeFocus: activeFocus)
        } else {
            if let context = group.context {
                Text(verbatim: context)
                    .padding(12)
                    .background(paper, in: RoundedRectangle(cornerRadius: 8))
            }
            ForEach(group.questions) { question in
                answerRow(question, group: group, activeFocus: activeFocus)
                    .id(question.id)
            }
        }
    }

    private func summary(_ context: String, group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                inlineCompletion(context, group: group, activeFocus: activeFocus)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(paper, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.14), lineWidth: 1))

            // 如果带有 Word Bank 词池（Summary Completion with Word List），提供官方可拖拽/点选词库池
            if !group.options.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Word List (可拖拽或点击填入上方空格)")
                        .lumaFont(size: questionFont, weight: .bold)
                    IELTSReadingInlineFlow {
                        ForEach(group.options.filter { $0.count == 2 }, id: \.self) { option in
                            let token = matchToken(group, option[0])
                            let used = group.questions.contains { answers[$0.id] == option[0] }
                            let isPicked = pickedMatch == token
                            Button {
                                pickedMatch = isPicked ? nil : token
                                if let activeFocus, group.questions.contains(where: { $0.id == activeFocus }) {
                                    answers[activeFocus] = option[0]
                                    pickedMatch = nil
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(verbatim: option[0]).bold().foregroundStyle(accent)
                                    Text(verbatim: option[1])
                                        .strikethrough(used, color: ink.opacity(0.4))
                                        .foregroundStyle(used ? ink.opacity(0.45) : ink)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isPicked ? accent.opacity(0.22) : paper, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isPicked ? accent : ink.opacity(0.20), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .draggable(token)
                            .disabled(submitted)
                        }
                    }
                }
                .padding(12)
                .background(surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
            }

            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    // MARK: 题型 10：表格填空 (Table Completion - 官方网格边框表格)
    private func tableCompletionOfficialLayout(_ rows: [[String]], group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                    ForEach(rows.indices, id: \.self) { row in
                        GridRow {
                            ForEach(rows[row].indices, id: \.self) { column in
                                inlineCompletion(rows[row][column], group: group, activeFocus: activeFocus)
                                    .frame(minWidth: max(165, questionFont * 7), maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(row == 0 ? surface : paper)
                                    .fontWeight(row == 0 ? .bold : .regular)
                            }
                        }
                    }
                }
                .background(ink.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(0.20), lineWidth: 1))
            }
            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    // MARK: 题型 11：流程图填空 (Flow-chart Completion - 官方步骤卡片 + 垂直流向箭头)
    private func flowchartCompletionOfficialLayout(_ context: String, group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        let lines = context.split(whereSeparator: \.isNewline).map(String.init)
        return VStack(alignment: .center, spacing: 6) {
            ForEach(lines.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accent)
                        .padding(.vertical, 2)
                }
                HStack(alignment: .center, spacing: 10) {
                    Text("Step \(index + 1)")
                        .lumaFont(size: 11, weight: .bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(accent)
                    inlineCompletion(lines[index], group: group, activeFocus: activeFocus)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(paper, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(ink.opacity(0.18), lineWidth: 1.2))
            }
            if submitted {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.questions) { feedback($0, options: group.options) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
        }
    }

    // MARK: 题型 12：笔记填空 (Note Completion - 官方层级项目符号大纲布局)
    private func noteCompletionOfficialLayout(_ context: String, group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        let lines = context.split(whereSeparator: \.isNewline).map(String.init)
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines.indices, id: \.self) { index in
                    let raw = lines[index].trimmingCharacters(in: .whitespaces)
                    let isBullet = raw.hasPrefix("•") || raw.hasPrefix("-") || raw.contains("[")
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if isBullet {
                            Text("•")
                                .font(.system(size: questionFont + 2, weight: .bold))
                                .foregroundStyle(accent)
                                .padding(.leading, 8)
                        }
                        inlineCompletion(raw.trimmingCharacters(in: CharacterSet(charactersIn: "•- ")), group: group, activeFocus: activeFocus)
                            .fontWeight(isBullet ? .regular : .bold)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(paper, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.16), lineWidth: 1))

            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    // MARK: 题型 13：句子填空 (Sentence Completion)
    private func sentenceCompletionOfficialLayout(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(group.questions) { question in
                let isFocused = activeFocus == question.id
                VStack(alignment: .leading, spacing: 6) {
                    if question.prompt.contains("[\(question.id)]") {
                        inlineCompletion(question.prompt, group: group, activeFocus: activeFocus)
                    } else {
                        answerRow(question, group: group, activeFocus: activeFocus)
                    }
                    if submitted { feedback(question, options: group.options) }
                }
                .padding(12)
                .background(isFocused ? accent.opacity(0.06) : paper, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isFocused ? accent : ink.opacity(0.13), lineWidth: 1))
                .id(question.id)
            }
        }
    }

    // MARK: 题型 14：简答题 (Short-answer Questions)
    private func shortAnswerOfficialLayout(_ group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(group.questions) { question in
                let isFocused = activeFocus == question.id
                VStack(alignment: .leading, spacing: 8) {
                    questionLabel(question, isFocused: isFocused)
                    answerField(question.id, label: "输入简答词组...", isFocused: isFocused)
                        .frame(maxWidth: 320)
                        .padding(.leading, 30)
                    if submitted { feedback(question, options: []) }
                }
                .padding(12)
                .background(isFocused ? accent.opacity(0.06) : paper, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isFocused ? accent : ink.opacity(0.13), lineWidth: 1))
                .id(question.id)
            }
        }
    }

    // MARK: 题型 15：图示标注 (Diagram Label Completion)
    private func diagramImage(_ asset: String) -> NSImage? {
        if let url = Bundle.module.url(forResource: asset, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return Bundle.module.image(forResource: NSImage.Name(asset))
    }

    private func diagramCompletion(_ image: NSImage, labels: [IELTSReadingSample.Group.DiagramLabel],
                                   group: IELTSReadingSample.Group) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / max(1, image.size.height), contentMode: .fit)
                    .frame(width: 460)
                    .overlay {
                        GeometryReader { geometry in
                            ForEach(labels) { label in
                                let isFocused = focusedQuestion == label.id
                                HStack(spacing: 4) {
                                    questionNumberBadge(label.id, isFocused: isFocused)
                                    answerField(label.id, label: "答案", isFocused: isFocused)
                                        .frame(width: 96)
                                    reviewFlag(label.id)
                                }
                                .padding(5)
                                .background(paper, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isFocused ? accent : ink.opacity(0.25), lineWidth: 1.2))
                                .fixedSize()
                                .position(x: min(max(75, geometry.size.width * label.x), geometry.size.width - 75),
                                          y: min(max(24, geometry.size.height * label.y), geometry.size.height - 24))
                                .id(label.id)
                            }
                        }
                    }
                    .padding(.vertical, 6)
            }
            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    private func matchToken(_ group: IELTSReadingSample.Group, _ option: String) -> String {
        "luma-ielts-match:\(group.id):\(option)"
    }

    @discardableResult
    private func assignMatch(_ token: String, to id: Int, group: IELTSReadingSample.Group, reusable: Bool) -> Bool {
        guard !submitted, group.questions.contains(where: { $0.id == id }),
              let option = group.options.first(where: { $0.count == 2 && matchToken(group, $0[0]) == token })
        else { return false }
        var updated = answers
        if !reusable {
            for question in group.questions where question.id != id && updated[question.id] == option[0] {
                updated.removeValue(forKey: question.id)
            }
        }
        updated[id] = option[0]
        answers = updated
        pickedMatch = nil
        return true
    }

    // MARK: - 官方行内空白槽渲染器（支持直接输入或从词库拖入）
    private func inlineCompletion(_ context: String, group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        let segments = summarySegments(context, questions: group.questions)
        return IELTSReadingInlineFlow {
            ForEach(segments.indices, id: \.self) { index in
                switch segments[index] {
                case let .word(word):
                    Text(verbatim: word)
                case let .blank(id):
                    let isFocused = activeFocus == id
                    HStack(spacing: 5) {
                        questionNumberBadge(id, isFocused: isFocused)
                        if group.options.isEmpty {
                            answerField(id, label: "\(id)", isFocused: isFocused)
                                .frame(width: max(92, questionFont * 6))
                        } else {
                            let currentCode = answers[id, default: ""]
                            let matched = group.options.first { $0.count == 2 && $0[0] == currentCode }
                            Menu {
                                Button("清空 (Clear)") { answers.removeValue(forKey: id) }
                                Divider()
                                ForEach(group.options.filter { $0.count == 2 }, id: \.self) { option in
                                    Button("\(option[0]) — \(option[1])") {
                                        focusedQuestion = id
                                        answers[id] = option[0]
                                    }
                                }
                            } label: {
                                Text(matched.map { "\($0[0]) (\($0[1]))" } ?? "拖入或选择")
                                    .lumaFont(size: questionFont - 1, weight: .semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .frame(minWidth: 96)
                                    .background(matched != nil ? accent.opacity(0.14) : surface, in: RoundedRectangle(cornerRadius: 5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .strokeBorder(isFocused ? accent : ink.opacity(0.32),
                                                          style: matched != nil ? StrokeStyle(lineWidth: 1.4) : StrokeStyle(lineWidth: 1, dash: [4, 2]))
                                    )
                            }
                            .buttonStyle(.plain)
                            .dropDestination(for: String.self) { items, _ in
                                guard let item = items.first else { return false }
                                focusedQuestion = id
                                return assignMatch(item, to: id, group: group, reusable: false)
                            }
                            .disabled(submitted)
                        }
                        reviewFlag(id)
                    }
                    .id(id)
                }
            }
        }
    }

    private enum SummarySegment {
        case word(String), blank(Int)
    }

    private func summarySegments(_ context: String, questions: [IELTSReadingSample.Group.Question]) -> [SummarySegment] {
        let source = context as NSString
        let pattern = try? NSRegularExpression(pattern: #"\[(\d+)\]"#)
        let ids = Set(questions.map(\.id))
        var cursor = 0
        var segments: [SummarySegment] = []
        for match in pattern?.matches(in: context, range: NSRange(location: 0, length: source.length)) ?? [] {
            guard let id = Int(source.substring(with: match.range(at: 1))), ids.contains(id) else { continue }
            let prefix = source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            segments += prefix.split(whereSeparator: \.isWhitespace).map { .word(String($0)) }
            segments.append(.blank(id))
            cursor = NSMaxRange(match.range)
        }
        segments += source.substring(from: cursor).split(whereSeparator: \.isWhitespace).map { .word(String($0)) }
        return segments
    }

    private func response(for id: Int) -> Binding<String> {
        Binding(
            get: { answers[id, default: ""] },
            set: { newValue in
                focusedQuestion = id
                answers[id] = newValue
            }
        )
    }

    private func questionNumberBadge(_ id: Int, isFocused: Bool) -> some View {
        Text(id.formatted())
            .lumaFont(size: questionFont - 1, weight: .bold)
            .monospacedDigit()
            .foregroundStyle(isFocused ? paper : ink)
            .frame(minWidth: 24, minHeight: 22)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isFocused ? accent : ink.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isFocused ? accent : ink.opacity(0.25), lineWidth: 1)
            )
    }

    private func reviewFlag(_ id: Int) -> some View {
        let flagged = markedQuestions.contains(id)
        return Button {
            if !markedQuestions.insert(id).inserted { markedQuestions.remove(id) }
        } label: {
            Image(systemName: flagged ? "flag.fill" : "flag")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(flagged ? Color.orange : ink.opacity(0.42))
        }
        .buttonStyle(.plain)
        .help("标记待复查 (Review)")
        .accessibilityLabel("标记第 \(id) 题待复查")
    }

    private func questionLabel(_ question: IELTSReadingSample.Group.Question, isFocused: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            questionNumberBadge(question.id, isFocused: isFocused)
            Text(verbatim: question.prompt)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            reviewFlag(question.id)
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedQuestion = question.id }
    }

    private func answerField(_ id: Int, label: String = "输入答案", isFocused: Bool = false) -> some View {
        TextField(label, text: response(for: id))
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(paper, in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isFocused ? accent : ink.opacity(0.32), lineWidth: isFocused ? 1.6 : 1)
            )
            .autocorrectionDisabled()
            .accessibilityLabel("第 \(id) 题")
            .disabled(submitted)
    }

    private func answerRow(_ question: IELTSReadingSample.Group.Question, group: IELTSReadingSample.Group, activeFocus: Int?) -> some View {
        let isFocused = activeFocus == question.id
        return VStack(alignment: .leading, spacing: 7) {
            questionLabel(question, isFocused: isFocused)
            answerField(question.id, isFocused: isFocused)
            if submitted { feedback(question, options: []) }
        }
    }

    private func feedback(_ question: IELTSReadingSample.Group.Question, options: [[String]]) -> some View {
        let correct = question.isCorrect(answers[question.id, default: ""])
        let expected = options.first { $0.first == question.answer }?.last ?? question.answer
        return HStack(spacing: 6) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(correct
                 ? "第 \(question.id) 题正确 (\(question.answer))"
                 : "第 \(question.id) 题正确答案：\(question.answer == expected ? expected : question.answer + " · " + expected)")
        }
        .lumaFont(size: questionFont - 1, weight: .semibold)
        .foregroundStyle(correct ? Color.green : Color.red)
        .padding(.top, 4)
    }

    private func groupTitle(_ group: IELTSReadingSample.Group) -> String {
        "\(group.type) · Questions \(group.id)–\(group.questions.last?.id ?? group.id)"
    }

    private func open(_ sample: IELTSReadingSample) {
        enabledGroups = Set(sample.groups.filter { type == "全部" || $0.type == type }.map(\.id))
        setPracticingState(false)
        selected = sample
    }
}

private struct IELTSReadingInlineFlow: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 440, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(width: bounds.width, subviews: subviews)
        for (view, point) in zip(subviews, result.origins) {
            view.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                       anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var rowStart = 0
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        for (index, size) in sizes.enumerated() {
            if x > 0 && x + size.width > width {
                for j in rowStart..<index { origins[j].y += (lineHeight - sizes[j].height) / 2 }
                x = 0
                y += lineHeight + 6
                lineHeight = 0
                rowStart = index
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + 4
            lineHeight = max(lineHeight, size.height)
        }
        for j in rowStart..<sizes.count { origins[j].y += (lineHeight - sizes[j].height) / 2 }
        return (CGSize(width: width, height: y + lineHeight), origins)
    }
}

@MainActor
private struct IELTSReadingPassage: NSViewRepresentable {
    let text: String
    @Binding var highlights: [StudyTextHighlight]
    let appearance: StudyAppearance
    let fontSize: CGFloat
    let jump: IELTSReadingPractice.PassageJump?

    final class Coordinator {
        var lastJump: IELTSReadingPractice.PassageJump?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.backgroundColor = NSColor(appearance.paper)
        scroll.drawsBackground = true
        let reader = LumaPromptInteractiveTextView(usingTextLayoutManager: false)
        reader.frame = scroll.contentView.bounds
        reader.positionsActionsBelowSelection = true
        reader.isEditable = false
        reader.isSelectable = true
        reader.isRichText = false
        reader.drawsBackground = false
        reader.textContainerInset = NSSize(width: 26, height: 20)
        reader.minSize = .zero
        reader.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        reader.isVerticallyResizable = true
        reader.isHorizontallyResizable = false
        reader.autoresizingMask = [.width]
        reader.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        reader.textContainer?.widthTracksTextView = true
        scroll.documentView = reader
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let reader = scroll.documentView as? LumaPromptInteractiveTextView else { return }
        scroll.backgroundColor = NSColor(appearance.paper)
        reader.onHighlightsChanged = { highlights = $0 }
        reader.render(text: text, highlights: highlights, appearance: appearance, fontSize: fontSize)
        if let jump, jump != context.coordinator.lastJump {
            context.coordinator.lastJump = jump
            let source = text as NSString
            let paragraph = NSRegularExpression.escapedPattern(for: jump.paragraph)
            let match = source.range(of: "(?m)^[ \t]*" + paragraph + "(?=\\s|$)", options: .regularExpression)
            if match.location != NSNotFound {
                reader.closeActions()
                reader.scrollRangeToVisible(match)
            }
        }
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        (scroll.documentView as? LumaPromptInteractiveTextView)?.closeActions()
    }
}