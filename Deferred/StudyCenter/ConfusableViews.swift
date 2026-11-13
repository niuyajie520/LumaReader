import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 1.12.0 练习视图（主窗口 compact=false / 悬浮小窗 compact=true 共用）

/// 只处理「自己所在窗口」的按键，避免主窗口与小窗同时打开时互相抢键。
struct LumaWindowKeyMonitor: NSViewRepresentable {
    var handler: (NSEvent) -> Bool

    final class KeyView: NSView {
        var onWindowChange: ((Int) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window?.windowNumber ?? -1)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = KeyView(frame: .zero)
        let coordinator = context.coordinator
        coordinator.handler = handler
        view.onWindowChange = { number in coordinator.windowNumber = number }
        coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handler = handler
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        var handler: ((NSEvent) -> Bool)?
        var windowNumber: Int = -1
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.windowNumber == self.windowNumber else { return event }
                if self.handler?(event) == true { return nil }
                return event
            }
        }

        func teardown() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

struct LumaPracticeShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 3), y: 0))
    }
}

struct LumaPracticeView: View {
    @Environment(\.studyAppearance) private var ap
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lumaDynamicMotion) private var dynamicMotion

    @ObservedObject var engine: LumaPracticeEngine
    let compact: Bool
    let mode: LumaPracticeMode
    let autoplay: Bool
    let showMeaning: Bool
    let autoAdvance: Bool
    let onRestart: (Bool) -> Void
    let onToggleMeaning: () -> Void
    let onExit: (() -> Void)?
    var isPresented = true
    var canPlay: @MainActor () -> Bool = { true }

    @FocusState private var fieldFocused: Bool
    @State private var shake: CGFloat = 0
    @State private var advanceTask: Task<Void, Never>? = nil

    private var speaker: LumaPracticeSpeaker { compact ? .mini : .shared }
    private var playbackItemID: String? { isPresented && !engine.finished ? engine.current?.id : nil }
    private var animated: Bool { dynamicMotion && !reduceMotion }
    private var isManga: Bool { ap.visualThemeSystem == "manga" }
    private var softInk: Color { ap.ink.opacity(0.86) }
    private var quietInk: Color { ap.ink.opacity(0.48) }
    private var wrongTint: Color { Color(red: 0.86, green: 0.38, blue: 0.36) }

    var body: some View {
        ZStack {
            if engine.finished {
                summary
            } else if let item = engine.current {
                stage(item)
            }
            LumaWindowKeyMonitor { event in handleKey(event) }
                .frame(width: 0, height: 0)
        }
        .task(id: playbackItemID) {
            guard playbackItemID != nil, let item = engine.current else { return }
            if mode == .dictation { fieldFocused = true }
            guard autoplay else { return }
            do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
            guard !Task.isCancelled, canPlay() else { return }
            speaker.speak(item.word)
        }
        .onChange(of: engine.phase) { _, phase in
            guard phase == .correct, autoAdvance else { return }
            let id = engine.current?.id
            advanceTask?.cancel()
            advanceTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                guard engine.current?.id == id else { return }
                engine.advance()
            }
        }
        .onChange(of: engine.errorPulse) { _, _ in
            if animated {
                withAnimation(.easeInOut(duration: 0.38)) { shake += 1 }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            if isPresented, mode == .dictation, !engine.finished { fieldFocused = true }
        }
        .onChange(of: isPresented) { _, visible in
            if !visible {
                speaker.stop()
                advanceTask?.cancel()
            }
        }
        .onDisappear { advanceTask?.cancel(); speaker.stop() }
    }

    // MARK: 题目

    @ViewBuilder
    private func stage(_ item: LumaPracticeItem) -> some View {
        if compact {
            VStack(spacing: 6) {
                GeometryReader { viewport in
                    ScrollView {
                        VStack(spacing: 8) {
                            Spacer(minLength: 4)
                            question(item, compactWidth: max(1, viewport.size.width - 8))
                            Spacer(minLength: 4)
                        }
                        .padding(.horizontal, 4)
                        .frame(minHeight: viewport.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                footer(item)
            }
        } else {
            VStack(spacing: 22) {
                Spacer(minLength: 0)
                question(item)
                Spacer(minLength: 0)
                footer(item)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func question(_ item: LumaPracticeItem, compactWidth: CGFloat? = nil) -> some View {
        promptBlock(item)
        if mode == .choice {
            choiceList(item)
        } else {
            dictationField(item, compactWidth: compactWidth)
        }
        feedback(item)
    }

    private func promptBlock(_ item: LumaPracticeItem) -> some View {
        VStack(spacing: compact ? 6 : 12) {
            Button {
                speaker.speak(item.word)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: compact ? 20 : 30, weight: .medium))
                    .foregroundStyle(ap.accent)
                    .frame(width: compact ? 46 : 70, height: compact ? 46 : 70)
                    .background(Circle().fill(ap.accent.opacity(ap.isDark ? 0.18 : 0.12)))
                    .overlay(Circle().strokeBorder(ap.accent.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("重播  ⌘R")
            if showMeaning || engine.phase != .asking {
                Text(item.meaning.isEmpty ? " " : item.meaning)
                    .font(.system(size: compact ? 13.5 : 18))
                    .foregroundStyle(quietInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 520)
            }
            if mode == .choice, engine.phase != .asking, !item.phonetic.isEmpty {
                Text(item.phonetic).font(.system(size: 13)).foregroundStyle(quietInk)
            }
        }
    }

    private func hintPattern(_ item: LumaPracticeItem) -> String {
        item.word.enumerated().map { pair in
            pair.offset < engine.hintLetters ? String(pair.element) : "·"
        }.joined(separator: " ")
    }

    private func dictationField(_ item: LumaPracticeItem, compactWidth: CGFloat?) -> some View {
        let shape = RoundedRectangle(cornerRadius: isManga ? 6 : 16, style: .continuous)
        let borderColor: Color = engine.phase == .wrong ? wrongTint : (engine.phase == .correct ? ap.accent : ap.line)
        let borderWidth: CGFloat = engine.phase == .asking ? 1 : 2
        let hint = hintPattern(item)
        let fontSize = compactWidth.map { width in
            let ceiling = min(56, max(44, width * 0.12))
            let text = engine.input.isEmpty ? hint : engine.input
            let measured = DictationAnswerMetrics.width(text, size: ceiling)
            return max(20, floor(ceiling * min(1, (width - 40) / max(1, measured))))
        } ?? 46
        let fieldHeight = compactWidth.map { min(140, max(104, $0 * 0.27)) }
        return TextField("", text: $engine.input, prompt: Text(hint).foregroundStyle(quietInk.opacity(0.7)))
            .textFieldStyle(.plain)
            .font(.system(size: fontSize, weight: .semibold, design: isManga ? .serif : .rounded))
            .foregroundStyle(softInk)
            .multilineTextAlignment(.center)
            .autocorrectionDisabled()
            .focused($fieldFocused)
            .disabled(engine.phase == .correct)
            .onSubmit { engine.submitDictation() }
            .padding(.vertical, compact ? 10 : 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: compact ? .infinity : 640)
            .frame(height: fieldHeight)
            .background {
                if compact {
                    shape.fill(ap.surface).onTapGesture {
                        if engine.phase != .correct { fieldFocused = true }
                    }
                } else {
                    shape.fill(ap.surface)
                }
            }
            .overlay { shape.strokeBorder(borderColor, lineWidth: borderWidth).allowsHitTesting(false) }
            .modifier(LumaPracticeShake(amount: shake))
    }

    private func choiceList(_ item: LumaPracticeItem) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            ForEach(Array(engine.choiceOptions.enumerated()), id: \.element.id) { offset, option in
                choiceRow(item, option: option, letter: offset < 5 ? ["A", "B", "C", "D", "E"][offset] : "")
            }
        }
        .frame(maxWidth: compact ? .infinity : 560)
    }

    private func choiceRow(_ item: LumaPracticeItem, option: LumaPracticeSibling, letter: String) -> some View {
        let answered = engine.phase != .asking
        let isCorrect = option.id == item.id
        let isPicked = engine.picked == option.id
        let shape = RoundedRectangle(cornerRadius: isManga ? 6 : 14, style: .continuous)
        let tint: Color? = answered ? (isCorrect ? ap.accent : (isPicked ? wrongTint : nil)) : nil
        let borderColor: Color = tint ?? ap.line
        let rowOpacity: Double = answered && !isCorrect && !isPicked ? 0.5 : 1.0
        return Button {
            engine.choose(option.id)
        } label: {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint ?? quietInk)
                    .frame(width: 24, height: 24)
                    .background(Circle().strokeBorder((tint ?? ap.ink).opacity(0.4), lineWidth: 1))
                Text(option.word)
                    .font(.system(size: compact ? 17 : 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(softInk)
                Spacer(minLength: 6)
                if answered {
                    Text(option.meaning)
                        .font(.system(size: compact ? 11.5 : 13))
                        .foregroundStyle(quietInk)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 8 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(tint.map { $0.opacity(0.14) } ?? ap.surface))
            .overlay(shape.strokeBorder(borderColor, lineWidth: tint == nil ? 0.8 : 1.6))
            .contentShape(shape)
            .opacity(rowOpacity)
        }
        .buttonStyle(.plain)
        .disabled(answered)
    }

    @ViewBuilder
    private func feedback(_ item: LumaPracticeItem) -> some View {
        if engine.phase == .wrong {
            VStack(spacing: 8) {
                Text(item.word)
                    .font(.system(size: compact ? 20 : 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(ap.accent)
                if mode == .dictation {
                    Text("再输入一遍继续").font(.system(size: 12)).foregroundStyle(quietInk)
                }
                if item.siblings.count > 1 {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(item.siblings) { sibling in
                            HStack(spacing: 8) {
                                Text(sibling.word)
                                    .font(.system(size: compact ? 12.5 : 14, weight: sibling.id == item.id ? .bold : .regular))
                                    .foregroundStyle(sibling.id == item.id ? ap.accent : softInk)
                                Text(sibling.meaning)
                                    .font(.system(size: compact ? 11.5 : 13))
                                    .foregroundStyle(quietInk)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .transition(.opacity)
        } else if engine.phase == .correct {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: compact ? 22 : 30))
                .foregroundStyle(ap.accent)
                .transition(.opacity)
        } else {
            Color.clear.frame(height: compact ? 22 : 30)
        }
    }

    private func footer(_ item: LumaPracticeItem) -> some View {
        HStack(spacing: 8) {
            Text("\(engine.index + 1)/\(engine.total)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(quietInk)
            Text("✓ \(engine.rightCount)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(quietInk)
            Spacer(minLength: 4)
            if engine.phase == .asking {
                if mode == .dictation {
                    Button("提示") { engine.showHint() }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 26))
                        .help("显示下一个字母  ⌘/")
                }
                Button("看答案") { engine.reveal() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 26))
                    .help("⌘'")
            } else {
                Button(mode == .dictation && engine.phase == .wrong ? "跳过" : "下一个") { engine.advance() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: engine.phase == .wrong && mode == .choice,
                                                              horizontalPadding: 12, height: 26))
            }
            if compact, mode == .dictation, engine.phase != .correct {
                Button("提交") { engine.submitDictation() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 10, height: 26))
                    .help("提交答案 · 回车")
            }
        }
    }

    // MARK: 结果

    private var summary: some View {
        let total = max(engine.total, 1)
        let rate = Int((Double(engine.rightCount) / Double(total) * 100).rounded())
        return VStack(spacing: compact ? 10 : 18) {
            Spacer(minLength: 0)
            Text("\(rate)%")
                .font(.system(size: compact ? 44 : 64, weight: .semibold, design: isManga ? .serif : .rounded))
                .foregroundStyle(softInk)
            Text("一次答对 \(engine.rightCount) / \(engine.total)")
                .font(.system(size: compact ? 12.5 : 14))
                .foregroundStyle(quietInk)
            if !engine.missed.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(engine.missed) { item in
                            HStack(spacing: 10) {
                                Button { speaker.speak(item.word) } label: {
                                    Image(systemName: "speaker.wave.2")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(quietInk)
                                Text(item.word).font(.system(size: 14, weight: .semibold)).foregroundStyle(softInk)
                                Spacer(minLength: 8)
                                Text(item.meaning).font(.system(size: 12)).foregroundStyle(quietInk).lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ap.surface))
                        }
                    }
                }
                .frame(maxWidth: 480, maxHeight: compact ? 110 : 240)
            }
            HStack(spacing: 8) {
                if !engine.missed.isEmpty {
                    Button { onRestart(true) } label: { Label("复习选错的", systemImage: "arrow.triangle.2.circlepath") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 12, height: 30))
                }
                Button { onRestart(false) } label: { Label("再来一轮", systemImage: "arrow.right") }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: engine.missed.isEmpty, horizontalPadding: 12, height: 30))
                if let onExit {
                    Button("返回", action: onExit)
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 14 : 32)
    }

    // MARK: 快捷键（沿用听力听写的组合键，字母键留给输入框）

    private func speakCurrent(slow: Bool) {
        if let item = engine.current { speaker.speak(item.word, slow: slow) }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var bits: UInt8 = 0
        if flags.contains(.command) { bits |= DictationShortcutPolicy.command }
        if flags.contains(.option) { bits |= DictationShortcutPolicy.option }
        if flags.contains(.shift) { bits |= DictationShortcutPolicy.shift }
        if flags.contains(.control) { bits |= DictationShortcutPolicy.control }
        let chars = event.charactersIgnoringModifiers ?? ""

        if let action = DictationShortcutPolicy.action(keyCode: event.keyCode, characters: chars, modifiers: bits) {
            switch action {
            case .replay: speakCurrent(slow: false)
            case .slowReplay: speakCurrent(slow: true)
            case .toggleMeaning: onToggleMeaning()
            case .toggleHint: engine.showHint()
            case .revealAnswer: engine.reveal()
            case .togglePause, .previous, .help: return false
            }
            return true
        }
        guard bits == 0 else { return false }
        let key = chars.lowercased()

        if engine.finished {
            if event.keyCode == 36 || event.keyCode == 76 { onRestart(false); return true }
            if key == "w", !engine.missed.isEmpty { onRestart(true); return true }
            if event.keyCode == 53, let onExit { onExit(); return true }
            return false
        }
        if event.keyCode == 53, let onExit { onExit(); return true }
        guard mode == .choice else { return false }
        switch event.keyCode {
        case 36, 76, 124:
            if engine.phase != .asking { engine.advance() }
            return true
        case 49:
            speakCurrent(slow: false)
            return true
        default:
            break
        }
        let map: [String: Int] = ["1": 0, "2": 1, "3": 2, "4": 3, "5": 4, "a": 0, "b": 1, "c": 2, "d": 3, "e": 4]
        if let i = map[key], engine.choiceOptions.indices.contains(i) {
            engine.choose(engine.choiceOptions[i].id)
            return true
        }
        if key == "r" { speakCurrent(slow: false); return true }
        return false
    }
}

// MARK: - 易混词主页（添加 / 导入 / 编辑 / 分类 / 自动发现）

private enum LumaConfusableSheet: Identifiable {
    case importText
    case discover
    case editor(LumaConfusableGroup, isNew: Bool)

    var id: String {
        switch self {
        case .importText: return "import"
        case .discover: return "discover"
        case .editor(let group, _): return "editor-" + group.id
        }
    }
}

struct LumaConfusableLibraryView: View {
    @Environment(\.studyAppearance) private var ap
    @ObservedObject var library: LumaConfusableLibrary
    let onStart: (String) -> Void

    @State private var search = ""
    @State private var category: String? = nil
    @State private var sheet: LumaConfusableSheet? = nil
    @State private var groupToDelete: LumaConfusableGroup? = nil
    @State private var categoryRequestGroup: String? = nil
    @State private var categoryInput = ""
    @State private var toast: String? = nil

    private var isManga: Bool { ap.visualThemeSystem == "manga" }
    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 16)]

    private var visibleGroups: [LumaConfusableGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return library.groups.filter { group in
            if let category, group.category != category { return false }
            guard !query.isEmpty else { return true }
            return group.entries.contains { $0.word.localizedStandardContains(query) || $0.meaning.localizedStandardContains(query) }
                || group.title.localizedStandardContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            categoryBar
            if let error = library.lastError {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Spacer()
                    Button("关闭") { library.lastError = nil }.buttonStyle(.borderless)
                }
                .font(.system(size: 12))
            }
            ScrollView {
                if visibleGroups.isEmpty {
                    emptyState.frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(visibleGroups) { group in groupCard(group) }
                    }
                    .padding(.bottom, 32)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .padding(.horizontal, 42)
        .padding(.top, 26)
        .background(ap.background.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .studyGlassCapsule(cornerRadius: 18)
                    .padding(.bottom, 22)
                    .task { try? await Task.sleep(for: .seconds(2.6)); self.toast = nil }
            }
        }
        .sheet(item: $sheet) { current in
            switch current {
            case .importText:
                LumaConfusableImportSheet(library: library) { groups in
                    finishAdding(groups)
                }
                .environment(\.studyAppearance, ap)
            case .discover:
                LumaConfusableDiscoverSheet(library: library) { groups in
                    finishAdding(groups)
                }
                .environment(\.studyAppearance, ap)
            case .editor(let group, let isNew):
                LumaConfusableGroupEditor(group: group, isNew: isNew, categories: library.categories) { saved in
                    library.upsert(saved)
                }
                .environment(\.studyAppearance, ap)
            }
        }
        .confirmationDialog("删除这一组？", isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } }), titleVisibility: .visible) {
            Button("删除「\(groupToDelete?.displayTitle ?? "")」", role: .destructive) {
                if let g = groupToDelete, let error = library.delete(g.id) { library.lastError = error }
                groupToDelete = nil
            }
            Button("取消", role: .cancel) { groupToDelete = nil }
        } message: { Text("只删除易混词里的这一组，听力词库和背词词库不受影响。") }
        .alert("移到分类", isPresented: Binding(get: { categoryRequestGroup != nil }, set: { if !$0 { categoryRequestGroup = nil } })) {
            TextField("分类名称（留空 = 未分类）", text: $categoryInput)
            Button("取消", role: .cancel) { categoryRequestGroup = nil }
            Button("确定") {
                if let id = categoryRequestGroup, let error = library.setCategory(categoryInput, for: id) { library.lastError = error }
                categoryRequestGroup = nil
            }
        }
    }

    private func finishAdding(_ groups: [LumaConfusableGroup]) {
        if let error = library.add(groups) {
            library.lastError = error
        } else {
            toast = "已添加 \(groups.count) 组"
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("易混词")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(ap.ink)
                Text("\(library.groups.count) 组 · \(library.groups.reduce(0) { $0 + $1.entries.count }) 个词")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(ap.ink.opacity(0.55))
            }
            Spacer()
            StudySearchField("搜索单词或释义", text: $search, width: 190)
            Menu {
                Button { sheet = .editor(LumaConfusableGroup(category: category ?? "", entries: [LumaConfusableEntry(word: ""), LumaConfusableEntry(word: "")]), isNew: true) } label: {
                    Label("新建一组", systemImage: "plus.square")
                }
                Button { sheet = .importText } label: { Label("粘贴 / 导入文本…", systemImage: "square.and.arrow.down") }
                Button { sheet = .discover } label: { Label("从词库里自动发现…", systemImage: "sparkle.magnifyingglass") }
            } label: { Image(systemName: "plus") }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32)).fixedSize()
            .help("添加易混词")
            Button { openMini(scope: nil) } label: { Image(systemName: "pip") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 32))
                .help("打开悬浮小窗（置顶，看视频时也能练）  ⌥⌘6")
            Menu {
                Button { onStart("all") } label: { Label("全部易混词", systemImage: "square.stack") }
                Button { onStart("hard") } label: { Label("仅易错的", systemImage: "exclamationmark.triangle") }
                if let category {
                    Button { onStart("cat:" + category) } label: { Label("当前分类：\(category)", systemImage: "folder") }
                }
            } label: { Label("练习", systemImage: "play.fill") }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32)).fixedSize()
            .disabled(library.groups.isEmpty)
        }
    }

    private var categoryBar: some View {
        let names = library.categories
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("全部") { category = nil }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(selected: category == nil, horizontalPadding: 12, height: 28))
                ForEach(names, id: \.self) { name in
                    Button(name) { category = name }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: category == name, horizontalPadding: 12, height: 28))
                }
            }
        }
        .opacity(names.isEmpty ? 0 : 1)
        .frame(height: names.isEmpty ? 0 : 28)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(ap.ink.opacity(0.35))
            Text(library.groups.isEmpty ? "还没有易混词，比如 curse / course / coarse" : "没有找到匹配的词组")
                .font(.system(size: 15))
                .foregroundStyle(ap.ink.opacity(0.6))
            if library.groups.isEmpty {
                HStack(spacing: 10) {
                    Button { sheet = .editor(LumaConfusableGroup(entries: [LumaConfusableEntry(word: ""), LumaConfusableEntry(word: "")]), isNew: true) } label: {
                        Label("新建一组", systemImage: "plus")
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 32))
                    Button { sheet = .discover } label: { Label("自动发现", systemImage: "sparkle.magnifyingglass") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                    Button { sheet = .importText } label: { Label("粘贴导入", systemImage: "square.and.arrow.down") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 32))
                }
            }
        }
    }

    // MARK: 卡片

    private func groupCard(_ group: LumaConfusableGroup) -> some View {
        let shape = RoundedRectangle(cornerRadius: isManga ? 6 : 16, style: .continuous)
        let strokeColor: Color = isManga ? ap.ink.opacity(0.85) : ap.line
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(group.entries.map(\.word).joined(separator: "  ·  "))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(ap.ink)
                    .lineLimit(2)
                Spacer(minLength: 6)
                if !group.category.isEmpty {
                    Text(group.category)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ap.accent)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(ap.accent.opacity(0.14)))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(group.entries) { entry in
                    Text(entry.meaning.isEmpty ? entry.word : "\(entry.word)  \(entry.meaning)")
                        .font(.system(size: 12))
                        .foregroundStyle(ap.ink.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text(group.attempts == 0 ? "未练习" : "练 \(group.attempts) 次 · 错 \(group.misses) 次")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(group.misses > 0 ? Color(red: 0.86, green: 0.38, blue: 0.36) : ap.ink.opacity(0.45))
                Spacer()
            }
            HStack(spacing: 8) {
                Button { sheet = .editor(group, isNew: false) } label: { Label("编辑", systemImage: "square.and.pencil").frame(maxWidth: .infinity) }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 8, height: 28))
                Button { openMini(scope: group.id) } label: { Image(systemName: "pip") }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 28))
                    .help("在悬浮小窗里练这一组")
                Button { onStart(group.id) } label: { Label("练习", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 8, height: 28))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(shape.fill(isManga ? AnyShapeStyle(ap.paper) : AnyShapeStyle(ap.secondaryGradient)))
        .overlay(shape.strokeBorder(strokeColor, lineWidth: isManga ? ap.mangaLineWeight : 1))
        .contentShape(shape)
        .onTapGesture(count: 2) { onStart(group.id) }
        .contextMenu {
            Button("练习", systemImage: "play.fill") { onStart(group.id) }
            Button("小窗练习", systemImage: "pip") { openMini(scope: group.id) }
            Button("编辑…", systemImage: "square.and.pencil") { sheet = .editor(group, isNew: false) }
            Button("移到分类…", systemImage: "folder") {
                categoryInput = group.category
                categoryRequestGroup = group.id
            }
            Button("重置统计", systemImage: "arrow.counterclockwise") {
                if let error = library.resetStats(group.id) { library.lastError = error }
            }
            Divider()
            Button("删除…", systemImage: "trash", role: .destructive) { groupToDelete = group }
        }
    }

    private func openMini(scope: String?) {
        var info: [String: String] = ["source": "confusable"]
        if let scope { info["scope"] = scope }
        NotificationCenter.default.post(name: LumaMiniPracticeNotification.open, object: nil, userInfo: info)
    }
}

// MARK: 候选列表（导入预览 / 自动发现共用；每一组都由你勾选，不会悄悄跳过）

struct LumaConfusableCandidate: Identifiable, Equatable {
    let id = UUID()
    var group: LumaConfusableGroup
    var isDuplicate: Bool
    var selected: Bool
}

struct LumaConfusableCandidateList: View {
    @Environment(\.studyAppearance) private var ap
    @Binding var candidates: [LumaConfusableCandidate]

    var body: some View {
        List {
            ForEach($candidates) { $candidate in
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $candidate.selected).labelsHidden()
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(candidate.group.entries.map(\.word).joined(separator: "  ·  "))
                                .font(.system(size: 14, weight: .semibold))
                            if candidate.isDuplicate {
                                Text("已存在")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                            }
                        }
                        Text(candidate.group.entries.map { $0.meaning.isEmpty ? "—" : $0.meaning }.joined(separator: " ｜ "))
                            .font(.system(size: 11.5))
                            .foregroundStyle(ap.ink.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollContentBackground(.hidden)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ap.surface)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ap.line, lineWidth: 1)))
    }
}

struct LumaConfusableImportSheet: View {
    @Environment(\.studyAppearance) private var ap
    @Environment(\.dismiss) private var dismiss
    let library: LumaConfusableLibrary
    let onConfirm: ([LumaConfusableGroup]) -> Void

    @State private var text = ""
    @State private var category = ""
    @State private var candidates: [LumaConfusableCandidate] = []
    @State private var ignored: [String] = []
    @State private var previewing = false
    @State private var showImporter = false
    @State private var errorText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(previewing ? "确认要添加的词组" : "粘贴或导入易混词")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ap.ink)
            if previewing {
                Text("勾选的才会加入；已存在的默认不勾，需要重复添加时请自己勾上。")
                    .font(.system(size: 12)).foregroundStyle(ap.ink.opacity(0.55))
                LumaConfusableCandidateList(candidates: $candidates)
                if !ignored.isEmpty {
                    DisclosureGroup("没能识别的 \(ignored.count) 行（不会加入）") {
                        Text(ignored.joined(separator: "\n"))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(ap.ink.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .font(.system(size: 12))
                }
            } else {
                Text("一行一组，单词之间用逗号、| 或分号隔开；单词后面可以直接写中文释义，没写的会自动从词库 / 词典里补。")
                    .font(.system(size: 12)).foregroundStyle(ap.ink.opacity(0.55))
                TextEditor(text: $text)
                    .font(.system(size: 14, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ap.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ap.line, lineWidth: 1)))
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("curse 诅咒, course 课程, coarse 粗糙的\naffect | effect\nprincipal, principle")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(ap.ink.opacity(0.3))
                                .padding(14)
                                .allowsHitTesting(false)
                        }
                    }
                HStack {
                    Text("分类").font(.system(size: 12)).foregroundStyle(ap.ink.opacity(0.6))
                    TextField("可选，如：考试高频", text: $category).textFieldStyle(.roundedBorder).frame(width: 200)
                    Button { showImporter = true } label: { Label("选择文件…", systemImage: "doc") }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                }
            }
            HStack {
                if !errorText.isEmpty { Text(errorText).font(.system(size: 12)).foregroundStyle(.red) }
                Spacer()
                if previewing {
                    Button("返回修改") { previewing = false }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                    Button("添加 \(candidates.filter(\.selected).count) 组") {
                        onConfirm(candidates.filter(\.selected).map(\.group))
                        dismiss()
                    }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 34))
                    .disabled(candidates.allSatisfy { !$0.selected })
                } else {
                    Button("取消") { dismiss() }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                        .keyboardShortcut(.cancelAction)
                    Button("预览") { buildPreview() }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 34))
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 500)
        .background(ap.background)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText, .utf8PlainText, .commaSeparatedText, .tabSeparatedText]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                text = try String(contentsOf: url, encoding: .utf8)
            } catch {
                errorText = "读取文件失败：\(error.localizedDescription)"
            }
        }
    }

    private func buildPreview() {
        let parsed = LumaConfusableParser.groups(from: text, category: category.trimmingCharacters(in: .whitespacesAndNewlines))
        let existing = Set(library.groups.map(\.wordKey))
        var seen = Set<Set<String>>()
        candidates = parsed.groups.map { group in
            var filled = group
            filled.entries = LumaWordLookup.fill(group.entries)
            let duplicate = existing.contains(filled.wordKey) || !seen.insert(filled.wordKey).inserted
            return LumaConfusableCandidate(group: filled, isDuplicate: duplicate, selected: !duplicate)
        }
        ignored = parsed.ignored
        errorText = candidates.isEmpty ? "没有识别到至少含两个单词的行" : ""
        if !candidates.isEmpty { previewing = true }
    }
}

struct LumaConfusableDiscoverSheet: View {
    @Environment(\.studyAppearance) private var ap
    @Environment(\.dismiss) private var dismiss
    let library: LumaConfusableLibrary
    let onConfirm: ([LumaConfusableGroup]) -> Void

    @State private var candidates: [LumaConfusableCandidate] = []
    @State private var loading = false
    @State private var searched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("从词库里自动发现易混词").font(.system(size: 22, weight: .medium)).foregroundStyle(ap.ink)
            Text("找拼写只差一个字母、相邻字母颠倒或音标相同的单词。只是候选，勾选后才会加入。")
                .font(.system(size: 12)).foregroundStyle(ap.ink.opacity(0.55))
            HStack(spacing: 8) {
                Spacer()
                Button { search() } label: { Label(searched ? "重新查找" : "开始查找", systemImage: "sparkle.magnifyingglass") }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 14, height: 30))
                    .disabled(loading)
            }
            if candidates.isEmpty {
                Text(searched ? "没有找到新的候选。" : "点击「开始查找」扫描阅读词库。")
                    .font(.system(size: 13)).foregroundStyle(ap.ink.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("\(candidates.count) 组候选").font(.system(size: 12)).foregroundStyle(ap.ink.opacity(0.55))
                    Spacer()
                    Button("全选") { for i in candidates.indices { candidates[i].selected = true } }.buttonStyle(.borderless)
                    Button("全不选") { for i in candidates.indices { candidates[i].selected = false } }.buttonStyle(.borderless)
                }
                .font(.system(size: 12))
                LumaConfusableCandidateList(candidates: $candidates)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                    .keyboardShortcut(.cancelAction)
                Button("添加 \(candidates.filter(\.selected).count) 组") {
                    onConfirm(candidates.filter(\.selected).map(\.group))
                    dismiss()
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 18, height: 34))
                .disabled(candidates.allSatisfy { !$0.selected })
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 520)
        .background(ap.background)
    }

    private func search() {
        loading = true
        let words = LumaChoiceLibrary.shared.allReadingWords
        let found = LumaConfusableSuggester.suggest(from: words, excluding: library.groups)
        candidates = found.map { LumaConfusableCandidate(group: $0, isDuplicate: false, selected: false) }
        searched = true
        loading = false
    }
}

// MARK: 词组编辑

struct LumaConfusableGroupEditor: View {
    @Environment(\.studyAppearance) private var ap
    @Environment(\.dismiss) private var dismiss
    let isNew: Bool
    let categories: [String]
    let onSave: (LumaConfusableGroup) -> String?

    @State private var group: LumaConfusableGroup
    @State private var errorText = ""

    init(group: LumaConfusableGroup, isNew: Bool, categories: [String], onSave: @escaping (LumaConfusableGroup) -> String?) {
        _group = State(initialValue: group)
        self.isNew = isNew
        self.categories = categories
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "新建易混词组" : "编辑易混词组")
                .font(.system(size: 22, weight: .medium)).foregroundStyle(ap.ink)
            HStack(spacing: 12) {
                TextField("组名（可留空，默认用单词拼接）", text: $group.title).textFieldStyle(.roundedBorder)
                HStack(spacing: 6) {
                    TextField("分类", text: $group.category).textFieldStyle(.roundedBorder).frame(width: 130)
                    if !categories.isEmpty {
                        Menu {
                            ForEach(categories, id: \.self) { name in Button(name) { group.category = name } }
                        } label: { Image(systemName: "folder") }
                        .menuStyle(.button).menuIndicator(.hidden).buttonStyle(.borderless).fixedSize()
                    }
                }
            }
            HStack(spacing: 10) {
                Text("英文").frame(width: 150, alignment: .leading)
                Text("音标").frame(width: 110, alignment: .leading)
                Text("中文释义").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 11.5)).foregroundStyle(ap.ink.opacity(0.5)).padding(.horizontal, 6)
            List {
                ForEach($group.entries) { $entry in
                    HStack(spacing: 10) {
                        TextField("单词", text: $entry.word).autocorrectionDisabled().textFieldStyle(.roundedBorder).frame(width: 150)
                        TextField("音标", text: $entry.phonetic).textFieldStyle(.roundedBorder).frame(width: 110)
                        TextField("中文释义", text: $entry.meaning).textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            group.entries.removeAll { $0.id == entry.id }
                        } label: { Image(systemName: "trash").font(.system(size: 12)) }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ap.surface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ap.line, lineWidth: 1)))
            HStack(spacing: 10) {
                Button { group.entries.append(LumaConfusableEntry(word: "")) } label: { Label("加一个词", systemImage: "plus") }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                Button { group.entries = LumaWordLookup.fill(group.entries) } label: { Label("补全释义和音标", systemImage: "text.badge.plus") }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 30))
                    .help("只补空着的；已写的不会被改")
                Spacer()
                if !errorText.isEmpty { Text(errorText).font(.system(size: 12)).foregroundStyle(.red) }
                Button("取消") { dismiss() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 14, height: 34))
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(StudyGlassCapsuleButtonStyle(prominent: true, horizontalPadding: 20, height: 34))
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 480)
        .background(ap.background)
    }

    private func save() {
        var cleaned: [LumaConfusableEntry] = []
        var seen = Set<String>()
        for entry in group.entries {
            let word = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
            if word.isEmpty && entry.meaning.isEmpty { continue }
            guard VocabularyImport.isValidEnglishTerm(word) else {
                errorText = "「\(word.isEmpty ? entry.meaning : word)」不是有效的英文词"
                return
            }
            guard seen.insert(word.lowercased()).inserted else {
                errorText = "「\(word)」重复了"
                return
            }
            var copy = entry
            copy.word = word
            copy.meaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.phonetic = entry.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = copy.readingWordID,
               let source = LumaChoiceLibrary.shared.readingWord(id: id),
               source.word.caseInsensitiveCompare(copy.word) != .orderedSame || source.definitionZH != copy.meaning {
                copy.readingWordID = nil
            }
            cleaned.append(copy)
        }
        guard cleaned.count >= 2 else {
            errorText = "一组至少要有两个词"
            return
        }
        var saved = group
        saved.entries = cleaned
        saved.title = group.title.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.category = group.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = onSave(saved) {
            errorText = issue
        } else {
            dismiss()
        }
    }
}

// MARK: - 易混词练习页（主窗口，全屏专注）

struct LumaConfusablePracticePage: View {
    @Environment(\.studyAppearance) private var ap
    @ObservedObject private var library = LumaConfusableLibrary.shared
    let scope: String
    let onExit: () -> Void

    @AppStorage("luma.practice.mode") private var modeRaw = LumaPracticeMode.dictation.rawValue
    @AppStorage("luma.practice.order") private var orderRaw = LumaPracticeOrder.groupShuffle.rawValue
    @AppStorage("luma.practice.autoplay") private var autoplay = true
    @AppStorage("luma.practice.autoAdvance") private var autoAdvance = true
    @AppStorage("luma.practice.showMeaning.confusable") private var showMeaning = true
    @StateObject private var engine = LumaPracticeEngine()

    private var mode: LumaPracticeMode { LumaPracticeMode(rawValue: modeRaw) ?? .dictation }
    private var order: LumaPracticeOrder { LumaPracticeOrder(rawValue: orderRaw) ?? .groupShuffle }

    var body: some View {
        ZStack {
            ap.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.leading, 96)
                    .padding(.trailing, 28)
                    .padding(.top, 14)
                if engine.total == 0 {
                    StudyEmptyState("这个范围里还没有可练的易混词", symbol: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LumaPracticeView(engine: engine, compact: false, mode: mode, autoplay: autoplay,
                                     showMeaning: showMeaning, autoAdvance: autoAdvance,
                                     onRestart: { missedOnly in restart(missedOnly: missedOnly) },
                                     onToggleMeaning: { showMeaning.toggle() },
                                     onExit: onExit)
                }
            }
        }
        .onAppear { restart(missedOnly: false) }
        .onChange(of: orderRaw) { _, _ in restart(missedOnly: false) }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { LumaPracticeSpeaker.shared.stop(); onExit() } label: { Image(systemName: "house") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 11, height: 32))
                .help("返回易混词  Esc")
            Text(LumaPracticeSources.scopeTitle(scope, library: library))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ap.ink.opacity(0.6))
            Spacer()
            HStack(spacing: 6) {
                ForEach(LumaPracticeMode.allCases) { item in
                    Button(item.title) { modeRaw = item.rawValue }
                        .buttonStyle(StudyGlassCapsuleButtonStyle(selected: mode == item, horizontalPadding: 12, height: 30))
                }
            }
            Menu {
                ForEach(LumaPracticeOrder.allCases) { item in
                    Button { orderRaw = item.rawValue } label: {
                        Label(item.title, systemImage: order == item ? "checkmark" : item.symbol)
                    }
                }
            } label: { Image(systemName: order.symbol) }
            .menuStyle(.button).menuIndicator(.hidden)
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 11, height: 32)).fixedSize()
            .help("出题顺序：\(order.title)")
            Button { autoplay.toggle() } label: { Image(systemName: autoplay ? "play.square" : "play.slash") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: autoplay, horizontalPadding: 11, height: 32))
                .help(autoplay ? "自动播放：开" : "自动播放：关")
            Button { showMeaning.toggle() } label: { Image(systemName: showMeaning ? "text.bubble.fill" : "text.bubble") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: showMeaning, horizontalPadding: 11, height: 32))
                .help("显示 / 隐藏中文释义  ⌥⌘M")
            Button {
                NotificationCenter.default.post(name: LumaMiniPracticeNotification.open, object: nil,
                                                userInfo: ["source": "confusable", "scope": scope])
            } label: { Image(systemName: "pip") }
            .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 11, height: 32))
            .help("在悬浮小窗里继续")
        }
    }

    private func restart(missedOnly: Bool) {
        let source: [LumaPracticeItem] = missedOnly
            ? engine.missed
            : LumaPracticeSources.confusableItems(scope: scope, library: library)
        engine.onResolved = { item, correct, typed, seconds in
            LumaPracticeSources.resolve(item: item, correct: correct, typed: typed, seconds: seconds)
        }
        engine.start(source, order: order)
    }
}
