import SwiftUI
import AppKit
import LumaReaderStudyKit

/// 非激活浮动面板：点它不会把你正在看的视频 / 浏览器切到后台，也不会把阅读主窗口带到前面，
/// 但仍可输入文字。置顶、可在全屏视频的桌面上显示。
@MainActor
final class LumaMiniPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 小窗内容：用与学习中心相同的主题色（不用玻璃，保持安静）。
struct MiniPracticeScene: View {
    let store: LibraryStore
    @ObservedObject var panelController: LumaMiniPanelController
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let themeSystem = store.visualThemeSystem
        let dark = store.isDarkAppearance || ((themeSystem == .monet || themeSystem.isAnimeFreshSeries) && colorScheme == .dark && store.appearance == .system)
        let palette = store.readingPalette(dark: dark)
        let appearance = StudyAppearance(
            paper: store.paper(dark: dark),
            ink: palette.ink,
            accent: store.accent,
            surface: store.chrome(dark: dark),
            glassEnabled: false,
            glassOpacity: 0.72,
            isDark: dark,
            visualThemeSystem: themeSystem == .manga ? store.mangaStyleSystemKey : themeSystem.rawValue,
            mangaLineWeight: store.mangaLineWeight
        )
        LumaMiniPracticeRoot(isPresented: panelController.isPresented, canPlay: { [weak panelController] in
            panelController?.isVisible == true && !LumaAppDelegate.displaySuspended
        })
            .environment(\.studyAppearance, appearance)
            .modifier(AppLanguageScope())
            .modifier(LumaThemeScope(store: store))
            .environment(\.lumaTextScale, CGFloat(store.globalTextScale))
            .foregroundStyle(palette.ink)
            .tint(store.accent)
            .preferredColorScheme(store.preferredColorScheme)
    }
}

@MainActor
final class LumaMiniPanelController: NSObject, NSWindowDelegate, ObservableObject {
    static let shared = LumaMiniPanelController()

    /// 主窗口出现时赋值；小窗跟随它的主题。
    var store: LibraryStore?
    private var panel: LumaMiniPanel?
    private var observer: NSObjectProtocol?
    @Published private(set) var isPresented = false

    var isVisible: Bool { panel?.isVisible == true }

    override init() {
        super.init()
        observer = NotificationCenter.default.addObserver(forName: LumaMiniPracticeNotification.open, object: nil, queue: .main) { [weak self] note in
            let source = note.userInfo?["source"] as? String
            let scope = note.userInfo?["scope"] as? String
            MainActor.assumeIsolated { self?.show(source: source, scope: scope) }
        }
    }

    func show(source: String?, scope: String?) {
        guard let store else { return }
        if let source {
            UserDefaults.standard.set(source, forKey: "luma.mini.source")
            if let scope, !scope.isEmpty {
                UserDefaults.standard.set(scope, forKey: source == "listening" ? "luma.mini.listeningDeck" : "luma.mini.confusableScope")
            }
        }
        if panel == nil { panel = makePanel(store: store) }
        panel?.orderFrontRegardless()
        panel?.makeKey()
        isPresented = true
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.close()
        } else {
            show(source: nil, scope: nil)
        }
    }

    private func makePanel(store: LibraryStore) -> LumaMiniPanel {
        let size = NSSize(width: 440, height: 380)
        let panel = LumaMiniPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.contentMinSize = NSSize(width: 360, height: 320)
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.delegate = self
        let hosting = NSHostingView(rootView: MiniPracticeScene(store: store, panelController: self))
        hosting.sizingOptions = []
        panel.contentView = hosting
        let frameName = "LumaMiniPracticePanel"
        let restored = panel.setFrameUsingName(frameName)
        _ = panel.setFrameAutosaveName(frameName)
        if restored {
            let current = panel.contentRect(forFrameRect: panel.frame).size
            let minimum = panel.contentMinSize
            if current.width < minimum.width || current.height < minimum.height {
                panel.setContentSize(NSSize(width: max(current.width, minimum.width),
                                            height: max(current.height, minimum.height)))
            }
        } else {
            if let visible = NSScreen.main?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24, y: visible.minY + 24))
            } else {
                panel.center()
            }
        }
        return panel
    }

    func windowWillClose(_ notification: Notification) {
        isPresented = false
        LumaMiniPracticeRoot.stopPlayback()
        // 主窗口已经关掉、只剩小窗时，关闭小窗就退出，不留空壳进程。
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            let hasMain = NSApp.windows.contains { !($0 is NSPanel) && ($0.isVisible || $0.isMiniaturized) }
            if !hasMain && !self.isVisible { NSApp.terminate(nil) }
        }
    }
}
