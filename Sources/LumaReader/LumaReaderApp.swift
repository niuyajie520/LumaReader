import SwiftUI
import LumaReaderStudyKit
import AppKit
import Darwin

@MainActor
final class LumaAppDelegate: NSObject, NSApplicationDelegate {
    /// Closing the last window quits instead of leaving a hidden background process.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private var workspaceObservers: [NSObjectProtocol] = []
    private var memoryPressure: (any DispatchSourceMemoryPressure)?
    private(set) static var displaySuspended = false
    private static var suspensionReasons: Set<String> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.disableRelaunchOnLogin()
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler {
            NotificationCenter.default.post(name: .lumaMemoryPressure, object: nil)
        }
        source.resume(); memoryPressure = source
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    let reason = name == NSWorkspace.willSleepNotification ? "system" : name == NSWorkspace.screensDidSleepNotification ? "display" : "session"
                    Self.suspensionReasons.insert(reason)
                    Self.displaySuspended = true
                    NotificationCenter.default.post(name: .lumaAppDidResignActive, object: nil, userInfo: ["sleep": true])
                }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    let reason = name == NSWorkspace.didWakeNotification ? "system" : name == NSWorkspace.screensDidWakeNotification ? "display" : "session"
                    Self.suspensionReasons.remove(reason)
                    Self.displaySuspended = !Self.suspensionReasons.isEmpty
                    if !Self.displaySuspended { NotificationCenter.default.post(name: .lumaRuntimeDidResume, object: nil) }
                }
            })
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        NotificationCenter.default.post(name: .lumaAppDidResignActive, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .lumaFlushBeforeTermination, object: nil)
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        memoryPressure?.cancel(); memoryPressure = nil
    }
}

@main
struct LumaReaderApp: App {
    @NSApplicationDelegateAdaptor(LumaAppDelegate.self) private var appDelegate
    @State private var store:LibraryStore
    @State private var readerController = ReaderController()
    @MainActor init() {
        if Bundle.main.bundleIdentifier == "app.luma.personal-reader",
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "app.luma.personal-reader")
            .filter({ !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })
            .min(by: { $0.processIdentifier < $1.processIdentifier }),
           existing.processIdentifier < ProcessInfo.processInfo.processIdentifier {
            _ = existing.activate(options: [])
            Darwin.exit(0)
        }
        #if DEBUG
        _store = State(initialValue:DebugReaderAcceptance.makeStore())
        #else
        _store = State(initialValue:LibraryStore())
        #endif
    }
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        Window("",id:"main") {
            ContentView(store: store, controller: readerController).modifier(AppLanguageScope()).modifier(LumaThemeScope(store:store))
                .environment(\.lumaTextScale, CGFloat(store.globalTextScale))
                .font(store.globalTextScale == 1 ? nil : .system(size: CGFloat(13 * store.globalTextScale)))
                .frame(minWidth: 940, minHeight: 620)
                .preferredColorScheme(store.preferredColorScheme)
                .onAppear { DiagnosticManager.shared.applicationDidStart() }
        }
        .defaultSize(width: 1320, height: 860)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.text("导入图书…")) { store.pickBooks() }.keyboardShortcut("o")
                Button(L10n.text("同步已接入云盘")) { store.syncAllConnectedClouds() }.keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button(L10n.text("返回书库")) { store.returnToLibrary() }.keyboardShortcut("l")
            }
            CommandMenu("学习") {
                Button("继续听写") {NotificationCenter.default.post(name:Notification.Name("LumaReader.OpenStudyCenter"),object:nil,userInfo:["mode":"学习_听力","resume":true]);openWindow(id:"main")}.keyboardShortcut("3",modifiers:[.command,.option])
                Button("继续写作") {NotificationCenter.default.post(name:Notification.Name("LumaReader.OpenStudyCenter"),object:nil,userInfo:["mode":"学习_写作_Task1题库","resume":true,"direct":true]);openWindow(id:"main")}.keyboardShortcut("4",modifiers:[.command,.option])
                Button("继续阅读") {NotificationCenter.default.post(name:Notification.Name("LumaReader.ResumeReadingWorkspace"),object:nil);openWindow(id:"main")}.keyboardShortcut("5",modifiers:[.command,.option])
            }
            CommandMenu(L10n.text("阅读")) {
                Button(L10n.text("展开 / 收起 AI 助手")) { if store.aiPanelVisible { store.aiPanelVisible = false } else { store.askAI() }; openWindow(id:"main") }.keyboardShortcut("a",modifiers:[.command,.option])
                Divider()
                Button(L10n.text("在此书中搜索")) { NotificationCenter.default.post(name:.lumaFindInBook,object:nil) }.keyboardShortcut("f").disabled(store.selectedBook == nil)
                Button(L10n.text("显示阅读工具栏")) { NotificationCenter.default.post(name:.lumaShowReaderChrome,object:nil) }.keyboardShortcut("t",modifiers:[.command,.option]).disabled(store.selectedBook == nil)
                Button(L10n.text("添加书签")) { store.reader?.addBookmark() }.keyboardShortcut("d")
                    .disabled(store.selectedBook == nil)
                Button(L10n.text("高亮所选文字")) { store.reader?.highlight(store.activeInk) }
                    .keyboardShortcut("h", modifiers: [.command,.shift])
                    .disabled(store.reader?.hasSelection != true)
                Button(L10n.text("上一页 / 节")) { store.reader?.move(-1) }.keyboardShortcut(.leftArrow, modifiers: [.command])
                Button(L10n.text("下一页 / 节")) { store.reader?.move(1) }.keyboardShortcut(.rightArrow, modifiers: [.command])
                Divider()
                Button(L10n.text("放大主页字号")) { store.adjustHomeFontSize(by: 1) }.keyboardShortcut("+", modifiers: [.command])
                Button(L10n.text("缩小主页字号")) { store.adjustHomeFontSize(by: -1) }.keyboardShortcut("-", modifiers: [.command])
                Button(L10n.text("重置主页字体")) { store.resetHomeTypography() }.keyboardShortcut("0", modifiers: [.command])
                Divider()
                Button(L10n.text("展开 / 折叠批注")) { store.toggleInspector() }.keyboardShortcut("1", modifiers: [.command,.option])
                Button(L10n.text("阅读统计")) { store.returnToLibrary(statistics:true) }.keyboardShortcut("2",modifiers:[.command,.option])
                Button(L10n.text("进入 / 退出沉浸阅读")) { store.toggleImmersive() }.keyboardShortcut("i",modifiers:[.command,.option])
                Button(L10n.text("导出批注…")) { store.exportNotes() }.keyboardShortcut("e", modifiers: [.command,.shift])
            }
        }
        Settings { ReaderSettings(store: store).modifier(AppLanguageScope()).lumaSurface(radius:0).modifier(LumaThemeScope(store:store)).environment(\.lumaTextScale, CGFloat(store.globalTextScale)).font(store.globalTextScale == 1 ? nil : .system(size: CGFloat(13 * store.globalTextScale))).frame(width: 780,height: 620).preferredColorScheme(store.preferredColorScheme).tint(store.accent) }
    }
}

extension Notification.Name {
    static let lumaMemoryPressure = Notification.Name("LumaReader.MemoryPressure")
    static let lumaRuntimeDidResume = Notification.Name("LumaReader.RuntimeDidResume")
    static let lumaAppDidResignActive = Notification.Name("LumaReader.AppDidResignActive")
    static let lumaFlushBeforeTermination = Notification.Name("LumaReader.FlushBeforeTermination")
    static let lumaFindInBook = Notification.Name("LumaReader.FindInBook")
    static let lumaShowReaderChrome = Notification.Name("LumaReader.ShowReaderChrome")
}
