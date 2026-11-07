import SwiftUI
import LumaReaderStudyKit
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
    @MainActor init(store:LibraryStore, controller:ReaderController? = nil) {
        self.store = store
        _controller = State(initialValue:controller ?? ReaderController())
    }
    @State private var studySession:LumaStudySession?
    @AppStorage("workspaceReadingBookID") private var workspaceReadingBookID=""
    @State private var studyVisible = false
    @State private var studyPreviousVisibility:NavigationSplitViewVisibility = .all
    @State private var studyPreviousAI = false
    @State private var studyMode = "学习"
    @Bindable var store: LibraryStore
    @Environment(\.undoManager) private var undo
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lumaMuted) private var muted
    @Environment(\.colorScheme) private var colorScheme
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var visibilityBeforeImmersion: NavigationSplitViewVisibility = .all
    @State private var controller = ReaderController()
    @State private var collection = "全部图书"
    @State private var activeCloudFilter: CloudProvider? = nil
    @State private var activeGroupID: UUID?
    @State private var showGroupEditor = false
    @State private var editingGroupID: UUID?
    @State private var groupName = ""
    @State private var groupBookID: UUID?
    @State private var titlebarInset: CGFloat = 90
    @State private var focusHeaderShown = false
    @State private var chromeTopHovered = false
    @State private var chromeHeaderHovered = false
    @State private var chromeKeyboardPinned = false
    @State private var chromeHideTask: Task<Void,Never>?
    @FocusState private var readerBackFocused: Bool
    @State private var showSettings = false
    @State private var showCustomization = false
    @State private var previewPDFAfterSettings = false
    @State private var aiResizeTask:Task<Void,Never>?
    @State private var aiDragWidth:CGFloat?
    @State private var activeReaderPanel: ReaderPanel?
    private var savedAIPanelWidth:Double { get { store.aiPanelWidth } nonmutating set { store.aiPanelWidth = newValue } }
    @Namespace private var chromeNamespace
    @State private var showBookSearch = false
    @State private var bookSearchText = ""
    @AppStorage("libraryLayout") private var libraryLayout = "grid"
    @AppStorage("librarySort") private var librarySort = "recent"
    @State private var dropGroupID: UUID?
    @State private var importDropTarget = false
    @State private var categorySearchShown = false
    @State private var categorySearch = ""
    @State private var dropCategoryID: UUID?
    @State private var dropCategoryAfter = false
    @State private var hoveredBookID: UUID?
    @FocusState private var shelfSearchFocused: Bool
    private enum ReaderPanel: Hashable { case contents, bookmarks, notes }

    var body: some View {
        lumaSelection
        .environment(\.lumaMotionLevel,store.effectiveMotionLevel)
        .modifier(LumaAppIconAppearance())
        .background(ReaderKeyboardBridge(controller:controller,enabled:store.selectedBook != nil && !showSettings && !showCustomization && !showBookSearch && activeReaderPanel == nil && controller.imagePreview == nil).frame(width:0,height:0))
        .lumaPanel(isPresented:Binding(get:{ controller.imagePreview != nil },set:{ if !$0 { controller.imagePreview = nil } }),size:CGSize(width:880,height:620),paper:store.paper(dark:colorScheme == .dark),accent:store.accent) {
            if let preview = controller.imagePreview {
                ReaderImageViewer(preview:preview,askAI:{ controller.imagePreview = nil; controller.askAboutImage(preview) },onClose:{ controller.imagePreview = nil },paper:store.paper(dark:colorScheme == .dark))
            }
        }
        .lumaPanel(isPresented:$showCustomization,size:CGSize(width:780,height:640),paper:store.paper(dark:colorScheme == .dark),accent:store.accent,fromGear:true) {
            CustomizationPanel(store:store,onClose:{ showCustomization = false })
        }
        .lumaPanel(isPresented:$showSettings,size:CGSize(width:560,height:640),paper:store.paper(dark:colorScheme == .dark),accent:store.accent,fromGear:true) {
            ReaderSettings(previewPDF:{ previewPDFAfterSettings = true; showSettings = false },store:store,onClose:{ showSettings = false })
        }
        .onChange(of:showSettings) { _,shown in
            if !shown && previewPDFAfterSettings { previewPDFAfterSettings = false; controller.previewCurrentPDFPage() }
        }
        .alert(L10n.text(editingGroupID == nil ? "新建分类":"重命名分类"),isPresented:$showGroupEditor) {
            TextField(L10n.text("分类名称"),text:$groupName)
            Button(L10n.text("取消"),role:.cancel) { groupBookID = nil }
            Button(L10n.text("保存")) { saveGroupName() }.keyboardShortcut(.defaultAction)
        }
        .alert(L10n.text("提示"), isPresented: lumaErrorPresented) {
            Button(L10n.text("好")) { store.error = nil }
        } message: { Text(L10n.text(store.error ?? "")) }
    }

    private var lumaSelection: some View {
        lumaLifecycle
        .onChange(of:store.collections) { _,groups in
            if let id = activeGroupID, !groups.active.contains(where:{ $0.id == id }) { activeGroupID = nil; collection = "全部图书" }
        }
        .onChange(of:store.selectedID) { _,id in
            activeReaderPanel = nil; showBookSearch = false; bookSearchText = ""
            chromeHideTask?.cancel(); focusHeaderShown = false; chromeKeyboardPinned = false
            chromeTopHovered = false; chromeHeaderHovered = false
            // Briefly introduce the controls on entry, then let the single
            // cancellation-aware chrome timer return the reader to quiet mode.
            if let id {workspaceReadingBookID=id.uuidString;studyVisible=false;revealReaderChrome(delay:1200)}
            store.showInspector = false
            let keyboard = NSApp.currentEvent?.type == .keyDown
            withAnimation(keyboard || reduceMotion || store.effectiveMotionLevel == .off ? nil:.smooth(duration:0.24,extraBounce:0)) {
                columnVisibility = id == nil ? .all : .detailOnly
            }
        }
        .onChange(of:store.showInspector) { _,shown in
            if shown { activeReaderPanel = .notes }
            else if activeReaderPanel == .notes { activeReaderPanel = nil }
        }
        .onChange(of:activeReaderPanel) { _,panel in store.showInspector = panel == .notes }
        .onChange(of:showSettings) { _,shown in store.activity.setReadingVisible(!shown && !showCustomization && store.selectedBook != nil) }
        .onChange(of:showCustomization) { _,shown in store.activity.setReadingVisible(!shown && !showSettings && store.selectedBook != nil) }
    }

    private var lumaLifecycle: some View {
        lumaAppearance
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
            store.systemReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            store.systemReduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            controller.updateSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for:.NSProcessInfoPowerStateDidChange)) { _ in
            store.systemLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willResignActiveNotification)) { _ in store.flush() }
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) { _ in store.flush() }
        .onDisappear { chromeHideTask?.cancel(); store.flush() }
        .onAppear {
            store.syncAllConnectedClouds()
            if store.selectedBook != nil { scheduleChromeHide() }
            #if DEBUG
            DebugReaderAcceptance.startIfRequested(store:store,controller:controller)
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) { _ in store.syncAllConnectedClouds() }
    }

    private var lumaReaderChrome: some View {
        lumaNavigation
        .onChange(of:studyVisible){_,shown in if !shown{studySession?.suspend()}}
        .onChange(of:studyMode) { oldMode,mode in
            guard studyVisible else{return}
            let wasPractice=oldMode.contains("模拟机考") || ["学习_听力_今日计划","学习_听力_错词复习"].contains(oldMode)
            let nowPractice=mode.contains("模拟机考") || ["学习_听力_今日计划","学习_听力_错词复习"].contains(mode)
            if nowPractice && !wasPractice {
                studyPreviousVisibility=columnVisibility;studyPreviousAI=store.aiPanelVisible
                columnVisibility = .detailOnly;store.aiPanelVisible=false
            } else if wasPractice && !nowPractice {
                columnVisibility=studyPreviousVisibility;store.aiPanelVisible=studyPreviousAI
            }
        }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("LumaReader.OpenStudyCenter"))) { notice in
            openStudy(mode:notice.userInfo?["mode"] as? String ?? "学习",resume:notice.userInfo?["resume"] as? Bool ?? false)
        }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("LumaReader.ResumeReadingWorkspace"))){_ in resumeReadingWorkspace()}
        .onReceive(NotificationCenter.default.publisher(for:.lumaFindInBook)) { _ in
            guard store.selectedBook != nil else { return }; activeReaderPanel = nil; showBookSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for:.lumaShowReaderChrome)) { _ in
            showReaderChromeFromKeyboard()
        }
        .onChange(of:controller.pageTurnPulse) { _,_ in revealReaderChrome(delay:1000) }
        .onChange(of:controller.hasSelection) { _,_ in scheduleChromeHide() }
        .onReceive(NotificationCenter.default.publisher(for:NSMenu.didBeginTrackingNotification)) { _ in chromeKeyboardPinned = true }
        .onReceive(NotificationCenter.default.publisher(for:NSMenu.didEndTrackingNotification)) { _ in chromeKeyboardPinned = false; scheduleChromeHide() }
        .onReceive(NotificationCenter.default.publisher(for:NSWindow.didResignKeyNotification)) { _ in
            chromeTopHovered = false; chromeHeaderHovered = false
            chromeKeyboardPinned = false; scheduleChromeHide()
        }
        .onReceive(NotificationCenter.default.publisher(for:NSWindow.didEnterFullScreenNotification)) { notice in
            guard let window = controller.readingWindow, (notice.object as? NSWindow) === window else { return }
            // AppKit can reveal its native controls during the transition even
            // when the requested visibility has not changed. Reconcile them
            // together with both header groups after the transition finishes.
            chromeTopHovered = false; chromeHeaderHovered = false
            chromeKeyboardPinned = false; focusHeaderShown = false
            NativeWindowControls.restore(window,controlsVisible:false,animated:false)
            scheduleChromeHide()
        }
        .onReceive(NotificationCenter.default.publisher(for:NSWindow.didExitFullScreenNotification)) { _ in
            chromeTopHovered = false; chromeHeaderHovered = false
            chromeKeyboardPinned = false; scheduleChromeHide()
        }
        .onChange(of:controller.readingClickPulse) { _,_ in chromeKeyboardPinned = false; scheduleChromeHide() }
        .onChange(of:activeReaderPanel) { _,_ in scheduleChromeHide() }
        .onChange(of:showBookSearch) { _,_ in scheduleChromeHide() }
        .onChange(of:showSettings) { _,_ in scheduleChromeHide() }
        .onChange(of:showCustomization) { _,_ in scheduleChromeHide() }
    }

    private func showReaderChromeFromKeyboard() {
        guard store.selectedBook != nil else { return }
        chromeKeyboardPinned = true
        revealReaderChrome(delay:1250)
        readerBackFocused = true
    }

    private var lumaAppearance: some View {
        lumaReaderChrome
        .onReceive(NotificationCenter.default.publisher(for:.lumaAskAI)) { _ in store.aiPanelVisible = true }
        .onExitCommand {
            if showBookSearch { showBookSearch = false }
            else if activeReaderPanel != nil { activeReaderPanel = nil }
            else if chromeKeyboardPinned { chromeKeyboardPinned = false; readerBackFocused = false; scheduleChromeHide() }
            else if store.immersive { store.toggleImmersive() }
        }
        .tint(store.accent).accentColor(store.accent)
        .toggleStyle(LumaThemeSwitchStyle(accent:store.accent))
        .foregroundStyle(store.readingPalette(dark:colorScheme == .dark).ink)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background(ReaderWindowChrome(color: NSColor(store.paper(dark:colorScheme == .dark)),
                                       controlsVisible:readerChromeVisible,animateControls:true,
                                       onSafeInset:{ value in if abs(titlebarInset-value)>1 { titlebarInset = value } })
            .frame(width:0,height:0))
        .onChange(of:store.immersive) { _,immersive in
            if immersive { visibilityBeforeImmersion = columnVisibility; columnVisibility = .detailOnly; closeReaderPanels(); focusHeaderShown = false }
            else { columnVisibility = visibilityBeforeImmersion }
        }
        .onChange(of:AppLanguage.shared.code) { _,_ in controller.updateSettings() }
        .onChange(of:colorScheme) { _,_ in controller.updateSettings() }
        .onChange(of:store.theme) { _,_ in controller.updateSettings() }
        .onChange(of:store.monetPalette) { _,_ in controller.updateSettings() }
        .onChange(of:store.monetEnabled) { _,_ in controller.updateSettings() }
        .onChange(of:store.readerFontFamily) { _,_ in controller.updateSettings() }
        .onChange(of:store.energySaving) { _,_ in controller.updateSettings() }
        .onChange(of:store.systemLowPower) { _,_ in controller.updateSettings() }
        .onChange(of:store.visualMotionLevel) { _,_ in controller.updateSettings() }
    }

    private var studyPractice:Bool {studyVisible && (studyMode.contains("模拟机考") || ["学习_听力_今日计划","学习_听力_错词复习"].contains(studyMode))}
    private var lumaNavigation: some View {
        HStack(spacing:0) {
            sidebar
                .zIndex(2)
                .environment(\.lumaSurfacePolish,true)
                .frame(width:215)
                .frame(width:columnVisibility == .detailOnly ? 0:215,alignment:.leading)
                .clipped()
                .allowsHitTesting(columnVisibility != .detailOnly)
                .accessibilityHidden(columnVisibility == .detailOnly)
            GeometryReader { geometry in
            let aiWidth = min(max(340,min(geometry.size.width*0.60,geometry.size.width-336)),max(340,CGFloat(store.aiPanelExpanded ? 520:savedAIPanelWidth)))
            ZStack(alignment:.topTrailing) {
            primaryContent
                .environment(\.lumaSurfacePolish,true)
                .modifier(ReadingLayoutSlot(width:geometry.size.width-(store.aiPanelVisible ? aiWidth+16:0),height:geometry.size.height-((store.immersive && store.selectedBook == nil) || studyPractice ? 0:64)))
                .clipped()
                .padding(.top,(store.immersive && store.selectedBook == nil) || studyPractice ? 0:64)
                .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                .animation(nil,value:aiWidth)
                .animation(reduceMotion || store.effectiveMotionLevel == .off ? nil:(store.aiPanelVisible ? AIPanelMotion.opening:AIPanelMotion.closing),value:store.aiPanelVisible)
        appHeader(availableWidth:geometry.size.width-(store.aiPanelVisible ? aiWidth+16:0))
            .padding(.trailing,store.aiPanelVisible ? aiWidth+16:0)
            .opacity(studyPractice ? 0:1)
            .allowsHitTesting(readerChromeVisible && !studyPractice)
            .onHover { inside in
                // Reading hover belongs to the window event monitor. Keeping a
                // second SwiftUI hover owner can re-pin the fading controls.
                guard store.selectedBook == nil else { return }
                chromeHeaderHovered = inside
                if inside { revealReaderChrome() } else { scheduleChromeHide() }
            }
            AIChatView(store:store,onCollapse:{ store.aiPanelVisible = false })
                .frame(width:aiWidth)
                .animation(aiDragWidth != nil || reduceMotion || store.effectiveMotionLevel == .off ? nil:AIPanelMotion.opening,value:store.aiPanelExpanded)
                .frame(maxHeight:.infinity)
                .background(store.paper(dark:colorScheme == .dark))
                .clipped()
                .overlay(alignment:.leading) { Rectangle().fill(muted.opacity(0.18)).frame(width:0.5).allowsHitTesting(false) }
                .overlay(alignment:.leading) {
                    AIResizeHandle(width:Double(aiWidth),onStart:{
                        aiDragWidth = aiWidth; savedAIPanelWidth = Double(aiWidth); controller.beginViewportChange(); store.aiPanelExpanded = false
                    },onResize:{ value in
                        savedAIPanelWidth = min(Double(max(340,min(geometry.size.width*0.60,geometry.size.width-336))),max(340,value))
                    },onEnd:{ aiDragWidth = nil; settleAILayout(delay:120) })
                    .frame(width:12).frame(maxHeight:.infinity).zIndex(10)
                    .accessibilityLabel(L10n.text("调整 AI 面板宽度"))
                    .accessibilityAdjustableAction { direction in
                        store.aiPanelExpanded = false
                        savedAIPanelWidth = min(Double(max(340,geometry.size.width-336)),max(340,savedAIPanelWidth+(direction == .increment ? 20:-20)))
                    }
                }
                .offset(x:store.aiPanelVisible ? 0:aiWidth+18)
                .allowsHitTesting(store.aiPanelVisible)
                .accessibilityHidden(!store.aiPanelVisible)
                .animation(reduceMotion || store.effectiveMotionLevel == .off ? nil:(store.aiPanelVisible ? AIPanelMotion.opening:AIPanelMotion.closing),value:store.aiPanelVisible)
                .zIndex(3)
            }
            .background(ReaderChromeMonitor(enabled:store.selectedBook != nil,trailingInset:store.aiPanelVisible ? aiWidth+16:0,onTopHover:{ inside in
                chromeTopHovered = inside
                if inside { revealReaderChrome() } else { scheduleChromeHide() }
            }).frame(width:0,height:0))
            .onPreferenceChange(ReadingViewportWidthPreference.self) { width in
                guard width > 0 else { return }; controller.beginViewportChange(); settleAILayout(delay:140)
            }
            .onChange(of:store.aiPanelVisible) { _,visible in
                if !visible { aiDragWidth = nil }
                controller.beginViewportChange(); settleAILayout(delay:visible ? 500:650)
            }
            .onChange(of:aiWidth) { _,_ in controller.beginViewportChange(); settleAILayout(delay:120) }
            }
        }
        .coordinateSpace(name:"lumaWindow")
        .overlayPreferenceValue(SearchAnchorPreference.self) { anchor in searchOverlay(anchor) }
        .animation(LumaMotion.adjusted(SurfaceMotion.popover,level:store.effectiveMotionLevel,reduceMotion:reduceMotion),value:showBookSearch)
        .ignoresSafeArea(.container,edges:.top)
    }

    private enum ChromeState { case hidden, hoverVisible, interacting, pageTurnFeedback, selectionActive, modalOpen }
    private var chromeState:ChromeState {
        if activeReaderPanel != nil || showBookSearch || showSettings || showCustomization { return .modalOpen }
        if chromeKeyboardPinned || chromeHeaderHovered { return .interacting }
        if chromeTopHovered { return .hoverVisible }
        if controller.hasSelection { return .selectionActive }
        return focusHeaderShown ? .pageTurnFeedback:.hidden
    }
    private var readerChromeVisible:Bool {
        store.selectedBook == nil || (chromeState != .hidden && chromeState != .selectionActive)
    }
    private func revealReaderChrome(delay:Int = 1250) {
        chromeHideTask?.cancel()
        withAnimation(reduceMotion || store.effectiveMotionLevel == .off ? nil:.easeOut(duration:0.20)) { focusHeaderShown = true }
        scheduleChromeHide(delay:delay)
    }
    private func scheduleChromeHide(delay:Int = 1250) {
        chromeHideTask?.cancel()
        guard store.selectedBook != nil else { return }
        chromeHideTask = Task { @MainActor in
            do { try await Task.sleep(for:.milliseconds(delay)) } catch { return }
            guard !Task.isCancelled else { return }
            // Hover notifications can remain stuck after SwiftUI replaces an
            // interactive header during its fade. The last delivered window pointer
            // position drives both hover and expiration, including native tests.
            if let window = controller.readingWindow, let content = window.contentView {
                let point = content.convert(ReaderChromePointer.location(in:window), from:nil)
                if content.bounds.contains(point) {
                    let fromTop = content.isFlipped ? point.y : content.bounds.height - point.y
                    if fromTop > 72 {
                        chromeTopHovered = false
                        chromeHeaderHovered = false
                        chromeKeyboardPinned = false
                        readerBackFocused = false
                    }
                }
            }
            // A keyboard shortcut is a temporary reveal, not a permanent pin.
            // Retain focus only while the user is actively hovering a control.
            if !chromeTopHovered && !chromeHeaderHovered {
                chromeKeyboardPinned = false
                readerBackFocused = false
            }
            guard !chromeTopHovered, !chromeHeaderHovered, !chromeKeyboardPinned, !controller.hasSelection,
                  activeReaderPanel == nil, !showBookSearch, !showSettings, !showCustomization else { return }
            withAnimation(reduceMotion || store.effectiveMotionLevel == .off ? nil:.easeOut(duration:0.14)) { focusHeaderShown = false }
        }
    }

    private func settleAILayout(delay:Int) {
        aiResizeTask?.cancel()
        aiResizeTask = Task { @MainActor in
            do { try await Task.sleep(for:.milliseconds(delay)) } catch { return }
            guard !Task.isCancelled else { return }; controller.finishViewportChange(); aiResizeTask = nil
        }
    }

    @ViewBuilder private func searchOverlay(_ anchor:Anchor<CGRect>?) -> some View {
        if showBookSearch, let anchor {
            GeometryReader { geometry in
                    let rect = geometry[anchor]
                    Color.clear.contentShape(Rectangle()).onTapGesture { showBookSearch = false }
                    BookSearchPanel(controller:controller,query:$bookSearchText,accent:store.accent,
                        paper:store.paper(dark:colorScheme == .dark),onSelect:{ showBookSearch = false })
                        .environment(\.lumaSurfacePolish,true)
                        .frame(width:min(380,geometry.size.width-32))
                        .readerGlass(radius:22,enabled:glassActive,tint:store.paper(dark:colorScheme == .dark))
                        .matchedGeometryEffect(id:"search",in:chromeNamespace,properties:.frame,anchor:.topTrailing)
                        .position(x:min(geometry.size.width-206,max(206,rect.maxX-190)),y:min(geometry.size.height-260,rect.maxY+262))
                        .transition(.opacity.combined(with:.scale(scale:0.97,anchor:.topTrailing)))
                        .preferredColorScheme(store.preferredColorScheme)
                }
            }
    }

    private var primaryContent:some View {
        Group {
            if let book = store.selectedBook { reading(book).transition(.opacity) }
            else if studyVisible,let studySession { StudyCenterScreen(mode:$studyMode,store:store,session:studySession) }
            else if store.showStatistics { StatisticsView(activity:store.activity,theme:store.theme,store:store).transition(.opacity) }
            else { library.transition(.opacity) }
        }
        .frame(minWidth:320,maxWidth:.infinity,maxHeight:.infinity)
        .background(store.paper(dark:colorScheme == .dark))
        .animation(!store.coverTransitions || reduceMotion || store.effectiveMotionLevel == .off || NSApp.currentEvent?.type == .keyDown ? nil:SurfaceMotion.spatial,value:store.selectedID)
    }

    // Keep interactive controls in the content area, away from titlebar drag hit regions.
    private var glassActive:Bool { store.effectiveGlassEffectsEnabled && !reduceTransparency }
    private func appHeader(availableWidth:CGFloat)->some View {
        let itemWidth:CGFloat = store.selectedBook == nil || availableWidth >= 520 ? 44:(availableWidth < 400 ? 24:32)
        return LumaGlassCluster(enabled:glassActive) {
        HStack(spacing:availableWidth < 520 ? 4:8) {
            Color.clear.frame(width:columnVisibility == .detailOnly ? titlebarInset:0,height:1).allowsHitTesting(false)
            if store.selectedBook != nil {
                HStack(spacing:3) {
                    Button { closeReaderPanels(); store.returnToLibrary() } label: {
                        Image(systemName:"chevron.left").frame(width:itemWidth,height:44).contentShape(Rectangle())
                    }.help(L10n.text("返回书库 · ⌘L")).accessibilityLabel(L10n.text("返回书库")).focused($readerBackFocused)
                    Button { activeReaderPanel = nil; showBookSearch.toggle() } label: {
                        Image(systemName:"magnifyingglass").frame(width:itemWidth,height:44).contentShape(Rectangle())
                    }.anchorPreference(key:SearchAnchorPreference.self,value:.bounds) { $0 }
                        .help(L10n.text("在此书中搜索")).accessibilityLabel(L10n.text("在此书中搜索"))
                    readerPanelButton(.contents,symbol:"list.bullet",label:"目录",itemWidth:itemWidth)
                    readerPanelButton(.notes,symbol:"note.text",label:"书签、高亮与笔记",itemWidth:itemWidth)
                }.padding(3)
                    .readerGlass(radius:25,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
                    .popover(isPresented:readerPanelPresented,arrowEdge:.bottom) { readerPanelContent.environment(\.lumaSurfacePolish,true) }
                    .opacity(readerChromeVisible ? 1:0).allowsHitTesting(readerChromeVisible).accessibilityHidden(!readerChromeVisible)
            }
            Color.clear.frame(minWidth:0,maxWidth:.infinity).allowsHitTesting(false)
            if store.selectedBook != nil {
                HStack(spacing:10) {
                    HStack(spacing:3) { readerUtilityActions(itemWidth:itemWidth) }.padding(3)
                        .readerGlass(radius:25,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
                    readerBookmarkAction(itemWidth:itemWidth)
                        .padding(3)
                        .readerGlass(radius:25,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
                }
                .opacity(readerChromeVisible ? 1:0).accessibilityHidden(!readerChromeVisible)
            } else {
                HStack(spacing:3) { headerActions(itemWidth:itemWidth) }.padding(3)
                    .anchorPreference(key:SearchAnchorPreference.self,value:.bounds) { $0 }
                    .readerGlass(radius:25,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
            }
        }.buttonStyle(InteractiveToolbarButtonStyle()).padding(.horizontal,12).frame(height:64)
            .onChange(of:readerChromeVisible, initial:true) { _,visible in
                #if DEBUG
                DebugReaderAcceptance.topControlsVisible = visible
                #endif
            }
            .onChange(of:[focusHeaderShown,chromeTopHovered,chromeHeaderHovered,chromeKeyboardPinned,controller.hasSelection,activeReaderPanel != nil,showBookSearch,showSettings,showCustomization], initial:true) { _,flags in
                #if DEBUG
                DebugReaderAcceptance.headerState = flags
                #endif
            }
            .overlay(alignment:.center) {
                if let book = store.selectedBook {
                    // Apple Books-style quiet reading: the title stays centered,
                    // while every actionable control fades away.
                    Text(book.title)
                        .font(store.homeFont(13,weight:.medium))
                        .foregroundStyle(store.readingPalette(dark:colorScheme == .dark).ink.opacity(0.55))
                        .lineLimit(1)
                        .frame(maxWidth:max(160,availableWidth*0.34))
                        .allowsHitTesting(false)
                } else {
                    headerTitle.allowsHitTesting(false)
                }
            }
            .background(store.paper(dark:colorScheme == .dark))
        }
    
    }
    @ViewBuilder private var headerTitle:some View {
        if let book = store.selectedBook {
            VStack(spacing:2) {
                Text(book.title).font(store.homeFont(13,weight:.medium)).lineLimit(1)
                if !book.author.isEmpty { Text(book.author).font(store.homeFont(10)).foregroundStyle(muted).lineLimit(1) }
            }
        } else { Text("Luma Reader").font(store.homeFont(14,weight:.medium)) }
    }
    @ViewBuilder private func headerActions(itemWidth:CGFloat)->some View {
        if store.selectedBook == nil {
            Button { store.pickBooks(groupID:activeGroupID) } label: { Image(systemName:"plus").frame(width:itemWidth,height:44).contentShape(Rectangle()) }.help(L10n.text("导入图书 · ⌘O"))
            Menu {
                Picker(L10n.text("显示"),selection:$libraryLayout) { Text(L10n.text("网格")).tag("grid"); Text(L10n.text("列表")).tag("list") }.pickerStyle(.inline)
                Divider()
                Picker(L10n.text("排序方式"),selection:$librarySort) { Text(L10n.text("最近阅读")).tag("recent"); Text(L10n.text("书名")).tag("title"); Text(L10n.text("作者")).tag("author") }.pickerStyle(.inline)
            } label: { Image(systemName:"ellipsis.circle").frame(width:40,height:44) }.help(L10n.text("显示与排序"))
        }
        if store.selectedBook != nil {
            readerBookmarkAction(itemWidth:itemWidth)
            readerUtilityActions(itemWidth:itemWidth)
        } else {
            Button { showCustomization = true } label: { Image(systemName:"slider.horizontal.3").frame(width:itemWidth,height:44) }
                .help(L10n.text("外观与排版")).accessibilityLabel(L10n.text("外观与排版"))
            Button { showSettings = true } label: { AnimatedSettingsGlyph(active:showSettings).frame(width:itemWidth,height:44).clipped().contentShape(Rectangle()).anchorPreference(key:GearAnchorPreference.self,value:.bounds) { $0 } }
                .help(L10n.text("设置")).accessibilityLabel(L10n.text("设置"))
            Button { store.aiPanelVisible.toggle() } label: { Image(systemName:"sparkles").frame(width:itemWidth,height:44) }
                .help(L10n.text("AI 助手")).accessibilityLabel(L10n.text("AI 助手"))
        }
    }

    private func readerBookmarkAction(itemWidth:CGFloat)->some View {
        Button { controller.addBookmark() } label: {
            Image(systemName:controller.currentBookmark == nil ? "bookmark":"bookmark.fill").frame(width:itemWidth,height:44)
                .phaseAnimator([false,true,false],trigger:controller.bookmarkPulse) { icon,pressed in
                    icon.scaleEffect(reduceMotion || store.effectiveMotionLevel == .off ? 1:pressed ? 0.96:1)
                } animation: { _ in MotionTokens.micro }
        }.foregroundStyle(controller.currentBookmark == nil ? store.readingPalette(dark:colorScheme == .dark).ink:store.accent)
            .help(L10n.text("添加 / 移除本页书签 · ⌘D")).accessibilityLabel(L10n.text(controller.currentBookmark == nil ? "添加本页书签":"移除本页书签"))
    }
    @ViewBuilder private func readerUtilityActions(itemWidth:CGFloat)->some View {
        Button { closeReaderPanels(); showSettings = true } label: {
            AnimatedSettingsGlyph(active:showSettings).frame(width:itemWidth,height:44).clipped().contentShape(Rectangle()).anchorPreference(key:GearAnchorPreference.self,value:.bounds) { $0 }
        }.help(L10n.text("设置")).accessibilityLabel(L10n.text("设置"))
        Button { store.aiPanelVisible.toggle() } label: {
            Image(systemName:"sparkles").frame(width:itemWidth,height:44)
        }.help(L10n.text("展开 / 收起 AI 助手 · ⌥⌘A")).accessibilityLabel(L10n.text("展开或收起 AI 助手"))
    }

    private var readerPanelPresented:Binding<Bool> {
        Binding(get:{ activeReaderPanel != nil },set:{ if !$0 { activeReaderPanel = nil } })
    }
    private func closeReaderPanels() { activeReaderPanel = nil; showBookSearch = false }

    private var lumaErrorPresented: Binding<Bool> {
        Binding(get:{ store.error != nil },set:{ if !$0 { store.error = nil } })
    }

    private func beginGroupEdit(_ group:LibraryGroup? = nil,book:Book? = nil) {
        editingGroupID = group?.id; groupName = group?.name ?? ""; groupBookID = book?.id; showGroupEditor = true
    }
    private func saveGroupName() {
        if let id = editingGroupID {
            store.renameGroup(id,to:groupName)
            if activeGroupID == id, let group = store.collections.active.first(where:{ $0.id == id }) { collection = group.name }
        } else if let id = store.createGroup(groupName) {
            if let bookID = groupBookID, let book = store.shelfBooks.first(where:{ $0.id == bookID }) { store.toggleGroup(id,for:book) }
        }
        groupBookID = nil
    }
    @ViewBuilder private func classificationActions(for book:Book) -> some View {
        Button(L10n.text(book.isFinished ? "标记为未读":"标记为已读")) { store.editShelf(book.id) { $0.isRead = !book.isFinished } }
        Menu(L10n.text("分类")) {
            ForEach(store.collections.active) { group in
                Button { store.toggleGroup(group.id,for:book) } label: {
                    Label(group.name,systemImage:store.collections.contains(book:book.id,in:group.id) ? "checkmark":"folder")
                }
            }
            Divider()
            Button(L10n.text("新建分类…")) { beginGroupEdit(book:book) }
        }
        Button(L10n.text("分享")) { store.shareBook(book) }
        Menu(L10n.text("移除…")) {
            Button(L10n.text("从书架移除")) { store.removeFromShelf(book) }
            Button(L10n.text("删除本地下载…")) { store.deleteLocalDownload(book) }
            Text(L10n.text("不会删除云端原文件"))
        }
    }

    private func readerPanelButton(_ panel:ReaderPanel,symbol:String,label:String,itemWidth:CGFloat)->some View {
        Button {
            showBookSearch = false
            activeReaderPanel = activeReaderPanel == panel ? nil:panel
        } label: {
            Image(systemName:symbol).frame(width:itemWidth,height:44)
                .background(activeReaderPanel == panel ? Color.primary.opacity(0.12):.clear,in:Capsule())
                .contentShape(Rectangle())
        }
            .help(label).accessibilityLabel(label)
    }
    private var readerPanelTitle:String {
        switch activeReaderPanel { case .contents:return "目录";case .bookmarks:return "书签";case .notes:return "高亮标记和笔记";case nil:return "" }
    }
    private var readerPanelContent:some View {
        VStack(spacing:0) {
            Picker(L10n.text("阅读导航"),selection:Binding(get:{ activeReaderPanel ?? .contents },set:{ activeReaderPanel = $0 })) {
                Text(L10n.text("目录")).tag(ReaderPanel.contents)
                Text(L10n.text("书签")).tag(ReaderPanel.bookmarks)
                Text(L10n.text("笔记")).tag(ReaderPanel.notes)
            }.pickerStyle(.segmented).padding(12)
            Text(L10n.text(readerPanelTitle)).font(store.homeFont(16,weight:.medium)).padding(.bottom,12)
            Divider().opacity(0.25)
            ZStack {
                Group {
                    if let id = store.selectedID {
                        ReadingOutlineView(items:controller.outline,bookID:id,currentChapter:controller.chapterIndex,currentHeadingIndex:controller.currentHeadingIndex,currentHeadingID:controller.currentHeadingID,disabled:controller.isTurning) { item in
                            if item.chapterIndex != nil { controller.goToOutline(item); activeReaderPanel = nil }
                        }.id(id)
                    }
                }.opacity(activeReaderPanel == .contents ? 1:0).allowsHitTesting(activeReaderPanel == .contents).accessibilityHidden(activeReaderPanel != .contents)
                bookmarkNavigation.opacity(activeReaderPanel == .bookmarks ? 1:0).allowsHitTesting(activeReaderPanel == .bookmarks).accessibilityHidden(activeReaderPanel != .bookmarks)
                Group { if let book = store.selectedBook { notesInspector(book) } }
                    .opacity(activeReaderPanel == .notes ? 1:0).allowsHitTesting(activeReaderPanel == .notes).accessibilityHidden(activeReaderPanel != .notes)
            }.frame(maxWidth:.infinity,maxHeight:.infinity)
        }.frame(width:340,height:520)
            .foregroundStyle(store.readingPalette(dark:colorScheme == .dark).ink)
            .readerGlass(radius:16,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
            .contentShape(Rectangle())
    }
    private var bookmarkNavigation:some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:4) {
                if let book = store.selectedBook {
                    if (book.bookmarks ?? []).isEmpty {
                        ContentUnavailableView(L10n.text("暂无书签"),systemImage:"bookmark").frame(maxWidth:.infinity).padding(.top,50)
                    }
                    ForEach(book.bookmarks ?? []) { mark in
                        HStack {
                            Button { controller.jump(to:mark); activeReaderPanel = nil } label: {
                                VStack(alignment:.leading,spacing:4) {
                                    Label(mark.title,systemImage:"bookmark.fill")
                                    if let anchor = mark.anchor { Text(anchor.quote).font(.caption).foregroundStyle(muted).lineLimit(2) }
                                }.frame(maxWidth:.infinity,alignment:.leading)
                            }.buttonStyle(.plain).disabled(controller.isTurning)
                            Button { store.removeBookmark(mark,from:book.id) } label: { Image(systemName:"trash") }.buttonStyle(.borderless)
                        }.font(store.homeFont(13)).padding(12)
                    }
                }
            }.padding(10)
        }
    }
    private var sidebar: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName:"book.closed.fill").font(.system(size:20,weight:.light)).foregroundStyle(store.accent)
                Text("Luma")
                    .font(store.homeFont(22, weight: .medium))
                    .tracking(LumaFontFamily.opticalTracking(for: 22))
            }.padding(.horizontal,18).padding(.top,48).padding(.bottom,22)

            LumaSidebarSection("图书",key:"librarySectionExpanded",symbol:"books.vertical",prominent:true,font:store.homeFont(17,weight:.medium)) {
                VStack(spacing:3) {
                    if let book=store.shelfBooks.first(where:{$0.id.uuidString==workspaceReadingBookID}) {
                        Button {resumeReadingWorkspace()} label:{Label("继续阅读 · \(book.title)",systemImage:"book.pages").lineLimit(1).frame(maxWidth:.infinity,minHeight:44,alignment:.leading).padding(.horizontal,11)}
                            .buttonStyle(LumaSidebarButtonStyle(isSelected:store.selectedID==book.id,accent:store.accent))
                    }
                    sideRow("全部图书",symbol:"books.vertical",count:store.shelfBooks.count)
                    sideRow("正在阅读",symbol:"book",count:store.shelfBooks.filter{$0.progress>0 && !$0.isFinished}.count)
                    sideRow("已读完",symbol:"checkmark.circle",count:store.shelfBooks.filter{$0.isFinished}.count)
                    sideRow("阅读统计",symbol:"chart.bar.xaxis",count:nil)
                }.padding(.horizontal,10)
                LumaSidebarSection("分类",key:"collectionSectionExpanded",onAdd:{ beginGroupEdit() },onSearch:{ categorySearchShown.toggle() }) {
                    VStack(spacing:3) {
                        if categorySearchShown {
                            HStack(spacing:5) {
                                TextField(L10n.text("搜索分类"),text:$categorySearch).textFieldStyle(.plain)
                                if !categorySearch.isEmpty {
                                    Button { categorySearch = "" } label: { Image(systemName:"xmark.circle.fill").frame(width:28,height:28) }
                                        .buttonStyle(.plain).accessibilityLabel(L10n.text("清空分类搜索"))
                                }
                            }.font(store.homeFont(12)).padding(7).lumaInputSurface().padding(.horizontal,12)
                        }
                        ForEach(filteredCollections) { group in categoryRow(group) }
                        if filteredCollections.isEmpty {
                            Text(L10n.text(categorySearch.isEmpty ? "暂无分类":"没有匹配的分类")).font(store.homeFont(11)).foregroundStyle(muted).padding(12)
                        }
                        if !categorySearch.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                            Text(L10n.text("搜索时暂停分类排序")).font(store.homeFont(10)).foregroundStyle(muted).padding(.horizontal,12)
                        }
                        Button(L10n.text("新建分类…")) { beginGroupEdit() }.buttonStyle(.plain).frame(maxWidth:.infinity,minHeight:40,alignment:.leading).padding(.horizontal,22)
                    }
                }.padding(.leading,14).padding(.top,8)
            }
            LumaSidebarSection("学习",key:"studySectionExpanded",symbol:"graduationcap",prominent:true,font:store.homeFont(17,weight:.medium)) {
                VStack(spacing:3) {
                    studyRow("听力", mode:"学习_听力", symbol:"headphones")
                    studyRow("写作", mode:"学习_写作_Task1题库", symbol:"pencil")
                    studyRow("学习统计", mode:"学习_统计", symbol:"chart.bar")
                }.padding(.horizontal,10)
            }.padding(.top,12)
            LumaSidebarSection("云盘",key:"cloudSectionExpanded",symbol:"cloud",prominent:true,font:store.homeFont(17,weight:.medium),busy:store.isSyncingCloud) {
                VStack(spacing:3) {
                    ForEach(CloudProvider.allCases) { provider in cloudSideRow(provider) }
                }.padding(.horizontal,10)
            }.padding(.top,12)

            Spacer()

        }
        }
        .background(store.paper(dark:colorScheme == .dark))
    }

    private var filteredCollections:[LibraryGroup] {
        let query = categorySearch.trimmingCharacters(in:.whitespacesAndNewlines)
        return store.orderedCollections.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
    }
    @ViewBuilder private func categoryRow(_ group:LibraryGroup)->some View {
        let row = Button {
            studyVisible = false
            activeGroupID = group.id; activeCloudFilter = nil; collection = group.name
            store.returnToLibrary()
        } label: {
            HStack(spacing:10) {
                Image(systemName:"folder").frame(width:20)
                Text(group.name).lineLimit(1)
                Spacer()
                Text("\(store.shelfBooks.filter { group.members[$0.id.uuidString]?.included == true }.count)").font(store.homeFont(11)).foregroundStyle(muted)
            }.font(store.homeFont(13)).padding(.horizontal,11).padding(.vertical,9).frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
        }.buttonStyle(LumaSidebarButtonStyle(isSelected:activeGroupID == group.id,accent:store.accent))
        .contextMenu {
            Button(L10n.text("重命名…")) { beginGroupEdit(group) }
            Button(L10n.text("删除分类"),role:.destructive) {
                store.removeGroup(group.id)
                if activeGroupID == group.id { activeGroupID = nil; collection = "全部图书" }
            }
        }
        let allowsReorder = categorySearch.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
        Group {
            if allowsReorder { row.onDrag { ShelfCategoryDrag.provider(group.id) } }
            else { row }
        }
        .background(dropGroupID == group.id ? store.accent.opacity(0.16):.clear,in:RoundedRectangle(cornerRadius:8))
        .overlay(alignment:dropCategoryAfter ? .bottom:.top) {
            if dropCategoryID == group.id { Rectangle().fill(store.accent).frame(height:2).padding(.horizontal,8).allowsHitTesting(false) }
        }
        .onDrop(of:[ShelfCategoryDrag.type,UTType.plainText.identifier],delegate:ShelfCategoryDrop(store:store,target:group.id,allowsReorder:allowsReorder,bookTarget:$dropGroupID,categoryTarget:$dropCategoryID,insertAfter:$dropCategoryAfter))
        .padding(.horizontal,10)
    }

    private func openStudy(mode:String,resume:Bool) {
        if studySession==nil {
            #if DEBUG
            studySession=LumaStudySession(storageDirectory:DebugReaderAcceptance.studyDirectory)
            #else
            studySession=LumaStudySession()
            #endif
        }
        let destination=resume ? studySession!.destination(for:mode):mode
        store.returnToLibrary();studyMode=destination;studyVisible=true
    }
    private func resumeReadingWorkspace() {
        guard let book=store.shelfBooks.first(where:{$0.id.uuidString==workspaceReadingBookID}) else{return}
        studyVisible=false;store.open(book)
    }

    private func studyRow(_ title:String, mode:String, symbol:String)->some View {
        Button {
            openStudy(mode:mode,resume:true)
        } label: {
            Label(title,systemImage:symbol).font(store.homeFont(13))
                .frame(maxWidth:.infinity,minHeight:44,alignment:.leading).padding(.horizontal,11)
        }.buttonStyle(LumaSidebarButtonStyle(isSelected:studyVisible && (studyMode == mode || (mode=="学习_听力" && studyMode.hasPrefix("学习_听力")) || (mode=="学习_写作_Task1题库" && (studyMode.contains("写作") || studyMode=="学习_草稿"))),accent:store.accent))
    }

    private func sideRow(_ title: String, symbol: String, count: Int?) -> some View {
        let isSelected = activeGroupID == nil && activeCloudFilter == nil && ((title == "阅读统计" && store.showStatistics) || (title != "阅读统计" && !store.showStatistics && collection == title))
        return Button {
            studyVisible = false
            activeCloudFilter = nil; activeGroupID = nil
            collection = title
            store.returnToLibrary(statistics: title == "阅读统计")
        } label: {
            HStack(spacing:10) {
                Image(systemName:symbol).frame(width:20)
                Text(L10n.text(title)).font(store.homeFont(13))
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(store.homeFont(11))
                        .monospacedDigit()
                        .foregroundStyle(muted)
                }
            }
            .padding(.horizontal,11)
            .padding(.vertical,9)
            .frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(LumaSidebarButtonStyle(isSelected: isSelected, accent: store.accent))
    }

    private func cloudSideRow(_ provider: CloudProvider) -> some View {
        let state = store.cloudStates[provider] ?? CloudDriveState(provider: provider)
        let isSelected = activeCloudFilter == provider && !store.showStatistics
        let count = state.syncedBookCount
        return Button {
            if state.isConnected {
                studyVisible = false
                activeCloudFilter = provider; activeGroupID = nil
                collection = provider.title
                store.returnToLibrary(statistics: false)
                store.syncCloud(provider)
            } else {
                store.connectCloud(provider)
            }
        } label: {
            HStack(spacing: 10) {
                CloudProviderIcon(provider:provider).foregroundStyle(store.accent).frame(width: 20)
                Text(L10n.text(provider.shortTitle)).font(store.homeFont(13)).lineLimit(1)
                Spacer()
                if state.isConnected {
                    Circle().fill(store.accent).frame(width: 6, height: 6)
                    if count > 0 {
                        Text("\(count)")
                            .font(store.homeFont(11))
                            .monospacedDigit()
                            .foregroundStyle(muted)
                    }
                } else {
                    Text(L10n.text("接入"))
                        .font(store.homeFont(10))
                        .foregroundStyle(muted)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(LumaSidebarButtonStyle(isSelected: isSelected, accent: store.accent))
        .help(L10n.text(state.lastSynced.map { "上次写入同步目录：" + $0.formatted(date:.abbreviated,time:.shortened) + "。云端传输状态请查看云盘客户端。" } ?? "连接云盘目录后同步全部图书、批注与书签"))
        .contextMenu {
            if state.isConnected {
                Button(L10n.text("立即同步 \(provider.title)")) { store.syncCloud(provider) }
                Button(L10n.text("更换同步目录…")) { store.connectCloud(provider) }
                Divider()
                Button(L10n.text("断开 \(provider.title)"), role: .destructive) {
                    if activeCloudFilter == provider { activeCloudFilter = nil; collection = "全部图书" }
                    store.disconnectCloud(provider)
                }
            } else {
                Button(L10n.text("接入 \(provider.title)…")) { store.connectCloud(provider) }
            }
        }
    }

    private var visibleBooks: [Book] {
        let result = store.filteredBooks.filter { book in
            if let group = activeGroupID { return store.collections.contains(book:book.id,in:group) }
            if let cloud = activeCloudFilter { return store.cloudStates[cloud]?.isConnected == true }
            if collection == "正在阅读" { return book.progress > 0 && !book.isFinished }
            if collection == "想读清单" { return book.shelf?.wantRead == true }
            if collection == "已读完" { return book.isFinished }
            if collection == "我的批注" { return !book.notes.isEmpty }
            return true
        }.sorted { a,b in
            if collection == "主页" { return a.lastOpened > b.lastOpened }
            if librarySort == "title" { return a.title.localizedStandardCompare(b.title) == .orderedAscending }
            if librarySort == "author" { return a.author.localizedStandardCompare(b.author) == .orderedAscending }
            return a.lastOpened > b.lastOpened
        }
        return collection == "主页" ? Array(result.prefix(12)):result
    }

    private var library: some View {
        let headingSize = round(30 * store.homeScale)
        return ScrollView {
            VStack(alignment:.leading,spacing:26) {
                HStack(alignment:.center, spacing: 14) {
                    Text(activeGroupID.flatMap { id in store.collections.active.first(where:{ $0.id == id })?.name } ?? L10n.text(collection))
                        .font(store.homeFont(30, weight: .medium))
                        .tracking(LumaFontFamily.opticalTracking(for: headingSize))

                    Spacer()

                    HStack(spacing:8) {
                        Image(systemName:"magnifyingglass").foregroundStyle(muted)
                        TextField(L10n.text("搜索书名或作者"),text:$store.search).textFieldStyle(.plain).focused($shelfSearchFocused)
                    }.font(store.homeFont(12)).padding(.horizontal,14).frame(width:210,height:40)
                        .readerGlass(radius:20,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
                }.padding(.top,26)

                if visibleBooks.isEmpty {
                    ContentUnavailableView(label: {
                        Label(L10n.text(store.shelfBooks.isEmpty ? "暂无图书" : "未找到匹配图书"), systemImage:"books.vertical")
                            .font(store.homeFont(16, weight: .medium))
                    }, actions: {
                        HStack(spacing: 10) {
                            Button(L10n.text("导入图书…")) { store.pickBooks(groupID:activeGroupID) }
                                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.96, cornerRadius: 8, horizontalPadding: 14, verticalPadding: 7, prominent: true, accent: store.accent))
                            if let cloud = activeCloudFilter {
                                Button(L10n.text("同步 \(cloud.title)")) { store.syncCloud(cloud) }
                                    .buttonStyle(LumaTactileButtonStyle(pressScale: 0.96, cornerRadius: 8, horizontalPadding: 12, verticalPadding: 7))
                            }
                        }
                    })
                    .frame(maxWidth:.infinity,minHeight:340)
                } else if libraryLayout == "list" {
                    LazyVStack(spacing:0) {
                        ForEach(visibleBooks) { book in
                            Button { openBook(book) } label: {
                                HStack(spacing:16) {
                                    Image(systemName:book.kind == "pdf" ? "doc.richtext":"book.closed").font(.system(size:24)).frame(width:40)
                                    VStack(alignment:.leading,spacing:5) {
                                        Text(book.title).font(store.homeFont(15,weight:.medium))
                                        Text(book.author).font(store.homeFont(12)).foregroundStyle(muted)
                                    }
                                    Spacer()
                                    Text("\(Int(book.progress*100))%").monospacedDigit().foregroundStyle(muted)
                                }.padding(.vertical,18).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            .contextMenu { classificationActions(for:book) }
                            .draggable("luma-book:"+book.id.uuidString)
                            Divider().opacity(0.3)
                        }
                    }
                } else {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:CGFloat(store.shelfCardWidth),maximum:CGFloat(store.shelfCardWidth)),spacing:28)],alignment:.leading,spacing:30) {
                        ForEach(visibleBooks) { book in
                            Button { openBook(book) } label: {
                                VStack(alignment:.leading,spacing:9) {
                                    ShelfCover(book:book,root:store.root,fontFamily:store.homeFontFamily,scale:store.homeScale,style:book.shelf?.coverStyle ?? store.shelfCoverStyle)
                                        .frame(width:CGFloat(store.shelfCardWidth),height:CGFloat(store.shelfCardWidth*1.45))
                                        .overlay(alignment:.bottomTrailing) {
                                            if coverOnlyShelf, hoveredBookID == book.id, book.progress > 0 {
                                                Text(L10n.text("已读 \(Int(book.progress*100))%"))
                                                    .font(store.homeFont(10)).monospacedDigit().padding(.horizontal,8).padding(.vertical,5)
                                                    .readerGlass(radius:9,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
                                                    .padding(8).allowsHitTesting(false).transition(.opacity)
                                            }
                                        }

                                    if !coverOnlyShelf {
                                    VStack(alignment:.leading,spacing:9) {
                                    Text(book.title)
                                        .font(store.homeFont(13, weight: .medium))
                                        .lineLimit(2)
                                        .frame(height: round(36 * store.homeScale), alignment: .topLeading)
                                    HStack(spacing: 5) {
                                        Text(book.author.isEmpty ? book.kind.uppercased() : book.author)
                                            .font(store.homeFont(11))
                                            .foregroundStyle(muted)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        if let provider = book.cloudProvider {
                                            CloudProviderIcon(provider:provider).foregroundStyle(store.accent)
                                                .font(.system(size: 10))
                                                .foregroundStyle(muted)
                                        }
                                    }
                                    if book.progress > 0 {
                                        ProgressView(value:book.progress).tint(store.accent)
                                        Text(L10n.text("已读 \(Int(book.progress*100))%"))
                                            .font(store.homeFont(10))
                                            .monospacedDigit()
                                            .foregroundStyle(muted)
                                    }
                                    }.padding(10).modifier(BookMonetFooter(book:book,root:store.root))
                                    }
                                }.contentShape(Rectangle())
                            }
                            .buttonStyle(LumaBookCardButtonStyle())
                            .onHover { inside in
                                withAnimation(reduceMotion || store.effectiveMotionLevel == .off ? nil:.easeOut(duration:0.12)) {
                                    if inside { hoveredBookID = book.id } else if hoveredBookID == book.id { hoveredBookID = nil }
                                }
                            }
                            .accessibilityLabel(Text(book.title+" "+book.author))
                            .accessibilityValue(Text(L10n.text(book.isFinished ? "已读完":book.progress > 0 ? "已读 \(Int(book.progress*100))%":"未读")))
                            .contextMenu { classificationActions(for:book) }
                            .draggable("luma-book:"+book.id.uuidString)
                            .overlay(alignment:.topTrailing) {
                                Menu { classificationActions(for:book) } label: { Image(systemName:"ellipsis.circle.fill").frame(width:36,height:36) }
                                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().padding(4).help(L10n.text("更多图书操作"))
                                    .opacity(!coverOnlyShelf || hoveredBookID == book.id ? 1:0)
                                    .allowsHitTesting(!coverOnlyShelf || hoveredBookID == book.id)
                                    .accessibilityHidden(coverOnlyShelf && hoveredBookID != book.id)
                            }
                            .help(book.title)
                        }
                    }
                }
            }.padding(.horizontal,42).padding(.bottom,40)
        }.background(store.paper(dark:colorScheme == .dark))
        .onDrop(of:[UTType.fileURL.identifier],isTargeted:$importDropTarget) { store.acceptFileDrop($0,groupID:activeGroupID) }
        .overlay { if importDropTarget { RoundedRectangle(cornerRadius:12).strokeBorder(store.accent,lineWidth:2).allowsHitTesting(false) } }
        .animation(LumaMotion.adjusted(SurfaceMotion.interactive,level:store.effectiveMotionLevel,reduceMotion:reduceMotion),value:libraryLayout)
        .animation(LumaMotion.adjusted(SurfaceMotion.interactive,level:store.effectiveMotionLevel,reduceMotion:reduceMotion),value:librarySort)
    }

    private var coverOnlyShelf:Bool {
        activeCloudFilter == nil && store.search.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && collection != "搜索"
    }

    private func openBook(_ book:Book) { store.open(book) }

    private func reading(_ book: Book) -> some View {
        VStack(spacing:0) {
            ZStack(alignment:.bottom) {
                ReaderSurface(book:book,store:store,controller:controller,undo:undo).id(book.id)
                if controller.hasSelection { selectionTools }

            }
            .overlay(alignment:.bottomLeading) {
                if controller.canReturnToReading {
                    Button { controller.returnToReadingPosition() } label: {
                        Image(systemName:"arrow.left").font(.system(size:13,weight:.medium)).frame(width:32,height:32).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(store.accent)
                    .readerGlass(radius:12,enabled:glassActive,tint:store.chrome(dark:colorScheme == .dark))
                    .help(L10n.text("返回跳转前的位置 · ⌥⌘←")).accessibilityLabel(L10n.text("返回跳转前的位置"))
                    .keyboardShortcut(.leftArrow,modifiers:[.command,.option])
                    .disabled(controller.isTurning || !controller.presentationReady)
                    .padding(8)
                    .opacity(readerChromeVisible ? 1:0).allowsHitTesting(readerChromeVisible)
                    .accessibilityHidden(!readerChromeVisible)
                }
            }
            .animation(LumaMotion.adjusted(SurfaceMotion.interactive,level:store.effectiveMotionLevel,reduceMotion:reduceMotion),value:controller.hasSelection)

            // Preserve the PDF viewport height; navigation is now a non-layout overlay.
            if book.kind == "pdf" && !store.immersive { Color.clear.frame(height:40).allowsHitTesting(false) }

        }
        .overlay(alignment:.top) {
            if !controller.bookmarkFeedback.isEmpty {
                Label(L10n.text(controller.bookmarkFeedback),systemImage:"checkmark.circle.fill")
                    .font(.system(size:13,weight:.medium)).padding(.horizontal,16).padding(.vertical,10)
                    .background(store.chrome(dark:colorScheme == .dark),in:Capsule()).padding(.top,18).allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(LumaMotion.adjusted(.easeOut(duration:0.15),level:store.effectiveMotionLevel,reduceMotion:reduceMotion),value:controller.bookmarkFeedback)
        .onAppear { store.activity.setReadingVisible(true) }
        .onDisappear { if store.selectedBook == nil { store.activity.setReadingVisible(false) }; store.flush() }
    }


    private var selectionTools:some View {
        LumaGlassCluster(enabled:glassActive) {
        ViewThatFits(in:.horizontal) {
            HStack(spacing:6) { inkSwatches; Divider().frame(height:26); selectionActions }
            VStack(spacing:4) { HStack(spacing:6) { inkSwatches }; HStack(spacing:6) { selectionActions } }
        }
        .padding(.horizontal,12).padding(.vertical,8)
        .readerGlass(radius:24,enabled:store.effectiveGlassEffectsEnabled && !reduceTransparency,tint:store.chrome(dark:colorScheme == .dark))
        .modifier(LumaGlassIdentity(id:"selection",namespace:chromeNamespace,enabled:glassActive))
        .padding(.horizontal,8).padding(.bottom,16)
        .transition(reduceMotion || store.effectiveMotionLevel == .off ? .opacity:.opacity.combined(with:.move(edge:.bottom)))
        }
    }
    @ViewBuilder private var inkSwatches:some View {
        ForEach(Ink.allCases) { ink in
            Button { controller.highlight(ink) } label: {
                Circle().fill(ink.color).frame(width:28,height:28)
                    .overlay(Circle().strokeBorder(.white.opacity(0.55),lineWidth:1).allowsHitTesting(false))
            }.buttonStyle(LumaSwatchButtonStyle(isSelected:store.activeInk == ink))
                .accessibilityLabel(L10n.text("用\(ink.title)高亮")).help(L10n.text(ink.title))
        }
    }
    @ViewBuilder private var selectionActions:some View {
        Button { controller.highlight(store.activeInk) } label: {
            Label(L10n.text("批注"),systemImage:"square.and.pencil").font(.system(size:13)).frame(minHeight:40)
        }.buttonStyle(LumaTactileButtonStyle()).help(L10n.text("添加标注和笔记"))
        Button { controller.askAI(selection:controller.selectedQuote) } label: { Image(systemName:"sparkles").font(.system(size:19)).foregroundStyle(store.accent).frame(width:40,height:40) }
            .buttonStyle(.borderless).help(L10n.text("问 AI")).accessibilityLabel(L10n.text("问 AI"))

    }

    private func notesInspector(_ book: Book) -> some View {
        VStack(alignment:.leading,spacing:0) {
            if book.notes.isEmpty {
                ContentUnavailableView(L10n.text("暂无批注"), systemImage:"highlighter")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment:.leading,spacing:12) {
                            ForEach(book.notes) { note in
                                noteCard(note,book:book).id(note.id)
                            }
                        }.padding(.horizontal,16).padding(.bottom,20)
                    }.onAppear { if let id = store.selectedNoteID { proxy.scrollTo(id,anchor:.center) } }
                    .onChange(of:store.selectedNoteID) { _,id in if let id { proxy.scrollTo(id,anchor:.center) } }
                }
            }
            Spacer(minLength:0)
        }.background(Color.clear)
    }

    private func noteCard(_ note: ReadingNote,book: Book) -> some View {
        let isSelected = store.selectedNoteID == note.id
        return VStack(alignment:.leading,spacing:11) {
            HStack(alignment:.top,spacing:10) {
                RoundedRectangle(cornerRadius:2).fill(Color(hex:note.highlightHex)).frame(width:3)
                Text(note.quote)
                    .font(store.homeFont(12))
                    .lineSpacing(4)
                    .lineLimit(8)
                    .frame(maxWidth:.infinity,alignment:.leading)
            }.fixedSize(horizontal:false,vertical:true)

            if isSelected {
                TextEditor(text:Binding(get:{ store.selectedBook?.notes.first{$0.id==note.id}?.note ?? "" },set:{ store.edit(note.id,in:book.id,text:$0) }))
                    .font(store.homeFont(12))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight:62)
                    .overlay(alignment:.topLeading) {
                        if note.note.isEmpty {
                            Text(L10n.text("添加笔记…"))
                                .font(store.homeFont(12))
                                .foregroundStyle(.tertiary)
                                .padding(.top,1)
                                .padding(.leading,4)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(L10n.text("批注笔记"))

                HStack(spacing:8) {
                    ForEach(Ink.allCases) { ink in
                        Button { store.edit(note.id,in:book.id,ink:ink) } label: {
                            Circle().fill(ink.color).frame(width:15,height:15)
                                .padding(3)
                                .overlay(Circle().stroke(note.ink==ink ? Color.primary.opacity(0.55) : .clear,lineWidth:1))
                        }
                        .buttonStyle(LumaSwatchButtonStyle(isSelected: note.ink == ink))
                        .accessibilityLabel(ink.title)
                    }
                }
            } else if !note.note.isEmpty {
                Text(note.note)
                    .font(store.homeFont(12))
                    .foregroundStyle(muted)
                    .lineLimit(4)
            }

            HStack(spacing: 6) {
                Text(L10n.text(note.rects.first.map { "第 \($0.page+1) 页" } ?? "第 \(note.chapter+1) 节"))
                    .font(store.homeFont(10))
                    .monospacedDigit()
                    .foregroundStyle(muted)
                Spacer()
                Button {
                    store.selectedNoteID = note.id
                    controller.jump(to:note)
                } label: { Image(systemName:"arrow.up.left") }
                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.92, cornerRadius: 6, horizontalPadding: 6, verticalPadding: 4))
                .help(L10n.text("定位原文"))

                Button { store.remove(note.id,from:book.id,undo:undo) } label: { Image(systemName:"trash") }
                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.92, cornerRadius: 6, horizontalPadding: 6, verticalPadding: 4))
                .help(L10n.text("删除 · ⌘Z"))
            }.font(store.homeFont(11)).foregroundStyle(muted)
        }
        .padding(14)
        .background(store.chrome(dark:colorScheme == .dark).opacity(glassActive ? 0.7:1),in:RoundedRectangle(cornerRadius:12, style:.continuous))
        .overlay(RoundedRectangle(cornerRadius:12, style: .continuous).strokeBorder(isSelected ? Color(hex:note.highlightHex).opacity(0.6) : Color.primary.opacity(0.05),lineWidth:1))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            store.selectedNoteID = note.id
            controller.jump(to:note)
        }
    }
}

struct BookCover: View {
    let book: Book
    var fontFamily: LumaFontFamily = .serif
    var scale: CGFloat = 1.0
    var tint: Color? = nil
    private var hue: Double { Double(book.id.uuid.0) / 255 }
    var body: some View {
        let titleSize = round(22 * scale)
        ZStack(alignment:.topLeading) {
            RoundedRectangle(cornerRadius:6, style: .continuous)
                .fill((tint ?? Color(hue:hue,saturation:0.17,brightness:0.72)).gradient)
            Circle().fill(.white.opacity(0.11)).frame(width:150).offset(x:70,y:95)
            Circle().stroke(.white.opacity(0.16),lineWidth:1).frame(width:180).offset(x:-50,y:120)
            Rectangle().fill(.black.opacity(0.12)).frame(width:5).padding(.leading,5)
            VStack(alignment:.leading,spacing:11) {
                Text(book.author.isEmpty ? "LUMA" : book.author.uppercased())
                    .font(fontFamily.font(size: round(9 * scale), weight: .medium))
                    .tracking(1.4)
                    .lineLimit(2)
                Text(book.title)
                    .font(fontFamily.font(size: titleSize, weight: .medium))
                    .tracking(LumaFontFamily.opticalTracking(for: titleSize))
                    .lineSpacing(3)
                    .lineLimit(5)
                Spacer()
                Image(systemName:"book.closed").font(.system(size:18,weight:.ultraLight))
            }.foregroundStyle(.white.opacity(0.92)).padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius:6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.32), .clear, .black.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color:.black.opacity(0.13),radius:11,x:0,y:6)
    }
}

struct ReaderSettings: View {
    @Environment(\.lumaMuted) private var muted
    @Environment(\.colorScheme) private var colorScheme
    var previewPDF:()->Void = {}
    @State private var showAPI = false
    @State private var settingsCategory = "阅读"
    @State private var showCustomizationFromSettings = false
    @Bindable var store: LibraryStore
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    private func close() { if let onClose { onClose() } else { dismiss() } }
    var body: some View {
        Form {
            Picker(L10n.text("设置类别"),selection:$settingsCategory) {
                ForEach(["阅读","外观","书库与管理","AI 与辅助","通用","高级"],id:\.self) { Text(L10n.text($0)).tag($0) }
            }.pickerStyle(.menu)
            if settingsCategory == "AI 与辅助" {
            Section(L10n.text("AI 助手")) {
                Button(L10n.text("设置 API")) { showAPI = true }.popover(isPresented:$showAPI,arrowEdge:.top) { AISettingsPanel(ai:store.ai,paper:store.paper(dark:colorScheme == .dark),accent:store.accent) }
                Button { store.askAI(); openWindow(id:"main"); close() } label: { Image(systemName:"sparkles").foregroundStyle(store.accent) }.help(L10n.text("阅读助手")).accessibilityLabel(L10n.text("阅读助手"))
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            }
            if settingsCategory == "外观" {
            Section(L10n.text("外观与主题")) {
                Button(L10n.text("莫奈与液态玻璃…")) { showCustomizationFromSettings = true }
                Picker(L10n.text("配色"),selection:$store.theme) {
                    ForEach(ReaderTheme.allCases) { theme in Label(L10n.text(theme.title),systemImage:"circle.fill").foregroundStyle(theme.accent).tag(theme) }
                }
                Picker(L10n.text("模式"),selection:$store.appearance) {
                    ForEach(Appearance.allCases,id:\.self) { Text(L10n.text($0.rawValue)).tag($0) }
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            Section(L10n.text("主页字体")) {
                Picker(L10n.text("字体样式"), selection: $store.homeFontFamily) {
                    ForEach(LumaFontFamily.allCases) { family in
                        Text(L10n.text(family.title)).tag(family)
                    }
                }
                LabeledContent(L10n.text("主页字号")) {
                    Slider(value: $store.homeFontSize, in: 12...18, step: 1)
                    Text("\(Int(store.homeFontSize)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            }
            if settingsCategory == "阅读" {
            Section(L10n.text("正文阅读")) {
                if store.selectedBook?.kind == "pdf" { Button(L10n.text("预览当前 PDF 页"),action:previewPDF) }
                PageMotionPicker(store:store)
                Toggle(L10n.text("翻页动画"),isOn:$store.pageTurnAnimation)
                Picker(L10n.text("翻页方式"),selection:$store.pageTurnStyle) {
                    ForEach(PageTurnStyle.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                Toggle(L10n.text("沉浸阅读"),isOn:Binding(get:{ store.immersive },set:{ value in if value != store.immersive { store.toggleImmersive() } }))
                    .disabled(store.selectedBook == nil)
                Picker(L10n.text("EPUB 字体"), selection: $store.readerFontFamily) {
                    ForEach(LumaFontFamily.allCases) { family in
                        Text(L10n.text(family.title)).tag(family)
                    }
                }
                LabeledContent(L10n.text("EPUB 字号")) {
                    Slider(value:$store.readerSize,in:15...30,step:1)
                    Text("\(Int(store.readerSize)) pt").monospacedDigit().frame(width:40, alignment: .trailing)
                }
                LabeledContent(L10n.text("EPUB 版心")) {
                    Slider(value:$store.readerWidth,in:480...900,step:20)
                    Text("\(Int(store.readerWidth))").monospacedDigit().frame(width:40, alignment: .trailing)
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            }
            if settingsCategory == "书库与管理" {
            ShelfSettings(store:store)
            if store.selectedBook != nil {
                Section(L10n.text("导出")) {
                    Button(L10n.text("导出批注…")) { store.exportNotes() }
                    if store.selectedBook?.kind == "pdf" { Button(L10n.text("导出含高亮 PDF…")) { store.reader?.exportPDF() } }
                }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            }
            Section(L10n.text("云端同步")) {
                LabeledContent(L10n.text("字体资源")) { Text(L10n.text("\(store.importedFonts.count) 款已导入字体")).font(.caption) }
                LabeledContent(L10n.text("同步范围")) {
                    Text(L10n.text("\(store.shelfBooks.count) 本书 · \(store.shelfBooks.reduce(0) { $0 + $1.notes.count }) 处批注 · \(store.shelfBooks.reduce(0) { $0 + ($1.bookmarks?.count ?? 0) }) 个书签"))
                        .font(.caption).monospacedDigit()
                }
                Text(L10n.text("保存 Luma 内的高亮、文字笔记、书签及阅读进度。请让各设备连接同一同步目录，并等待云盘客户端完成上传和下载。"))
                    .font(.caption).foregroundStyle(muted)
                Text(L10n.text("其他阅读器的私有批注不会自动导入。这里的成功状态表示已写入同步目录，不代表云端传输已经完成。"))
                    .font(.caption).foregroundStyle(muted)
                Button(L10n.text("同步全部")) { store.syncAllConnectedClouds() }.disabled(store.isSyncingCloud)
                ForEach(CloudProvider.allCases) { provider in
                    let state = store.cloudStates[provider] ?? CloudDriveState(provider: provider)
                    HStack(spacing: 10) {
                        Label { Text(L10n.text(provider.title)) } icon: { CloudProviderIcon(provider:provider).foregroundStyle(store.accent) }
                        Spacer()
                        if state.isConnected {
                            Text(L10n.text(state.lastSynced.map { "已写入目录 · " + $0.formatted(date:.abbreviated,time:.shortened) } ?? "尚未写入同步目录"))
                                .font(.caption)
                                .foregroundStyle(muted)
                                .lineLimit(1)
                            Button(L10n.text("同步")) { store.syncCloud(provider) }
                                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.95, cornerRadius: 6, horizontalPadding: 8, verticalPadding: 4))
                            Button(L10n.text("目录…")) { store.connectCloud(provider) }
                                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.95, cornerRadius: 6, horizontalPadding: 8, verticalPadding: 4))
                            Button(L10n.text("断开")) { store.disconnectCloud(provider) }
                                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.95, cornerRadius: 6, horizontalPadding: 8, verticalPadding: 4))
                                .foregroundStyle(muted)
                        } else {
                            Button(L10n.text("接入…")) { store.connectCloud(provider) }
                                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.95, cornerRadius: 6, horizontalPadding: 10, verticalPadding: 4, prominent: true, accent: store.accent))
                        }
                    }
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            }
            if settingsCategory == "通用" {
            Section(L10n.text("界面语言")) {
                Picker(L10n.text("界面语言"),selection:Binding(get:{ AppLanguage.shared.choice },set:{ AppLanguage.shared.choice = $0 })) {
                    Text(L10n.text("跟随系统")).tag("system"); Text(L10n.text("简体中文")).tag("zh-Hans"); Text("English").tag("en")
                }
            }
            Section(L10n.text("节能与计时")) {
                Toggle(L10n.text("省电模式"),isOn:$store.energySaving)
                Button(L10n.text("自定义动画与玻璃效果…")) { showCustomizationFromSettings = true }
                Stepper(L10n.text("空闲 \(store.activity.idleMinutes) 分钟暂停计时"),value:Binding(get:{ store.activity.idleMinutes },set:{ store.activity.idleMinutes = $0 }),in:1...30)
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            }
            if settingsCategory == "高级" {
                Section(L10n.text("开发者与诊断")) { DiagnosticsSettingsView() }
                    .listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            }
            Section {
                Button(L10n.text("完成")) { close() }
                    .buttonStyle(LumaTactileButtonStyle(pressScale: 0.96, cornerRadius: 8, horizontalPadding: 16, verticalPadding: 6, prominent: true, accent: store.accent))
                    .frame(maxWidth:.infinity,alignment:.trailing)
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
        }
        .formStyle(.grouped).scrollContentBackground(.hidden)
        .popover(isPresented:$showCustomizationFromSettings,arrowEdge:.top) {
            CustomizationPanel(store:store).frame(width:780,height:640).lumaSurface(radius:16)
        }
        .background(Color.clear)
        .tint(store.accent).accentColor(store.accent).toggleStyle(LumaThemeSwitchStyle(accent:store.accent))
        .onChange(of:store.theme) { _,_ in store.reader?.updateSettings() }
        .onChange(of:store.appearance) { _,_ in store.reader?.updateSettings() }
        .onChange(of:store.readerFontFamily) { _,_ in store.reader?.updateSettings() }
        .onChange(of:store.readerSize) { _,_ in store.reader?.updateSettings() }
        .onChange(of:store.readerWidth) { _,_ in store.reader?.updateSettings() }
    }
}

extension View {
    func readerGlass(radius:CGFloat,enabled:Bool,tint:Color) -> some View {
        modifier(ReaderGlassSurface(radius:radius,enabled:enabled,backing:tint))
    }
}

private struct ReaderWindowChrome: NSViewRepresentable {
    let color: NSColor
    var controlsVisible:Bool
    var animateControls:Bool
    var onSafeInset:(CGFloat)->Void
    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ view: ChromeView, context: Context) { view.color = color; view.controlsVisible = controlsVisible; view.animateControls = animateControls; view.onSafeInset = onSafeInset; view.apply() }
    final class ChromeView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        var animateControls = false
        var controlsVisible = true
        var onSafeInset:(CGFloat)->Void = { _ in }
        var color = NSColor.windowBackgroundColor
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            guard let window else { return }
            NativeWindowControls.restore(window,controlsVisible:controlsVisible,animated:animateControls)
            if let content = window.contentView {
                let maxX = [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton].compactMap { window.standardWindowButton($0) }.map { $0.convert($0.bounds,to:content).maxX }.max() ?? 78
                let inset = max(90,maxX+16)
                DispatchQueue.main.async { [weak self] in self?.onSafeInset(inset) }
            }
            // Do not reassign styleMask on every SwiftUI update; that rebuilds native window chrome.
            if !window.styleMask.contains(.fullSizeContentView) { window.styleMask.insert(.fullSizeContentView) }
            if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
            if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
            if window.titlebarSeparatorStyle != .none { window.titlebarSeparatorStyle = .none }
            if window.backgroundColor != color { window.backgroundColor = color }
            window.isMovableByWindowBackground = false
            if window.toolbarStyle != .unifiedCompact { window.toolbarStyle = .unifiedCompact }
            window.toolbar?.showsBaselineSeparator = false
            WindowControlsProbe.startIfRequested(window)
        }
    }
}


private struct BookSearchPanel: View {
    @Bindable var controller:ReaderController
    @Binding var query:String
    var accent:Color = .accentColor
    var paper:Color = Color(nsColor:.windowBackgroundColor)
    var onSelect:()->Void = {}
    @FocusState private var focused:Bool
    private var trimmed:String { query.trimmingCharacters(in:.whitespacesAndNewlines) }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text(L10n.text("在此书中搜索")).font(.system(size:12,weight:.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action:onSelect) { Image(systemName:"xmark").frame(width:30,height:30) }
                    .buttonStyle(.plain).accessibilityLabel(L10n.text("关闭搜索"))
            }
            HStack {
                Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                TextField(L10n.text("在此书中"),text:$query).textFieldStyle(.plain).focused($focused)
                    .onSubmit { controller.rememberSearch(query) }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName:"xmark.circle.fill").frame(width:36,height:36) }
                        .buttonStyle(.borderless).help(L10n.text("清空搜索"))
                }
            }.padding(.horizontal,12).frame(height:48).background(accent.opacity(0.08),in:Capsule())
            VStack(alignment:.leading,spacing:12) { searchContent }.frame(height:384,alignment:.top)
        }.padding(16).frame(width:380)
        .modifier(LumaPanelEntrance(anchor:.topTrailing))
        .onAppear { focused = true; if !trimmed.isEmpty && controller.searchResults.isEmpty && !controller.isSearching { controller.searchBook(query) } }
        .onChange(of:query) { _,value in controller.searchBook(value) }
        .onDisappear { controller.rememberSearch(query) }
    }
    @ViewBuilder private var searchContent:some View {
        if trimmed.isEmpty {
            if controller.recentSearches.isEmpty { Text(L10n.text("输入关键字搜索整本书")).foregroundStyle(.secondary).frame(height:72) }
            else {
                HStack { Text(L10n.text("最近搜索")).foregroundStyle(.secondary); Spacer(); Button(L10n.text("清除")) { controller.clearRecentSearches() }.buttonStyle(.borderless) }.font(.caption)
                ScrollView {
                    VStack(alignment:.leading,spacing:4) {
                        ForEach(controller.recentSearches,id:\.self) { value in
                            Button { query = value; controller.rememberSearch(value) } label: { Label(value,systemImage:"clock").frame(maxWidth:.infinity,minHeight:38,alignment:.leading).contentShape(Rectangle()) }.buttonStyle(.plain)
                        }
                    }
                }.frame(height:min(240,CGFloat(controller.recentSearches.count)*42))
            }
        } else if controller.isSearching {
            HStack { ProgressView().controlSize(.small); Text(L10n.text("正在搜索…")).foregroundStyle(.secondary) }.frame(height:72)
        } else if let error = controller.searchError {
            Text(L10n.text(error)).foregroundStyle(.secondary).frame(minHeight:72)
        } else if controller.searchResults.isEmpty {
            Text(L10n.text("没有找到“\(trimmed)”")).foregroundStyle(.secondary).frame(height:100)
        } else {
            Text(L10n.text(controller.searchResults.count >= 1000 ? "前 1000 项结果":"\(controller.searchResults.count) 项结果")).font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment:.leading,spacing:0) {
                    ForEach(Array(controller.searchResults.enumerated()),id:\.element.id) { index,hit in
                        Button { controller.jump(to:hit); onSelect() } label: {
                            VStack(alignment:.leading,spacing:6) {
                                Text(hit.title).font(.system(size:12,weight:.semibold)).lineLimit(1)
                                Text(snippet(hit.snippet)).font(.system(size:13)).lineLimit(3).multilineTextAlignment(.leading)
                            }.frame(maxWidth:.infinity,minHeight:64,alignment:.leading).padding(.vertical,10).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(controller.isTurning)
                        .modifier(LumaResultEntrance(index:index))
                        Divider()
                    }
                }
            }.frame(height:360).scrollIndicators(.visible)
        }
    }
    private func snippet(_ value:String) -> AttributedString {
        var text = AttributedString(value)
        if let range = text.range(of:trimmed,options:.caseInsensitive) { text[range].backgroundColor = accent.opacity(0.22) }
        return text
    }
}


private struct ShelfCover: View {
    let book: Book
    let root: URL
    let fontFamily: LumaFontFamily
    let scale: CGFloat
    var style = "monet"
    @State private var image: NSImage?
    @State private var palette: MonetPalettePair?
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Group {
            if style == "original", let image { Image(nsImage:image).resizable().aspectRatio(contentMode:.fit).shadow(color:.black.opacity(0.15),radius:9,y:5) }
            else { BookCover(book:book,fontFamily:fontFamily,scale:scale,tint:scheme == .dark ? palette?.dark.accent:palette?.light.accent) }
        }.task(id:book.coverFilename) {
            guard let filename = book.coverFilename else { image = nil; return }
            let url = root.appendingPathComponent("Covers").appendingPathComponent(filename)
            let data = await Task.detached(priority:.utility) { try? Data(contentsOf:url) }.value
            guard !Task.isCancelled else { return }
            image = data.flatMap { NSImage(data:$0) }
            if let seed = await CoverColorExtractor.shared.seed(from:url,cacheURL:root.appendingPathComponent("cover-monet-cache.json")), !Task.isCancelled {
                let value = await Task.detached(priority:.utility) { MonetPalettePair.make(seed:seed,style:.tonalSpot) }.value
                if !Task.isCancelled { palette = value }
            }
        }
    }
}
