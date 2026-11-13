import SwiftUI
import AppKit

// MARK: - 1.12.0 悬浮小窗练习（类似视频的画中画：置顶、半透明、可拖动、可在全屏视频上方显示）
//
// 窗口本身（NSPanel）由 App 目标里的 LumaMiniPanelController 创建；这里是窗口里的内容。
// 来源有两个：易混词（听写 / 听音选词）和听力词库（听写）。

/// 把窗口层级、透明度、是否在所有桌面显示同步到设置里；对任何 NSWindow / NSPanel 都有效。
struct LumaFloatingWindowConfigurator: NSViewRepresentable {
    var pinned: Bool
    var opacity: Double

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        Task { @MainActor [weak view] in apply(view?.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor [weak nsView] in apply(nsView?.window) }
    }

    @MainActor
    private func apply(_ window: NSWindow?) {
        guard let window else { return }
        window.level = pinned ? .floating : .normal
        window.collectionBehavior = pinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.alphaValue = CGFloat(min(max(opacity, 0.35), 1.0))
    }
}

public struct LumaMiniPracticeRoot: View {
    @Environment(\.studyAppearance) private var ap

    @AppStorage("luma.mini.source") private var source = "confusable"
    @AppStorage("luma.mini.pinned") private var pinned = true
    @AppStorage("luma.mini.opacity") private var opacity = 0.94
    @AppStorage("luma.mini.confusableScope") private var confusableScope = "all"
    @AppStorage("luma.mini.listeningDeck") private var listeningDeck = ""
    @AppStorage("luma.mini.roundSize") private var roundSize = 20
    @AppStorage("luma.mini.recordToWrongBook") private var recordToWrongBook = true
    @AppStorage(LumaMiniVoice.preferenceKey) private var voiceRaw = LumaMiniVoice.followStudy.rawValue

    @AppStorage("luma.practice.mode") private var modeRaw = LumaPracticeMode.dictation.rawValue
    @AppStorage("luma.practice.order") private var orderRaw = LumaPracticeOrder.groupShuffle.rawValue
    @AppStorage("luma.practice.autoplay") private var autoplay = true
    @AppStorage("luma.practice.autoAdvance") private var autoAdvance = true
    @AppStorage("luma.practice.showMeaning.confusable") private var showMeaningConfusable = true
    @AppStorage("luma.practice.showMeaning.listening") private var showMeaningListening = false

    @StateObject private var engine = LumaPracticeEngine()
    @ObservedObject private var library = LumaConfusableLibrary.shared
    @State private var showSettings = false

    private let isPresented: Bool
    private let canPlay: @MainActor () -> Bool

    public init(isPresented: Bool = true, canPlay: @escaping @MainActor () -> Bool = { true }) {
        self.isPresented = isPresented
        self.canPlay = canPlay
    }

    @MainActor public static func stopPlayback() {
        LumaPracticeSpeaker.mini.stop()
    }

    private var isListening: Bool { source == "listening" }
    private var order: LumaPracticeOrder { LumaPracticeOrder(rawValue: orderRaw) ?? .groupShuffle }
    /// 听力单词没有「同组词」，只支持听写。
    private var effectiveMode: LumaPracticeMode {
        isListening ? .dictation : (LumaPracticeMode(rawValue: modeRaw) ?? .dictation)
    }
    private var showMeaning: Bool { isListening ? showMeaningListening : showMeaningConfusable }
    private var configKey: String {
        "\(source)|\(confusableScope)|\(listeningDeck)|\(orderRaw)|\(roundSize)"
    }
    private var quiet: Color { ap.ink.opacity(0.5) }

    public var body: some View {
        ZStack {
            ap.paper.ignoresSafeArea()
            VStack(spacing: 8) {
                topBar
                scopeMenu
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            LumaFloatingWindowConfigurator(pinned: pinned, opacity: opacity)
                .frame(width: 0, height: 0)
        }
        .onAppear { restart(missedOnly: false) }
        .onChange(of: configKey) { _, _ in restart(missedOnly: false) }
        .onChange(of: voiceRaw) { _, _ in Self.stopPlayback() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumaReader.AppDidResignActive"))) { note in
            if note.userInfo?["sleep"] as? Bool == true { Self.stopPlayback() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if engine.total == 0 {
            emptyState
        } else {
            LumaPracticeView(
                engine: engine, compact: true, mode: effectiveMode, autoplay: autoplay,
                showMeaning: showMeaning, autoAdvance: autoAdvance,
                onRestart: { missedOnly in restart(missedOnly: missedOnly) },
                onToggleMeaning: { toggleMeaning() },
                onExit: nil, isPresented: isPresented, canPlay: canPlay)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: isListening ? "headphones" : "arrow.left.arrow.right")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(quiet)
            Text(isListening ? "这个听力词库里没有可练的单词" : "还没有易混词")
                .font(.system(size: 13))
                .foregroundStyle(quiet)
            if !isListening {
                Text("在主窗口「学习 → 易混词」里添加")
                    .font(.system(size: 11.5))
                    .foregroundStyle(quiet.opacity(0.8))
            }
            Button("打开主窗口") { bringMainWindowForward() }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 12, height: 28))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 顶栏

    private var topBar: some View {
        HStack(spacing: 6) {
            Button("易混词") { source = "confusable" }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: !isListening, horizontalPadding: 10, height: 26))
            Button("听力") { source = "listening" }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: isListening, horizontalPadding: 10, height: 26))
            Spacer(minLength: 8)
            Button { orderRaw = order.next.rawValue } label: { Image(systemName: order.symbol) }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 9, height: 26))
                .help("出题顺序：\(order.title)（点击切换）")
            Button { pinned.toggle() } label: { Image(systemName: pinned ? "pin.fill" : "pin.slash") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(selected: pinned, horizontalPadding: 9, height: 26))
                .help(pinned ? "已置顶：始终浮在其它窗口上方" : "未置顶")
            Button { showSettings.toggle() } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 9, height: 26))
                .popover(isPresented: $showSettings, arrowEdge: .bottom) { settingsPopover }
        }
    }

    private var scopeTitle: String {
        isListening
            ? LumaPracticeSources.listeningTitle(listeningDeck.isEmpty ? (LumaPracticeSources.listeningDecks().first?.id ?? "") : listeningDeck)
            : LumaPracticeSources.scopeTitle(confusableScope, library: library)
    }

    private var scopeMenu: some View {
        let title = scopeTitle
        return Menu {
            if isListening {
                ForEach(LumaPracticeSources.listeningDecks()) { deck in
                    Button { listeningDeck = deck.id } label: {
                        Label(deck.title, systemImage: deck.id == listeningDeck ? "checkmark" : "book.closed")
                    }
                }
            } else {
                Button { confusableScope = "all" } label: { Label("全部易混词", systemImage: confusableScope == "all" ? "checkmark" : "square.stack") }
                Button { confusableScope = "hard" } label: { Label("仅易错的", systemImage: confusableScope == "hard" ? "checkmark" : "exclamationmark.triangle") }
                if !library.categories.isEmpty {
                    Divider()
                    ForEach(library.categories, id: \.self) { name in
                        Button { confusableScope = "cat:" + name } label: {
                            Label(name, systemImage: confusableScope == "cat:" + name ? "checkmark" : "folder")
                        }
                    }
                }
                Divider()
                ForEach(library.groups) { group in
                    Button { confusableScope = group.id } label: {
                        Label(group.displayTitle, systemImage: confusableScope == group.id ? "checkmark" : "arrow.left.arrow.right")
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Label(title, systemImage: isListening ? "books.vertical" : "square.stack")
                    .lineLimit(1)
                Spacer(minLength: 6)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ap.ink)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 26)
            .studyGlassCapsule(cornerRadius: 13)
            .contentShape(Rectangle())
        }
        .menuStyle(.button).menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help(title)
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isListening {
                Picker("方式", selection: $modeRaw) {
                    ForEach(LumaPracticeMode.allCases) { item in Text(item.title).tag(item.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Picker("发音来源", selection: $voiceRaw) {
                ForEach(LumaMiniVoice.allCases, id: \.rawValue) { voice in
                    Text(voice.title).tag(voice.rawValue)
                }
            }
            LumaMiniVoiceNotice()
            Toggle("自动播放发音", isOn: $autoplay)
            Toggle("显示中文释义", isOn: isListening ? $showMeaningListening : $showMeaningConfusable)
            Toggle("答对自动下一题", isOn: $autoAdvance)
            if isListening {
                Picker("每轮词数", selection: $roundSize) {
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                    Text("全部").tag(0)
                }
                Toggle("答题记入听力错词本", isOn: $recordToWrongBook)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("透明度 \(Int(opacity * 100))%").font(.system(size: 12)).foregroundStyle(quiet)
                Slider(value: $opacity, in: 0.4...1.0)
            }
            Button("打开主窗口") { bringMainWindowForward() }
                .buttonStyle(.borderless)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(16)
        .frame(width: 250)
    }

    // MARK: 动作

    private func toggleMeaning() {
        if isListening { showMeaningListening.toggle() } else { showMeaningConfusable.toggle() }
    }

    private func bringMainWindowForward() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func restart(missedOnly: Bool) {
        let items: [LumaPracticeItem]
        if missedOnly {
            items = engine.missed
        } else if isListening {
            let decks = LumaPracticeSources.listeningDecks()
            if !decks.contains(where: { $0.id == listeningDeck }), let first = decks.first { listeningDeck = first.id }
            items = LumaPracticeSources.listeningItems(deckID: listeningDeck, order: order, limit: roundSize)
        } else {
            items = LumaPracticeSources.confusableItems(scope: confusableScope, library: library)
        }
        engine.onResolved = { item, correct, typed, seconds in
            LumaPracticeSources.resolve(item: item, correct: correct, typed: typed, seconds: seconds)
        }
        engine.start(items, order: order)
    }
}

private struct LumaMiniVoiceNotice: View {
    @ObservedObject private var speaker = LumaPracticeSpeaker.mini

    var body: some View {
        if speaker.fellBackToApple {
            Text("Kitten 未能播放，这次使用了 Apple 语音。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
