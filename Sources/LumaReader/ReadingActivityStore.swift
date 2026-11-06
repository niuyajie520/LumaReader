import AppKit
import Observation

@MainActor @Observable
final class ReadingActivityStore {
    private(set) var ledger = ReadingLedger()
    @ObservationIgnored var onRecord: (() -> Void)?
    var error: String?
    var dailyGoalMinutes: Int = 30 { didSet { UserDefaults.standard.set(dailyGoalMinutes,forKey:"dailyGoalMinutes") } }
    var idleMinutes: Int = 5 { didSet { UserDefaults.standard.set(idleMinutes,forKey:"readingIdleMinutes") } }
    private(set) var isCounting = false
    @ObservationIgnored private let file: URL
    @ObservationIgnored private var canWrite = true
    @ObservationIgnored private var readingVisible = false
    @ObservationIgnored private weak var readingWindow: NSWindow?
    @ObservationIgnored private var beganAt: Date?
    @ObservationIgnored private var beganUptime: TimeInterval?
    @ObservationIgnored private var lastInteraction: TimeInterval = 0
    @ObservationIgnored private var deadlineTask: Task<Void,Never>?
    @ObservationIgnored private var eventMonitor: Any?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(root: URL) {
        file = root.appendingPathComponent("reading-statistics.json")
        if FileManager.default.fileExists(atPath:file.path) {
            do { ledger = try JSONDecoder().decode(ReadingLedger.self,from:Data(contentsOf:file)) }
            catch { canWrite = false; self.error = "阅读记录读取失败，已保留原文件并停止写入。" }
        }
        let prefs = UserDefaults.standard
        dailyGoalMinutes = min(600,max(5,prefs.object(forKey:"dailyGoalMinutes") as? Int ?? 30))
        idleMinutes = min(30,max(1,prefs.object(forKey:"readingIdleMinutes") as? Int ?? 5))
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.scrollWheel,.leftMouseDown,.rightMouseDown]) { [weak self] event in
            self?.interaction()
            return event
        }
        let center = NotificationCenter.default
        for name in [NSApplication.willResignActiveNotification,NSApplication.willTerminateNotification,NSWindow.didResignKeyNotification,NSWindow.didMiniaturizeNotification] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pause() }
            })
        }
        for name in [NSApplication.didBecomeActiveNotification,NSWindow.didBecomeKeyNotification,NSWindow.didDeminiaturizeNotification] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.interaction() }
            })
        }
        observers.append(center.addObserver(forName:NSWindow.didChangeOcclusionStateNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.eligible != true { self?.pause() } }
        })
        for name in [NSWorkspace.willSleepNotification,NSWorkspace.screensDidSleepNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pause() }
            })
        }
    }

    private var eligible: Bool {
        guard readingVisible,NSApp.isActive,let window = NSApp.keyWindow,window === readingWindow else { return false }
        return window.isVisible && !window.isMiniaturized && window.occlusionState.contains(.visible) && window.attachedSheet == nil
    }

    func setReadingWindow(_ window: NSWindow?) {
        readingWindow = window
        if window == nil { pause() } else { interaction() }
    }

    func setReadingVisible(_ visible: Bool) {
        readingVisible = visible
        visible ? interaction() : pause()
    }

    func interaction() {
        guard eligible else { pause(); return }
        let now = ProcessInfo.processInfo.systemUptime
        lastInteraction = now
        if !isCounting {
            beganAt = Date(); beganUptime = now; isCounting = true
            armDeadline()
        }
    }

    private func armDeadline() {
        deadlineTask?.cancel()
        deadlineTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isCounting else { return }
                let remaining = max(0,self.lastInteraction + Double(self.idleMinutes*60) - ProcessInfo.processInfo.systemUptime)
                if remaining <= 0 { self.pause(); return }
                // One adaptive inactivity deadline, not a second-by-second UI timer.
                do { try await Task.sleep(for:.seconds(remaining)) } catch { return }
            }
        }
    }

    func pause() {
        deadlineTask?.cancel(); deadlineTask = nil
        guard let start = beganAt,let uptime = beganUptime else { isCounting = false; return }
        let end = min(ProcessInfo.processInfo.systemUptime,lastInteraction + Double(idleMinutes*60))
        let elapsed = max(0,end-uptime)
        beganAt = nil; beganUptime = nil; isCounting = false
        guard elapsed > 0 else { return }
        ledger.record(start:start,seconds:elapsed)
        persist()
        onRecord?()
    }


    func resetDay(_ date:Date,undo:UndoManager?) {
        pause(); setDayReset(date,active:true,undo:undo)
    }
    func undoResetDay(_ date:Date,undo:UndoManager?) { setDayReset(date,active:false,undo:undo) }
    private func setDayReset(_ date:Date,active:Bool,undo:UndoManager?) {
        let key = ReadingLedger.key(date,calendar:.current)
        if active {
            if ledger.resetDays == nil { ledger.resetDays = [:] }
            ledger.resetDays?[key] = Date()
        } else {
            if ledger.restoredDays == nil { ledger.restoredDays = [:] }
            ledger.restoredDays?[key] = Date()
        }
        persist(); onRecord?()
        undo?.registerUndo(withTarget:self) { target in
            MainActor.assumeIsolated { target.setDayReset(date,active:!active,undo:undo) }
        }
        undo?.setActionName("重置阅读记录")
    }

    func merge(with remote: ReadingLedger) {
        let updated = CloudSyncEngine.mergeLedger(local: ledger, remote: remote)
        guard updated != ledger else { return }
        ledger = updated
        persist()
    }

    private func persist() {
        guard canWrite else { return }
        do { try JSONEncoder().encode(ledger).write(to:file,options:.atomic) }
        catch { self.error = "阅读记录保存失败：\(error.localizedDescription)" }
    }
}
