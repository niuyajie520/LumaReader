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
    public init() {}

    private enum CodingKeys: String, CodingKey { case listeningMode, activePracticeListeningMode, selectedDeckID, writingMode, activePracticeWritingMode, writingDraftID, dictationInput, inputWordID, showMeaning, revealedWordID, deckInputs, deckInputWordIDs, deckShowMeaning, deckRevealedWordIDs }
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
    }

}

/// Lifetime belongs to the application window, not a particular study page.
/// Preserves independent state across Reading, Listening/Dictation, and Writing modules,
/// and keeps formal exam countdowns running continuously in real time across view switches.
@MainActor public final class LumaStudySession {
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

@MainActor final class ListeningDailyGoal: ObservableObject {
    @Published var target: Int = 300
    @Published private(set) var seconds: Int = 0
    @Published private(set) var running = false
    private let defaults = UserDefaults.standard
    private var day = ""
    private var startedAt: Date?
    private var ticker: Task<Void, Never>?

    init() {
        let saved = defaults.integer(forKey: "luma.listening.dailyTarget")
        target = saved > 0 ? saved : 300
        restoreToday()
    }
    private static func key(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    private func restoreToday() {
        day = Self.key(Date())
        seconds = defaults.integer(forKey: "luma.listening.seconds." + day)
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
                let storeKey = "luma.listening.seconds." + dateKey
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
        // dictation_focus_v7
        NotificationCenter.default.post(name: Notification.Name("LumaReader.DictationFocusChanged"), object: nil, userInfo: ["enabled": true])
        ticker = Task { @MainActor [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self else { return }
                ticks += 1
                if ticks % 15 == 0 { self.checkpoint() }
                else {
                    let today = Self.key(Date())
                    if today != self.day { self.checkpoint() }
                    else { self.seconds = self.defaults.integer(forKey: "luma.listening.seconds." + today) + Int(Date().timeIntervalSince(self.startedAt ?? Date())) }
                }
            }
        }
    }
    func pause() {
        checkpoint(); running = false; startedAt = nil
        NotificationCenter.default.post(name: Notification.Name("LumaReader.DictationFocusChanged"), object: nil, userInfo: ["enabled": false])
        ticker?.cancel(); ticker = nil
    }
    var formatted: String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}

struct ListeningDailyGoalCard: View {
    @ObservedObject var timer: ListeningDailyGoal
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
