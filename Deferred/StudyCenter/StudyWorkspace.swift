import AppKit
import Foundation

public struct StudyWorkspaceState: Codable, Equatable, Sendable {
    public var listeningMode: String?
    public var activePracticeListeningMode: String?
    public var selectedDeckID: String?
    public var writingMode: String?
    public var activePracticeWritingMode: String?
    public var writingDraftID: UUID?
    public var dictationInput: String = ""
    public var inputWordID: String?
    public var showMeaning: Bool = false
    public var revealedWordID: String?
    public var deckInputs: [String: String]? = nil
    public var deckInputWordIDs: [String: String]? = nil
    public var deckShowMeaning: [String: Bool]? = nil
    public var deckRevealedWordIDs: [String: String]? = nil
    /// 每个单词自己的一份听写记录（模式|日期|词ID → 已输入内容 / 释义 / 揭示状态），
    /// 换到别的词再回来不会互相覆盖。
    public var wordInputs: [String: String]? = nil
    public var wordShowMeaning: [String: Bool]? = nil
    public var wordRevealedWordIDs: [String: String]? = nil
    /// 「本轮」听写的起点。存在工作区里：临时退出应用不会重置，
    /// 只有真正从头开始一轮新的听写才会刷新。
    public var dictationRoundStartedAt: Date? = nil
    public init() {}

    /// Clear only listening/dictation drafts; preserve writing navigation and draft identity.
    public mutating func clearDictationDrafts() {
        activePracticeListeningMode = nil
        dictationInput = ""
        inputWordID = nil
        showMeaning = false
        revealedWordID = nil
        deckInputs = nil
        deckInputWordIDs = nil
        deckShowMeaning = nil
        deckRevealedWordIDs = nil
        wordInputs = nil
        wordShowMeaning = nil
        wordRevealedWordIDs = nil
        dictationRoundStartedAt = nil
    }

    public mutating func replaceDictationDrafts(with other: StudyWorkspaceState?) {
        clearDictationDrafts()
        guard let other else { return }
        listeningMode = other.listeningMode
        selectedDeckID = other.selectedDeckID
        activePracticeListeningMode = other.activePracticeListeningMode
        dictationInput = other.dictationInput
        inputWordID = other.inputWordID
        showMeaning = other.showMeaning
        revealedWordID = other.revealedWordID
        deckInputs = other.deckInputs
        deckInputWordIDs = other.deckInputWordIDs
        deckShowMeaning = other.deckShowMeaning
        deckRevealedWordIDs = other.deckRevealedWordIDs
        wordInputs = other.wordInputs
        wordShowMeaning = other.wordShowMeaning
        wordRevealedWordIDs = other.wordRevealedWordIDs
        dictationRoundStartedAt = other.dictationRoundStartedAt
    }

    private enum CodingKeys: String, CodingKey { case listeningMode, activePracticeListeningMode, selectedDeckID, writingMode, activePracticeWritingMode, writingDraftID, dictationInput, inputWordID, showMeaning, revealedWordID, deckInputs, deckInputWordIDs, deckShowMeaning, deckRevealedWordIDs, wordInputs, wordShowMeaning, wordRevealedWordIDs, dictationRoundStartedAt }
    public init(from decoder:Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy:CodingKeys.self)
        listeningMode = try c.decodeIfPresent(String.self, forKey:.listeningMode)
        activePracticeListeningMode = try c.decodeIfPresent(String.self, forKey:.activePracticeListeningMode)
        selectedDeckID = try c.decodeIfPresent(String.self, forKey:.selectedDeckID)
        writingMode = try c.decodeIfPresent(String.self, forKey:.writingMode)
        activePracticeWritingMode = try c.decodeIfPresent(String.self, forKey:.activePracticeWritingMode)
        writingDraftID = try c.decodeIfPresent(UUID.self, forKey:.writingDraftID)
        dictationInput = try c.decodeIfPresent(String.self, forKey:.dictationInput) ?? ""
        inputWordID = try c.decodeIfPresent(String.self, forKey:.inputWordID)
        showMeaning = try c.decodeIfPresent(Bool.self, forKey:.showMeaning) ?? false
        revealedWordID = try c.decodeIfPresent(String.self, forKey:.revealedWordID)
        deckInputs = try c.decodeIfPresent([String:String].self, forKey:.deckInputs)
        deckInputWordIDs = try c.decodeIfPresent([String:String].self, forKey:.deckInputWordIDs)
        deckShowMeaning = try c.decodeIfPresent([String:Bool].self, forKey:.deckShowMeaning)
        deckRevealedWordIDs = try c.decodeIfPresent([String:String].self, forKey:.deckRevealedWordIDs)
        wordInputs = try c.decodeIfPresent([String:String].self, forKey:.wordInputs)
        wordShowMeaning = try c.decodeIfPresent([String:Bool].self, forKey:.wordShowMeaning)
        wordRevealedWordIDs = try c.decodeIfPresent([String:String].self, forKey:.wordRevealedWordIDs)
        dictationRoundStartedAt = try c.decodeIfPresent(Date.self, forKey:.dictationRoundStartedAt)
    }

}

/// Lifetime belongs to the application window, not a particular study page.
/// Preserves independent state across Reading, Listening/Dictation, and Writing modules,
/// and keeps formal exam countdowns running continuously in real time across view switches.
@MainActor public final class LumaStudySession {
    /// 主窗口学习中心与悬浮小窗共用同一个会话，避免两份数据互相覆盖。
    public static let shared = LumaStudySession()
    let model: LumaStudyCenterHostView.HostStateModel
    public init(storageDirectory: URL? = nil) {
        model = LumaStudyCenterHostView.HostStateModel(storageDirectory: storageDirectory)
    }
    public func suspend() {
        // Stop speech synthesis when leaving Study Center, while keeping the continuous exam clock alive
        model.speech.stop()
        model.save()
        model.releaseDerivedVocabularyCaches()
    }
    public func releaseTransientCaches() { model.releaseDerivedVocabularyCaches() }
    public var hasActiveListeningProgress: Bool {
        !model.dictationMachine.isSessionFinished &&
        (!model.dictationMachine.completedWordIDs.isEmpty ||
         !model.dictationMachine.attemptLogs.isEmpty ||
         !model.dictationInput.isEmpty ||
         model.dictationMachine.requiresCorrection)
    }
    public var hasActiveWritingProgress: Bool {
        let draft = model.currentDraft
        let isSubmitted = model.storeSnapshot.writingSubmissions.contains { $0.draftSessionID == draft.id }
        guard !isSubmitted else { return false }
        return !draft.part1EssayText.isEmpty ||
               !draft.part2EssayText.isEmpty ||
               draft.elapsedSeconds > 0 ||
               model.storeSnapshot.activeWritingDrafts.values.contains(where: { $0.id == draft.id })
    }
    /// - Parameter directResume: 仅「菜单栏 → 继续写作」传 true，直接回到未完成的写作；
    ///   侧栏点「写作」不传，始终先进入题库主页（Task 1 / Task 2 之一），由用户自己选题，
    ///   未完成的草稿通过顶栏「继续写作」按钮进入。
    public func destination(for root: String, directResume: Bool = false) -> String {
        let state = model.storeSnapshot.workspace
        if root == "学习_听力" {
            // Listening entry always opens the deck chooser; saved sessions remain intact.
            return root
        }
        if root == "学习_写作_Task1题库" && !directResume {
            // 记住上次停留的是 Task 1 还是 Task 2 题库；其余状态（正在写、评分反馈、历史作文）一律回到题库主页。
            return state?.writingMode == "学习_写作_Task2题库" ? "学习_写作_Task2题库" : root
        }
        if root == "学习_写作_Task1题库" {
            let saved = state?.writingMode ?? root
            if saved.contains("模拟机考") {
                if state?.writingDraftID != model.currentDraft.id { return root }
                return saved
            }
            if let activeWriting = state?.activePracticeWritingMode,
               activeWriting.contains("模拟机考"),
               state?.writingDraftID == model.currentDraft.id,
               hasActiveWritingProgress {
                return activeWriting
            }
            return saved
        }
        return root
    }
}

// BEGIN LISTENING DAILY GOAL COMPONENT
import SwiftUI
import Foundation
import AppKit

@MainActor final class StudyDailyTimer: ObservableObject {
    enum Scope: String {
        case listening, reading
    }

    private let scope: Scope
    private var secondsKeyPrefix: String { "luma.\(scope.rawValue).seconds." }

    @Published var target: Int = 300
    @Published private(set) var seconds: Int = 0
    @Published private(set) var running = false
    private let defaults = UserDefaults.standard
    private var day = ""
    private var startedAt: Date?
    private var ticker: Task<Void, Never>?
    /// 30 秒无操作自动停止计时（冻结累计，不打断音频与练习判定）
    static let idleLimit: TimeInterval = 30
    @Published private(set) var idleFrozen = false
    private var frozenSeconds = 0
    private var lastActivity = Date()
    private var activityMonitor: Any?
    nonisolated(unsafe) private var resetObserver: NSObjectProtocol?

    init(scope: Scope = .listening) {
        self.scope = scope
        let saved = scope == .listening ? defaults.integer(forKey: "luma.listening.dailyTarget") : 0
        target = saved > 0 ? saved : 300
        restoreToday()
        if scope == .listening {
            resetObserver = NotificationCenter.default.addObserver(forName: Notification.Name("LumaReader.DictationTimerReset"), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.startedAt = self.running ? Date() : nil
                    self.frozenSeconds = 0
                    self.restoreToday()
                }
            }
        }
    }
    deinit {
        if let resetObserver { NotificationCenter.default.removeObserver(resetObserver) }
    }
    private static func key(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    private func restoreToday() {
        day = Self.key(Date())
        seconds = defaults.integer(forKey: secondsKeyPrefix + day)
    }
    func setTarget(_ value: Int) {
        target = min(10000, max(1, value))
        defaults.set(target, forKey: "luma.listening.dailyTarget")
    }
    private func checkpoint() {
        let now = Date()
        if var cursor = startedAt {
            while cursor < now {
                let nextDay = Calendar.current.startOfDay(for: cursor).addingTimeInterval(36 * 3600)
                let boundary = Calendar.current.startOfDay(for: nextDay)
                let end = min(boundary, now)
                let dateKey = Self.key(cursor)
                let storeKey = secondsKeyPrefix + dateKey
                defaults.set(defaults.integer(forKey: storeKey) + max(0, Int(end.timeIntervalSince(cursor))), forKey: storeKey)
                cursor = end
            }
            startedAt = now
        }
        restoreToday()
    }
    func start() {
        guard !running, NSApplication.shared.isActive else { return }
        restoreToday(); startedAt = Date(); running = true
        idleFrozen = false; lastActivity = Date()
        installActivityMonitorIfNeeded()
        // dictation_focus_v7
        if scope == .listening { notifyDictationFocus(true) }
        ticker = Task { @MainActor [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self else { return }
                // 冻结期间停止累计：把游标推到当前时刻，今日总时长保持不动
                if self.idleFrozen {
                    self.startedAt = Date()
                    self.seconds = self.frozenSeconds
                    continue
                }
                if Date().timeIntervalSince(self.lastActivity) >= Self.idleLimit {
                    self.freezeIdle()
                    continue
                }
                ticks += 1
                if ticks % 15 == 0 { self.checkpoint() }
                else {
                    let today = Self.key(Date())
                    if today != self.day { self.checkpoint() }
                    else { self.seconds = self.defaults.integer(forKey: secondsKeyPrefix + today) + Int(Date().timeIntervalSince(self.startedAt ?? Date())) }
                }
            }
        }
    }
    func pause() {
        checkpoint(); running = false; startedAt = nil
        idleFrozen = false; removeActivityMonitor()
        if scope == .listening { notifyDictationFocus(false) }
        ticker?.cancel(); ticker = nil
    }
    // MARK: - 无操作自动停止计时

    /// 任何键盘 / 鼠标操作都算一次活动；冻结状态下动一下就自动恢复累计。
    func noteActivity() {
        lastActivity = Date()
        guard idleFrozen else { return }
        idleFrozen = false; startedAt = Date()
        NotificationCenter.default.post(name: Self.idleNotification, object: nil, userInfo: ["enabled": false])
    }

    private static let idleNotification = Notification.Name("LumaReader.DictationTimerIdle")

    private func freezeIdle() {
        guard running, !idleFrozen else { return }
        checkpoint()
        frozenSeconds = seconds
        idleFrozen = true
        NotificationCenter.default.post(name: Self.idleNotification, object: nil, userInfo: ["enabled": true])
    }

    private func installActivityMonitorIfNeeded() {
        guard scope == .listening, activityMonitor == nil else { return }
        activityMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .mouseMoved]) { [weak self] event in
            self?.noteActivity()
            return event
        }
    }

    private func removeActivityMonitor() {
        if let monitor = activityMonitor { NSEvent.removeMonitor(monitor) }
        activityMonitor = nil
    }

    private func notifyDictationFocus(_ enabled: Bool) {
        NotificationCenter.default.post(name: Notification.Name("LumaReader.DictationFocusChanged"), object: nil, userInfo: ["enabled": enabled])
    }
    var formatted: String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}

struct ListeningDailyGoalCard: View {
    @ObservedObject var timer: StudyDailyTimer
    let completed: Int
    var compact: Bool = false
    @State private var settingsShown = false
    @Environment(\.studyAppearance) private var appearance
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 14) {
            HStack {
                if !compact {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("今日听写").font(.headline)
                        Text("\(completed) / \(timer.target) 词").font(.title2.weight(.semibold)).monospacedDigit()
                    }
                }
                Spacer()
                if compact {
                if !timer.running { Text("已暂停").font(.caption).foregroundStyle(appearance.ink.opacity(0.6)) }
                Image(systemName: "clock").foregroundStyle(appearance.ink.opacity(0.5))
                Text(timer.formatted).font(.system(size: compact ? 13 : 22, weight: .medium, design: .monospaced))
                Button {
                    if timer.running { timer.pause() } else { timer.start() }
                } label: {
                    Image(systemName: timer.running ? "pause.fill" : "play.fill").frame(width: 16)
                }
                .buttonStyle(StudyGlassCapsuleButtonStyle(horizontalPadding: 10, height: 30))
                .help(timer.running ? "暂停计时" : "继续计时")
                .accessibilityLabel(timer.running ? "暂停听写计时" : "开始或继续听写计时")
                }
                if !compact {
                    Button { settingsShown = true } label: { Image(systemName: "ellipsis") }
                        .buttonStyle(.plain).padding(8).help("设置每日目标")
                        .popover(isPresented: $settingsShown) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("每日听写目标").font(.headline)
                                HStack {
                                    TextField("词数", value: Binding(get: { timer.target }, set: { timer.setTarget($0) }), format: .number)
                                        .textFieldStyle(.roundedBorder).frame(width: 100)
                                    Text("词 / 天")
                                }
                                Text("重复巩固不重复计数；达到目标后仍可继续练习。")
                                    .font(.caption).frame(width: 230, alignment: .leading)
                            }.padding(18)
                        }
                }
            }
            if !compact {
            ProgressView(value: min(Double(completed), Double(timer.target)), total: Double(timer.target)).tint(appearance.accent)
            }
        }
        .padding(compact ? 0 : 18)
        .foregroundStyle(appearance.ink)
        .background(appearance.surface.opacity(compact ? 0 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}
