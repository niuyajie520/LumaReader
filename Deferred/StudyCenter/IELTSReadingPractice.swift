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
    @State private var type = "全部"
    @State private var search = ""
    @State private var focusedQuestion: Int?
    @State private var pickedMatch: String?
    @State private var passageJump: PassageJump?

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
        focusedQuestion = nil
        pickedMatch = nil
        passageJump = nil
        practicing = true
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

    private var paper: Color {
        appearance.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(red: 0.99, green: 0.98, blue: 0.95)
    }

    private var ink: Color {
        appearance.isDark ? Color(white: 0.94) : Color(white: 0.12)
    }

    private var paperAppearance: StudyAppearance {
        var result = appearance
        result.paper = paper
        result.ink = ink
        return result
    }

    private let types = ["段落标题匹配", "段落信息匹配", "特征匹配", "单选题", "摘要填空",
                         "TRUE / FALSE / NOT GIVEN", "YES / NO / NOT GIVEN", "多选题", "句尾匹配",
                         "句子填空", "笔记填空", "表格填空", "流程图填空", "图示标注", "简答题"]

    var body: some View {
        Group {
            if let sample = selected {
                if practicing { practice(sample) } else { selection(sample) }
            } else {
                catalog
            }
        }
        .padding(practicing ? 14 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(ink)
        .tint(appearance.accent)
        .background(paper)
        .environment(\.colorScheme, appearance.isDark ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in pauseClock() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.AppDidResignActive"))) { _ in pauseClock() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in pauseClock() }
        .onDisappear { pauseClock() }
        .onChange(of: answers) { _, _ in saveDraft() }
        .onChange(of: markedQuestions) { _, _ in saveDraft() }
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("雅思阅读").lumaFont(size: 30, weight: .bold)
                Spacer()
                if let sample = IELTSReadingSample.layoutSample {
                    Button("题型样例", systemImage: "rectangle.split.2x1") {
                        enabledGroups = []
                        selected = sample
                    }
                    .buttonStyle(.bordered)
                }
            }
            if let samples = IELTSReadingSample.catalog {
                if let draft = drafts.first, let sample = samples.first(where: { $0.id == draft.sampleID }) {
                    Button {
                        resume(draft, sample: sample)
                    } label: {
                        Label("继续练习 · \(sample.title)", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                HStack(spacing: 14) {
                    TextField("搜索文章标题或目录编号", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Picker("题型", selection: $type) {
                        Text("全部题型").tag("全部")
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
                Text("\(matches.count) 篇文章").font(.caption).foregroundStyle(.secondary)
                if matches.isEmpty {
                    ContentUnavailableView("没有符合筛选条件的文章", systemImage: "text.magnifyingglass")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(matches) { sample in
                                Button { open(sample) } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(sample.title).lumaFont(size: 17, weight: .semibold)
                                        Text("目录第 \(sample.id) 篇 · \(sample.groups.flatMap(\.questions).count) 题")
                                            .foregroundStyle(.secondary)
                                        Text(sample.groups.map(\.type).joined(separator: " · "))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(appearance.surface, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("无法读取阅读题库", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func selection(_ sample: IELTSReadingSample) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button("返回题库", systemImage: "chevron.left") { selected = nil }
            let isLayoutSample = sample.id == IELTSReadingSample.layoutSample?.id
            Text(isLayoutSample ? "题型样例" : sample.title).lumaFont(size: 24, weight: .semibold)
            if !isLayoutSample {
                Text("PDF 第 \(sample.pages) 页").foregroundStyle(.secondary)
            }
            HStack {
                Button("全选") { enabledGroups = Set(sample.groups.map(\.id)) }
                Button("清空") { enabledGroups.removeAll() }
                Spacer()
                Text("已选 \(sample.groups.filter { enabledGroups.contains($0.id) }.flatMap(\.questions).count) 题")
                    .foregroundStyle(.secondary)
            }
            Form {
                Section(isLayoutSample ? "选择要试做的题型" : "选择这篇文章要练的题组") {
                    ForEach(sample.groups) { group in
                        Toggle(groupTitle(group), isOn: Binding(
                            get: { enabledGroups.contains(group.id) },
                            set: { enabled in
                                if enabled { enabledGroups.insert(group.id) }
                                else { enabledGroups.remove(group.id) }
                            }
                        ))
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 250)
            if let draft = drafts.first(where: { $0.sampleID == sample.id }) {
                Button("继续本篇练习") { resume(draft, sample: sample) }
                    .buttonStyle(.borderedProminent)
            }
            Button(drafts.contains { $0.sampleID == sample.id } ? "开始新一轮" : "开始练习") {
                answers = [:]
                submitted = false
                elapsed = 0
                markedQuestions.removeAll()
                focusedQuestion = nil
                pickedMatch = nil
                passageJump = nil
                resumeClock()
                practicing = true
                saveDraft()
            }
            .buttonStyle(.bordered)
            .disabled(enabledGroups.isEmpty)
        }
    }

    private func practice(_ sample: IELTSReadingSample) -> some View {
        let groups = sample.groups.filter { enabledGroups.contains($0.id) }
        let questions = groups.flatMap(\.questions)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("题组", systemImage: "chevron.left") { pauseClock(); practicing = false }
                Spacer()
                Text("\(questions.filter { hasAnswer($0.id) }.count)/\(questions.count) 已答")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                clock
                fontControls
                if submitted {
                    let score = questions.filter { $0.isCorrect(answers[$0.id, default: ""]) }.count
                    Text("答对 \(score) / \(questions.count)").monospacedDigit()
                } else {
                    Button("交卷") {
                        if questions.allSatisfy({ hasAnswer($0.id) }) { submit() }
                        else { confirmSubmission = true }
                    }.buttonStyle(.borderedProminent)
                }
            }
            Divider()

            ScrollViewReader { reader in
                VStack(spacing: 10) {
                    HSplitView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(sample.title)
                                .font(.system(size: 23, weight: .semibold, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 26)
                                .padding(.vertical, 14)
                            Divider()
                            IELTSReadingPassage(
                                text: sample.text, highlights: annotations(for: sample.id),
                                appearance: paperAppearance, fontSize: CGFloat(passageFont), jump: passageJump
                            )
                            .id(sample.id)
                        }
                        .frame(minWidth: 210, idealWidth: 510, maxHeight: .infinity)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(groups) { group in
                                    questionGroup(group)
                                }
                                if submitted { Text(sample.notes).foregroundStyle(.secondary) }
                            }
                            .font(.system(size: questionFont))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                        }
                        .frame(minWidth: 230, idealWidth: 390)
                    }
                    Divider()
                    HStack {
                        if !submitted {
                            Button("未答题") {
                                if let question = questions.first(where: { !hasAnswer($0.id) }) {
                                    focusedQuestion = question.id
                                    reader.scrollTo(question.id, anchor: .top)
                                }
                            }
                            .disabled(questions.allSatisfy { hasAnswer($0.id) })
                        }
                        Button(submitted ? "下一道错题" : "下一道待复查") {
                            let targets = questions.filter {
                                submitted ? !$0.isCorrect(answers[$0.id, default: ""]) : markedQuestions.contains($0.id)
                            }
                            if let question = targets.first(where: { $0.id > (focusedQuestion ?? 0) }) ?? targets.first {
                                focusedQuestion = question.id
                                reader.scrollTo(question.id, anchor: .top)
                            }
                        }
                        .disabled(!questions.contains {
                            submitted ? !$0.isCorrect(answers[$0.id, default: ""]) : markedQuestions.contains($0.id)
                        })
                        Spacer(minLength: 0)
                    }
                    .controlSize(.small)
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(questions) { question in
                                let answered = hasAnswer(question.id)
                                Button {
                                    focusedQuestion = question.id
                                    reader.scrollTo(question.id, anchor: .top)
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(question.id.formatted()).monospacedDigit()
                                        if submitted && !question.isCorrect(answers[question.id, default: ""]) { Image(systemName: "xmark.circle").font(.caption2) }
                                        if markedQuestions.contains(question.id) { Image(systemName: "flag.fill").font(.caption2) }
                                    }
                                    .padding(6)
                                    .background(answered ? appearance.accent.opacity(0.2) : appearance.surface,
                                                in: RoundedRectangle(cornerRadius: 6))
                                }
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focusedQuestion == question.id ? appearance.accent : .clear, lineWidth: 1.5))
                                .buttonStyle(.plain)
                                .accessibilityLabel("第 \(question.id) 题，\(answered ? "已答" : "未答")\(markedQuestions.contains(question.id) ? "，待复查" : "")")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .confirmationDialog("还有 \(questions.filter { !hasAnswer($0.id) }.count) 题未答", isPresented: $confirmSubmission, titleVisibility: .visible) {
            Button("仍然交卷", role: .destructive) { submit() }
            Button("继续作答", role: .cancel) {}
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


    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let running = startedAt != nil
            let seconds = Int(elapsed + (startedAt.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0))
            Button {
                if running { pauseClock() } else { resumeClock() }
            } label: {
                Label(String(format: "%02d:%02d", seconds / 60, seconds % 60),
                      systemImage: running ? "pause.circle" : "play.circle")
                    .monospacedDigit()
            }
            .disabled(submitted)
            .help(running ? "暂停计时" : "继续计时")
        }
    }

    private var fontControls: some View {
        Button { showFontControls.toggle() } label: {
            Image(systemName: "textformat.size")
        }
        .accessibilityLabel("字号")
        .popover(isPresented: $showFontControls) {
            VStack(alignment: .leading, spacing: 14) {
                Slider(value: $passageFont, in: 12...30, step: 1) { Text("原文 \(Int(passageFont))") }
                Slider(value: $questionFont, in: 12...30, step: 1) { Text("题目 \(Int(questionFont))") }
            }
            .padding(16)
            .frame(width: 275)
        }
    }

    private func questionGroup(_ group: IELTSReadingSample.Group) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: "Questions \(group.id)–\(group.questions.last?.id ?? group.id)")
                .font(.system(size: questionFont + 3, weight: .bold))
            Text(group.instruction).fixedSize(horizontal: false, vertical: true)
            switch group.type {
            case "段落标题匹配", "特征匹配", "句尾匹配":
                matchingGroup(group)
            case "段落信息匹配":
                ForEach(group.questions) { question in
                    selectionRow(question, options: group.options, compact: true)
                        .id(question.id)
                }
            case "表格填空":
                if let table = group.table, !table.isEmpty {
                    tableCompletion(table, group: group)
                } else {
                    completion(group)
                }
            case "流程图填空", "笔记填空":
                if let context = group.context, !context.isEmpty {
                    structuredCompletion(context, group: group)
                } else {
                    completion(group)
                }
            case "图示标注":
                if let asset = group.diagramAsset, let image = diagramImage(asset), let labels = group.diagramLabels,
                   Set(labels.map(\.id)) == Set(group.questions.map(\.id)),
                   labels.allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) }) {
                    diagramCompletion(image, labels: labels, group: group)
                } else {
                    if let asset = group.diagramAsset, let image = diagramImage(asset) {
                        Image(nsImage: image).resizable().scaledToFit()
                    }
                    completion(group)
                }
            case "句子填空":
                ForEach(group.questions) { question in
                    if question.prompt.contains("[\(question.id)]") {
                        inlineCompletion(question.prompt, group: group)
                        if submitted { feedback(question, options: group.options) }
                    } else {
                        answerRow(question, group: group).id(question.id)
                    }
                }
            case "简答题":
                ForEach(group.questions) { question in
                    answerRow(question, group: group).id(question.id)
                }
            default:
                completion(group)
            }
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func completion(_ group: IELTSReadingSample.Group) -> some View {
        if let context = group.context,
           group.questions.allSatisfy({ context.contains("[\($0.id)]") }) {
            summary(context, group: group)
        } else {
            if let context = group.context { Text(verbatim: context) }
            ForEach(group.questions) { question in
                answerRow(question, group: group)
                    .id(question.id)
            }
        }
    }

    private func tableCompletion(_ rows: [[String]], group: IELTSReadingSample.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                    ForEach(rows.indices, id: \.self) { row in
                        GridRow {
                            ForEach(rows[row].indices, id: \.self) { column in
                                inlineCompletion(rows[row][column], group: group)
                                    .frame(width: max(150, questionFont * 6 + 36), alignment: .leading)
                                    .padding(8)
                                    .background(ink.opacity(row == 0 ? 0.13 : 0.055))
                                    .fontWeight(row == 0 ? .semibold : .regular)
                            }
                        }
                    }
                }
            }
            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    private func diagramImage(_ asset: String) -> NSImage? {
        if let url = Bundle.module.url(forResource: asset, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return Bundle.module.image(forResource: NSImage.Name(asset))
    }

    private func diagramCompletion(_ image: NSImage, labels: [IELTSReadingSample.Group.DiagramLabel],
                                   group: IELTSReadingSample.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(image.size.width / max(1, image.size.height), contentMode: .fit)
                    .frame(width: 420)
                    .overlay {
                        GeometryReader { geometry in
                            ForEach(labels) { label in
                                HStack(spacing: 4) {
                                    Text(label.id.formatted()).bold()
                                    answerField(label.id, label: "答案").frame(width: 82)
                                    reviewFlag(label.id)
                                }
                                .padding(4)
                                .background(paper)
                                .fixedSize()
                                .position(x: min(max(67, geometry.size.width * label.x), geometry.size.width - 67),
                                          y: min(max(21, geometry.size.height * label.y), geometry.size.height - 21))
                                .id(label.id)
                            }
                        }
                    }
                    .padding(.vertical, 5)
            }
            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    private func structuredCompletion(_ context: String, group: IELTSReadingSample.Group) -> some View {
        let lines = context.split(whereSeparator: \.isNewline).map(String.init)
        let flowchart = group.type == "流程图填空"
        return VStack(alignment: .leading, spacing: 7) {
            ForEach(lines.indices, id: \.self) { index in
                if flowchart && index > 0 {
                    Image(systemName: "arrow.down").frame(maxWidth: .infinity)
                }
                inlineCompletion(lines[index], group: group)
                    .padding(flowchart ? 9 : 0)
                    .background(flowchart ? ink.opacity(0.06) : .clear)
            }
            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    private func matchToken(_ group: IELTSReadingSample.Group, _ option: String) -> String {
        "luma-ielts-match:\(group.id):\(option)"
    }

    private func matchingGroup(_ group: IELTSReadingSample.Group) -> some View {
        let headings = group.type == "段落标题匹配"
        let reusable = !headings && (
            group.instruction.localizedCaseInsensitiveContains("more than once")
            || group.instruction.localizedCaseInsensitiveContains("more than one time")
        )
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(headings ? "List of Headings" : group.type == "句尾匹配" ? "List of Endings" : "Options").bold()
                ForEach(group.options.filter { $0.count == 2 }, id: \.self) { option in
                    let token = matchToken(group, option[0])
                    let used = !reusable && group.questions.contains { answers[$0.id] == option[0] }
                    Button {
                        pickedMatch = pickedMatch == token ? nil : token
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "line.3.horizontal")
                            Text(verbatim: option[0]).bold()
                            Text(verbatim: option[1]).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if used { Image(systemName: "checkmark") }
                        }
                        .padding(7)
                        .background(pickedMatch == token ? appearance.accent.opacity(0.23) : ink.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .draggable(token)
                    .disabled(submitted)
                }
            }
            .textSelection(.disabled)
            ForEach(group.questions) { question in
                let chosen = answers[question.id, default: ""]
                let choice = group.options.first { $0.count == 2 && $0[0] == chosen }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(question.id.formatted()).bold()
                        if headings, let paragraph = question.prompt.split(separator: " ").last {
                            Button(question.prompt) { passageJump = PassageJump(paragraph: String(paragraph)) }
                                .buttonStyle(.link)
                        } else {
                            Text(verbatim: question.prompt).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        reviewFlag(question.id)
                    }
                    HStack {
                        Button {
                            if let pickedMatch { _ = assignMatch(pickedMatch, to: question.id, group: group, reusable: reusable) }
                        } label: {
                            Text(verbatim: choice.map { "\($0[0])  \($0[1])" } ?? "Drop here")
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                                .padding(.horizontal, 8)
                                .background(ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(ink.opacity(0.33), style: StrokeStyle(dash: [4, 3])))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(question.id) 题，\(choice?.last ?? "未作答")")
                        .dropDestination(for: String.self) { items, _ in
                            guard let item = items.first else { return false }
                            return assignMatch(item, to: question.id, group: group, reusable: reusable)
                        }
                        .disabled(submitted)
                        if choice != nil && !submitted {
                            Button("清除答案", systemImage: "xmark.circle") { answers.removeValue(forKey: question.id) }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                        }
                    }
                    if submitted { feedback(question, options: group.options) }
                }
                .id(question.id)
            }
        }
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

    private func summary(_ context: String, group: IELTSReadingSample.Group) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            inlineCompletion(context, group: group)
            if !group.options.isEmpty {
                IELTSReadingInlineFlow {
                    ForEach(group.options.filter { $0.count == 2 }, id: \.self) { option in
                        Text(verbatim: "\(option[0])  \(option[1])")
                            .padding(5)
                            .background(ink.opacity(0.06))
                    }
                }
            }
            if submitted {
                ForEach(group.questions) { feedback($0, options: group.options) }
            }
        }
    }

    private func inlineCompletion(_ context: String, group: IELTSReadingSample.Group) -> some View {
        let segments = summarySegments(context, questions: group.questions)
        return IELTSReadingInlineFlow {
            ForEach(segments.indices, id: \.self) { index in
                switch segments[index] {
                case let .word(word):
                    Text(verbatim: word)
                case let .blank(id):
                    HStack(spacing: 5) {
                        Text(id.formatted()).bold()
                        if group.options.isEmpty {
                            answerField(id, label: "答案").frame(width: max(75, questionFont * 5))
                        } else {
                            Picker("第 \(id) 题", selection: response(for: id)) {
                                Text("—").tag("")
                                ForEach(group.options.filter { $0.count == 2 }, id: \.self) { option in
                                    Text(verbatim: option[0]).tag(option[0])
                                }
                            }
                            .labelsHidden()
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
        Binding(get: { answers[id, default: ""] }, set: { answers[id] = $0 })
    }

    private func reviewFlag(_ id: Int) -> some View {
        Button {
            if !markedQuestions.insert(id).inserted { markedQuestions.remove(id) }
        } label: {
            Image(systemName: markedQuestions.contains(id) ? "flag.fill" : "flag")
                .foregroundStyle(ink)
        }
        .buttonStyle(.plain)
        .help("标记待复查")
        .accessibilityLabel("标记第 \(id) 题待复查")
    }

    private func questionLabel(_ question: IELTSReadingSample.Group.Question) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(question.id.formatted()).bold()
            Text(verbatim: question.prompt).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            reviewFlag(question.id)
        }
    }

    private func answerField(_ id: Int, label: String = "输入答案") -> some View {
        TextField(label, text: response(for: id))
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .accessibilityLabel("第 \(id) 题")
            .disabled(submitted)
    }

    private func answerRow(_ question: IELTSReadingSample.Group.Question, group: IELTSReadingSample.Group) -> some View {
        let options = question.options.isEmpty ? group.options : question.options
        return Group {
            if group.type == "多选题" {
                multipleSelectionRow(question, options: options)
            } else if !options.isEmpty {
                selectionRow(question, options: options, compact: false)
            } else if group.type == "TRUE / FALSE / NOT GIVEN" {
                selectionRow(question, options: [["TRUE", "TRUE"], ["FALSE", "FALSE"], ["NOT GIVEN", "NOT GIVEN"]], compact: false)
            } else if group.type == "YES / NO / NOT GIVEN" {
                selectionRow(question, options: [["YES", "YES"], ["NO", "NO"], ["NOT GIVEN", "NOT GIVEN"]], compact: false)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    questionLabel(question)
                    answerField(question.id)
                    if submitted { feedback(question, options: []) }
                }
            }
        }
    }

    private func selectionRow(_ question: IELTSReadingSample.Group.Question, options: [[String]], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            questionLabel(question)
            if compact {
                IELTSReadingInlineFlow {
                    ForEach(options.filter { $0.count == 2 }, id: \.self) { option in
                        let selected = answers[question.id] == option[0]
                        Button(option[0]) { answers[question.id] = option[0] }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selected ? appearance.accent.opacity(0.27) : ink.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 4))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .disabled(submitted)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(options.filter { $0.count == 2 }, id: \.self) { option in
                        let selected = answers[question.id] == option[0]
                        Button { answers[question.id] = option[0] } label: {
                            Label(option[0] == option[1] ? option[0] : "\(option[0]). \(option[1])",
                                  systemImage: selected ? "largecircle.fill.circle" : "circle")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .disabled(submitted)
            }
            if submitted { feedback(question, options: options) }
        }
    }

    private func multipleSelectionRow(_ question: IELTSReadingSample.Group.Question, options: [[String]]) -> some View {
        let choices = Set(answers[question.id, default: ""].split(separator: ",").map(String.init))
        let limit = max(1, question.requiredSelections ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            questionLabel(question)
            ForEach(options.filter { $0.count == 2 }, id: \.self) { option in
                Toggle("\(option[0]). \(option[1])", isOn: Binding {
                    choices.contains(option[0])
                } set: { selected in
                    var next = Set(answers[question.id, default: ""].split(separator: ",").map(String.init))
                    if selected, next.count < limit { next.insert(option[0]) }
                    if !selected { next.remove(option[0]) }
                    answers[question.id] = next.sorted().joined(separator: ",")
                })
                .toggleStyle(.checkbox)
                .disabled(submitted || (!choices.contains(option[0]) && choices.count >= limit))
            }
            if submitted { feedback(question, options: options) }
        }
    }

    private func feedback(_ question: IELTSReadingSample.Group.Question, options: [[String]]) -> some View {
        let correct = question.isCorrect(answers[question.id, default: ""])
        let expected = options.first { $0.first == question.answer }?.last ?? question.answer
        return Label(correct ? "第 \(question.id) 题正确" : "第 \(question.id) 题答案：\(question.answer == expected ? expected : question.answer + " · " + expected)",
                     systemImage: correct ? "checkmark.circle" : "xmark.circle")
            .foregroundStyle(correct ? ink : Color.red)
    }

    private func groupTitle(_ group: IELTSReadingSample.Group) -> String {
        "\(group.type) · \(group.id)–\(group.questions.last?.id ?? group.id)"
    }

    private func open(_ sample: IELTSReadingSample) {
        enabledGroups = Set(sample.groups.filter { type == "全部" || $0.type == type }.map(\.id))
        practicing = false
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
                y += lineHeight + 5
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

/// Uses the writing prompt's selection actions inside a scrolling reading pane.
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
