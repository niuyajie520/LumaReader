import SwiftUI

@main
struct LumaReaderApp: App {
    @State private var store:LibraryStore
    @MainActor init() {
        #if DEBUG
        _store = State(initialValue:DebugReaderAcceptance.makeStore())
        #else
        _store = State(initialValue:LibraryStore())
        #endif
    }
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        Window(L10n.text("Luma · 图书"),id:"main") {
            ContentView(store: store).modifier(AppLanguageScope()).modifier(LumaThemeScope(store:store))
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
        Settings { ReaderSettings(store: store).modifier(AppLanguageScope()).lumaSurface(radius:0).modifier(LumaThemeScope(store:store)).frame(width: 520,height: 640).preferredColorScheme(store.preferredColorScheme).tint(store.accent) }
    }
}

extension Notification.Name {
    static let lumaFindInBook = Notification.Name("LumaReader.FindInBook")
    static let lumaShowReaderChrome = Notification.Name("LumaReader.ShowReaderChrome")
}
