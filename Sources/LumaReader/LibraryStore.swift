import Observation
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import ImageIO

@MainActor @Observable
final class LibraryStore {
    var books: [Book] = []
    var collections = LibraryGroups()
    var selectedID: UUID? { didSet { if selectedID != oldValue { aiPanelVisible = false; aiPanelExpanded = false } } }
    var selectedNoteID: UUID?
    var pageMotionMode = UserDefaults.standard.string(forKey:"pageMotionMode") ?? "original" { didSet { UserDefaults.standard.set(pageMotionMode,forKey:"pageMotionMode") } }
    var shelfCoverStyle = UserDefaults.standard.string(forKey:"shelfCoverStyle") ?? "monet" { didSet { UserDefaults.standard.set(shelfCoverStyle,forKey:"shelfCoverStyle") } }
    var shelfCardWidth = UserDefaults.standard.object(forKey:"shelfCardWidth") as? Double ?? 165 { didSet { UserDefaults.standard.set(shelfCardWidth,forKey:"shelfCardWidth") } }
    var search = ""
    var showStatistics = false
    var error: String?
    var isImporting = false
    var isSyncingCloud = false
    var showInspector = true { didSet { UserDefaults.standard.set(showInspector, forKey: "showInspector") } }
    var aiPanelWidth:Double = 340
    var aiPanelPinned = false
    var aiPanelExpanded = false
    var glassOpacity = min(0.85,max(0.05,UserDefaults.standard.object(forKey:"glassOpacity") as? Double ?? 0.32)) {
        didSet { UserDefaults.standard.set(glassOpacity,forKey:"glassOpacity") }
    }
    var aiPanelVisible = false { didSet {
        if aiPanelVisible != oldValue {
            DiagnosticManager.shared.aiVisibility(aiPanelVisible)
            if aiPanelVisible { aiPanelWidth = 340; aiPanelExpanded = false }
            reader?.beginViewportChange()
            if !aiPanelVisible { reader?.focusReadingSurface() }
        }
    } }
    @ObservationIgnored var readingPreferencesArchive: BookReadingPreferencesArchive?
    @ObservationIgnored var readingPreferencesSaveTask: Task<Void,Never>?
    @ObservationIgnored var applyingReadingPreferences = false
    @ObservationIgnored var readingPreferencesDirty = false
    @ObservationIgnored var readingPreferencesWritable = true
    var perBookReadingSettings = UserDefaults.standard.object(forKey:"perBookReadingSettings") as? Bool ?? true {
        didSet { UserDefaults.standard.set(perBookReadingSettings,forKey:"perBookReadingSettings"); restoreReadingPreferences(for:selectedID) }
    }
    var immersive = false
    private var inspectorBeforeImmersion = true
    private var aiBeforeImmersion = false
    private var restoreAIOnExit = false
    var autoHideAIInFocus = UserDefaults.standard.object(forKey:"autoHideAIInFocus") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoHideAIInFocus,forKey:"autoHideAIInFocus") }
    }
    var readerLineHeight = UserDefaults.standard.object(forKey:"readerLineHeight") as? Double ?? 1.75 {
        didSet { UserDefaults.standard.set(readerLineHeight,forKey:"readerLineHeight"); readingPreferencesDidChange(); updateReadingSettingsIfReady() }
    }
    var readerParagraphSpacing = UserDefaults.standard.object(forKey:"readerParagraphSpacing") as? Double ?? 1.35 {
        didSet { UserDefaults.standard.set(readerParagraphSpacing,forKey:"readerParagraphSpacing"); readingPreferencesDidChange(); updateReadingSettingsIfReady() }
    }
    var readerIndent = UserDefaults.standard.object(forKey:"readerIndent") as? Bool ?? false {
        didSet { UserDefaults.standard.set(readerIndent,forKey:"readerIndent"); readingPreferencesDidChange(); updateReadingSettingsIfReady() }
    }
    var monetEnabled = UserDefaults.standard.object(forKey:"monetEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(monetEnabled,forKey:"monetEnabled"); readingPreferencesDidChange(); refreshMonet(); updateReadingSettingsIfReady() }
    }
    var monetSource = MonetSource(rawValue:UserDefaults.standard.string(forKey:"monetSource") ?? "cover") ?? .cover {
        didSet { UserDefaults.standard.set(monetSource.rawValue,forKey:"monetSource"); readingPreferencesDidChange(); refreshMonet(force:true) }
    }
    var monetStyle = MonetStyle(rawValue:UserDefaults.standard.string(forKey:"monetStyle") ?? "tonalSpot") ?? .tonalSpot {
        didSet { UserDefaults.standard.set(monetStyle.rawValue,forKey:"monetStyle"); readingPreferencesDidChange(); rebuildMonet() }
    }
    var monetLocked = UserDefaults.standard.bool(forKey:"monetLocked") {
        didSet { UserDefaults.standard.set(monetLocked,forKey:"monetLocked"); readingPreferencesDidChange(); if monetLocked { monetTask?.cancel(); monetStatus = "已锁定当前配色" } else { refreshMonet() } }
    }
    var monetSeed = UserDefaults.standard.object(forKey:"monetSeed") as? Int ?? 0xFF8C7862 {
        didSet { UserDefaults.standard.set(monetSeed,forKey:"monetSeed"); readingPreferencesDidChange(); rebuildMonet() }
    }
    var monetStatus = ""
    private(set) var monetPalette = MonetPalettePair.make(seed:0xFF8C7862,style:.tonalSpot)
    @ObservationIgnored private var monetTask: Task<Void,Never>?

    var isDarkAppearance: Bool {
        (!monetEnabled && theme.forcesDark) || appearance == .dark ||
        (appearance == .system && NSApp.effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua)
    }
    func readingPalette(dark: Bool) -> ReadingPalette {
        monetEnabled ? (dark ? monetPalette.dark:monetPalette.light):.classic(theme,dark:dark)
    }
    var accent: Color { readingPalette(dark:isDarkAppearance).accent }
    func paper(dark: Bool) -> Color { readingPalette(dark:dark).paper }
    func chrome(dark: Bool) -> Color { readingPalette(dark:dark).chrome }
    func refreshResolvedReadingTheme() { rebuildMonet(); refreshMonet(); updateReadingSettingsIfReady() }
    func updateReadingSettingsIfReady() { if !applyingReadingPreferences { reader?.updateSettings() } }
    private func rebuildMonet() {
        guard !applyingReadingPreferences else { return }
        monetPalette = .make(seed:monetSeed,style:monetStyle)
        updateReadingSettingsIfReady()
    }
    func setMonetHex(_ text: String) -> Bool {
        let hex = text.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"#",with:"")
        guard hex.count == 6, let value = Int(hex,radix:16) else { return false }
        monetSource = .manual; monetSeed = 0xFF000000 | value
        return true
    }
    func chooseMonetImage() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf:url)
            let directory = root.appendingPathComponent("ThemeImages",isDirectory:true)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let name = perBookReadingSettings ? selectedID?.uuidString ?? "default":"default"
            try data.write(to:directory.appendingPathComponent(name),options:.atomic)
            monetSource = .image; refreshMonet(force:true)
        } catch { monetStatus = "图片未能读取：" + error.localizedDescription }
    }
    func refreshMonet(force: Bool = false) {
        monetTask?.cancel()
        guard !applyingReadingPreferences else { return }
        guard monetEnabled, force || !monetLocked else { return }
        guard monetSource != .manual else { monetStatus = "使用手动主色"; return }
        let bookID = selectedID
        let source = monetSource
        let url: URL?
        switch source {
        case .cover: url = selectedBook?.coverFilename.map { root.appendingPathComponent("Covers").appendingPathComponent($0) }
        case .image:
            let name = perBookReadingSettings ? selectedID?.uuidString ?? "default":"default"
            let candidate = root.appendingPathComponent("ThemeImages").appendingPathComponent(name)
            let shared = root.appendingPathComponent("ThemeImages/default")
            url = FileManager.default.fileExists(atPath:candidate.path) ? candidate:(FileManager.default.fileExists(atPath:shared.path) ? shared:root.appendingPathComponent("theme-image"))
        case .wallpaper: url = NSScreen.main.flatMap { NSWorkspace.shared.desktopImageURL(for:$0) }
        case .manual: url = nil
        }
        guard let url else { monetStatus = "没有可读取的封面，保留当前配色"; return }
        monetStatus = "正在提取颜色…"
        let cacheURL = root.appendingPathComponent("monet-seeds.json")
        monetTask = Task { [weak self] in
            let seed = await CoverColorExtractor.shared.seed(from:url,cacheURL:cacheURL)
            guard !Task.isCancelled, let self, self.monetEnabled,
                  self.monetSource == source, source != .cover || self.selectedID == bookID else { return }
            if let seed { self.monetSeed = seed; self.monetStatus = "已从" + source.title + "取色" }
            else { self.monetStatus = "无法读取图片，保留当前配色" }
        }
    }
    var theme: ReaderTheme = .paper { didSet { savePreferences() } }
    var pageTurnAnimation = UserDefaults.standard.object(forKey:"pageTurnAnimation") as? Bool ?? true { didSet { UserDefaults.standard.set(pageTurnAnimation,forKey:"pageTurnAnimation"); readingPreferencesDidChange() } }
    var pageTurnStyle: PageTurnStyle = .natural { didSet { savePreferences() } }
    var coverTransitions = true { didSet { savePreferences() } }
    var energySaving = false { didSet { savePreferences() } }
    var glassEffectsEnabled = true { didSet { savePreferences() } }
    var visualMotionLevel: VisualMotionLevel = .enhanced { didSet { savePreferences() } }
    var systemReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    var systemReduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    var systemLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var effectiveEnergySaving: Bool { energySaving || systemLowPower }
    var effectiveMotionLevel: VisualMotionLevel {
        VisualEffectsPolicy.effectiveMotion(requested:visualMotionLevel,energySaving:energySaving,
                                            systemLowPower:systemLowPower,reduceMotion:systemReduceMotion)
    }
    var effectiveGlassEffectsEnabled: Bool {
        VisualEffectsPolicy.glassEnabled(requested:glassEffectsEnabled,energySaving:energySaving,
                                         systemLowPower:systemLowPower,reduceTransparency:systemReduceTransparency)
    }
    var preferredColorScheme: ColorScheme? { !monetEnabled && theme.forcesDark ? .dark : appearance.colorScheme }
    var activeInk: Ink = .yellow
    var appearance: Appearance = .system { didSet { savePreferences() } }

    // Home page & reader typography settings
    var homeFontFamily: LumaFontFamily = .serif { didSet { savePreferences() } }
    var homeFontSize: Double = 14.0 { didSet { savePreferences() } }
    var importedFonts:[ImportedFont] = []
    var isImportingFonts = false
    var readerCustomFont = UserDefaults.standard.string(forKey:"readerCustomFont") ?? "" {
        didSet { UserDefaults.standard.set(readerCustomFont,forKey:"readerCustomFont"); readingPreferencesDidChange(); updateReadingSettingsIfReady() }
    }
    var homeCustomFont = UserDefaults.standard.string(forKey:"homeCustomFont") ?? "" {
        didSet { UserDefaults.standard.set(homeCustomFont,forKey:"homeCustomFont") }
    }
    var readerFontFamily: LumaFontFamily = .serif { didSet { savePreferences() } }
    var readerSize = 19.0 { didSet { savePreferences(); updateReadingSettingsIfReady() } }
    var readerWidth = 680.0 { didSet { savePreferences(); updateReadingSettingsIfReady() } }

    // Cloud drive states for iCloud Drive, OneDrive, and Google Drive
    var cloudStates: [CloudProvider: CloudDriveState] = [
        .iCloud: CloudDriveState(provider: .iCloud),
        .oneDrive: CloudDriveState(provider: .oneDrive),
        .googleDrive: CloudDriveState(provider: .googleDrive)
    ]

    let ai = AIChatStore()
    var reader: ReaderController?
    let root: URL
    let activity: ReadingActivityStore
    private var persistenceReady = false
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var cloudSaveTask: Task<Void, Never>?
    @ObservationIgnored private var syncRequested = false
    @ObservationIgnored private var generatingCovers = false
    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var lastWrittenCollections: Data?
    @ObservationIgnored private var lastWrittenData: Data?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    var selectedBook: Book? { books.first { $0.id == selectedID } }
    var filteredBooks: [Book] {
        shelfBooks.filter { search.isEmpty || ($0.title + $0.author).localizedCaseInsensitiveContains(search) }
            .sorted { $0.lastOpened > $1.lastOpened }
    }

    var homeScale: CGFloat {
        CGFloat(min(18.0, max(12.0, homeFontSize)) / 14.0)
    }

    func homeFont(_ baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil) -> Font {
        let scaled = round(baseSize * homeScale * 2) / 2
        if let font = importedFonts.first(where:{ $0.id == homeCustomFont }) {
            return .custom(font.postScriptName,size:scaled).weight(weight)
        }
        return .system(size: scaled, weight: weight, design: design ?? homeFontFamily.design)
    }

    func adjustHomeFontSize(by delta: Double) {
        homeFontSize = min(18.0, max(12.0, homeFontSize + delta))
    }

    func resetHomeTypography() {
        homeFontFamily = .serif; homeCustomFont = ""
        homeFontSize = 14.0
    }

    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LumaReader", isDirectory: true)
        activity = ReadingActivityStore(root:root)
        do {
            try FileManager.default.createDirectory(at: root.appendingPathComponent("Books"), withIntermediateDirectories: true)
            let file = root.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: file.path) {
                books = try JSONDecoder().decode([Book].self, from: Data(contentsOf: file))
            }
            let groupsFile = root.appendingPathComponent("collections.json")
            if FileManager.default.fileExists(atPath:groupsFile.path) {
                let data = try Data(contentsOf:groupsFile)
                collections = try JSONDecoder().decode(LibraryGroups.self,from:data)
                lastWrittenCollections = data
            }
            persistenceReady = true
            let prefs = UserDefaults.standard
            let loadedTheme = ReaderTheme(rawValue: prefs.string(forKey:"theme") ?? "paper") ?? .paper
            let loadedAppearance = Appearance(rawValue: prefs.string(forKey:"appearance") ?? "跟随系统") ?? .system
            let loadedEnergy = prefs.object(forKey:"energySaving") as? Bool ?? false
            let loadedGlass = prefs.object(forKey:"glassEffectsEnabled") as? Bool ?? true
            let loadedMotion = VisualMotionLevel(rawValue:prefs.string(forKey:"visualMotionLevel") ?? "enhanced") ?? .enhanced
            let loadedTurn = PageTurnStyle(rawValue:prefs.string(forKey:"pageTurnStyle") ?? "natural") ?? .natural
            let loadedCover = prefs.object(forKey:"coverTransitions") as? Bool ?? true
            showInspector = prefs.object(forKey:"showInspector") as? Bool ?? true
            let loadedHomeFont = LumaFontFamily(rawValue: prefs.string(forKey:"homeFontFamily") ?? "serif") ?? .serif
            let loadedHomeSize = min(18.0, max(12.0, prefs.object(forKey:"homeFontSize") as? Double ?? 14.0))
            let loadedReaderFont = LumaFontFamily(rawValue: prefs.string(forKey:"readerFontFamily") ?? "serif") ?? .serif
            let loadedSize = prefs.object(forKey:"readerSize") as? Double ?? 19
            let loadedWidth = prefs.object(forKey:"readerWidth") as? Double ?? 680
            theme = loadedTheme; appearance = loadedAppearance; energySaving = loadedEnergy
            glassEffectsEnabled = loadedGlass; visualMotionLevel = loadedMotion
            pageTurnStyle = loadedTurn; coverTransitions = loadedCover
            homeFontFamily = loadedHomeFont; homeFontSize = loadedHomeSize
            readerFontFamily = loadedReaderFont
            readerSize = loadedSize; readerWidth = loadedWidth
            loadReadingPreferences()
            restoreReadingPreferences(for:nil)
            rebuildMonet()
            restoreCloudConnections()
            Task { await reloadFonts(); await refreshMissingCovers() }
            activity.onRecord = { [weak self] in
                guard let self, !self.isSyncingCloud else { return }
                self.scheduleCloudSync()
            }
            terminationObserver = NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.flush() }
            }
        } catch { self.error = "书库未能读取，已停止写入以保护原数据：\(error.localizedDescription)" }
    }

    func fileURL(_ book: Book) -> URL { root.appendingPathComponent("Books").appendingPathComponent(book.filename) }

    // One pending, cancellable save for an editing burst; no repeating idle timer.
    func save(sync: Bool = true) {
        guard persistenceReady else { return }
        dirty = true
        if sync { scheduleCloudSync() }
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        flushReadingPreferences()
        pendingSave?.cancel(); pendingSave = nil
        guard persistenceReady, dirty else { return }
        do {
            let data = try JSONEncoder().encode(books)
            if data != lastWrittenData {
                try data.write(to: root.appendingPathComponent("library.json"), options: .atomic)
                lastWrittenData = data
            }
            let groupData = try JSONEncoder().encode(collections)
            if groupData != lastWrittenCollections {
                try groupData.write(to:root.appendingPathComponent("collections.json"),options:.atomic)
                lastWrittenCollections = groupData
            }
            dirty = false
        } catch { self.error = "保存失败：\(error.localizedDescription)" }
    }

    private func savePreferences() {
        let prefs = UserDefaults.standard
        prefs.set(theme.rawValue,forKey:"theme"); prefs.set(appearance.rawValue,forKey:"appearance")
        prefs.set(energySaving,forKey:"energySaving")
        prefs.set(glassEffectsEnabled,forKey:"glassEffectsEnabled")
        prefs.set(visualMotionLevel.rawValue,forKey:"visualMotionLevel")
        prefs.set(pageTurnStyle.rawValue,forKey:"pageTurnStyle")
        prefs.set(coverTransitions,forKey:"coverTransitions")
        prefs.set(homeFontFamily.rawValue,forKey:"homeFontFamily")
        prefs.set(homeFontSize,forKey:"homeFontSize")
        prefs.set(readerFontFamily.rawValue,forKey:"readerFontFamily")
        prefs.set(readerSize,forKey:"readerSize")
        prefs.set(readerWidth,forKey:"readerWidth")
        readingPreferencesDidChange()
    }

    func mutate(_ id: UUID, _ change: (inout Book) -> Void) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        let previous = books[index]
        change(&books[index])
        guard books[index] != previous else { return }
        if books[index].position != previous.position || books[index].progress != previous.progress || books[index].readerOffset != previous.readerOffset || books[index].readerAnchor != previous.readerAnchor {
            books[index].progressUpdatedAt = Date()
        }
        save()
    }

    func askAI() {
        aiPanelVisible = true
        if let reader, selectedBook != nil { reader.askAI(selection:"") }
        else { ai.prepare(nil); NotificationCenter.default.post(name:.lumaAskAI,object:nil) }
    }

    func captureAIContext(_ completion:@escaping (AIReadingContext?) -> Void) {
        guard let reader, selectedBook != nil else { completion(nil); return }
        reader.captureAIContext(selection:ai.pendingQuote,completion:completion)
    }

    @discardableResult func createGroup(_ name:String) -> UUID? {
        do { let id = try collections.create(name); save(); flush(); return id }
        catch { self.error = error.localizedDescription; return nil }
    }
    func renameGroup(_ id:UUID,to name:String) {
        do { try collections.rename(id,to:name); save(); flush() }
        catch { self.error = error.localizedDescription }
    }
    func flushShelfGroups() { save(); flush() }
    func removeGroup(_ id:UUID) { collections.remove(id); save(); flush() }
    func toggleGroup(_ id:UUID,for book:Book) {
        let included = !collections.contains(book:book.id,in:id)
        collections.set(book:book.id,in:id,included:included); save(); flush()
    }

    func toggleInspector() {
        if immersive { toggleImmersive() }
        showInspector.toggle()
    }

    func toggleImmersive() {
        guard selectedBook != nil || immersive else { return }
        if immersive {
            immersive = false; showInspector = inspectorBeforeImmersion
            if restoreAIOnExit { aiPanelVisible = aiBeforeImmersion }; restoreAIOnExit = false
            updateReadingSettingsIfReady()
        } else {
            inspectorBeforeImmersion = showInspector; aiBeforeImmersion = aiPanelVisible; restoreAIOnExit = autoHideAIInFocus
            immersive = true; showInspector = false
            if autoHideAIInFocus { aiPanelVisible = false }
            updateReadingSettingsIfReady()
        }
    }

    func returnToLibrary(statistics: Bool = false) {
        if selectedID != nil { DiagnosticManager.shared.cancel(.bookLoad); DiagnosticManager.shared.record(.bookClose) }
        aiPanelVisible = false; aiPanelExpanded = false
        let lockedTheme = currentReadingPreferences
        if immersive { toggleImmersive() }
        aiPanelVisible = false; aiPanelExpanded = false
        activity.setReadingVisible(false)
        flush()
        scheduleCloudSync()
        selectedID = nil; selectedNoteID = nil; showStatistics = statistics
        restoreReadingPreferences(for:nil,preservingTheme:lockedTheme)
    }

    func open(_ book: Book) {
        if selectedID != book.id { DiagnosticManager.shared.cancel(.bookLoad); DiagnosticManager.shared.begin(.bookLoad) }
        aiPanelVisible = false; aiPanelExpanded = false
        let lockedTheme = monetLocked ? currentReadingPreferences:nil
        flushReadingPreferences()
        if immersive { toggleImmersive() }
        aiPanelVisible = false; aiPanelExpanded = false
        selectedID = book.id; selectedNoteID = nil; showStatistics = false
        restoreReadingPreferences(for:book.id,preservingTheme:lockedTheme)
        mutate(book.id) { $0.lastOpened = Date() }
    }

    func pickBooks(groupID: UUID? = nil) {
        guard persistenceReady, !isImporting else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, UTType(filenameExtension: "epub") ?? .data]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = L10n.text("加入书库")
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { await importFiles(urls, provider: nil, groupID:groupID) }
    }

    @discardableResult
    func importFiles(_ urls: [URL], provider: CloudProvider?, groupID: UUID? = nil) async -> Int {
        guard persistenceReady, !isImporting else { return 0 }
        isImporting = true
        defer { isImporting = false }
        var addedCount = 0
        for source in urls {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let localRoot = root
            let existing = books.filter { $0.kind == source.pathExtension.lowercased() }
            do {
                let book = try await Task.detached(priority: .utility) {
                    try Self.prepareBook(source: source, root: localRoot, existing: existing, provider: provider)
                }.value
                if let book {
                    if !books.contains(where:{ $0.id == book.id }) { books.append(book); addedCount += 1 }
                    else if provider == nil, book.shelf?.removed == true { editShelf(book.id) { $0.removed = false } }
                    if let groupID { collections.set(book:book.id,in:groupID,included:true) }
                    save()
                }
            } catch { DiagnosticManager.shared.record(.bookImportFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)]); self.error = "\(source.lastPathComponent)：\(error.localizedDescription)" }
        }
        return addedCount
    }

    nonisolated private static func prepareBook(source: URL, root: URL, existing: [Book], provider: CloudProvider?) throws -> Book? {
        let kind = source.pathExtension.lowercased()
        guard ["pdf", "epub"].contains(kind) else { return nil }
        if let duplicate = existing.first(where: { FileManager.default.contentsEqual(atPath:source.path,andPath:root.appendingPathComponent("Books").appendingPathComponent($0.filename).path) }) { return duplicate }
        let filename = UUID().uuidString + "." + kind
        let destination = root.appendingPathComponent("Books").appendingPathComponent(filename)
        try FileManager.default.copyItem(at: source, to: destination)
        do {
            var book = Book(title: source.deletingPathExtension().lastPathComponent, filename: filename, kind: kind, cloudProvider: provider)
            if kind == "pdf" {
                guard let doc = PDFDocument(url: destination), !doc.isLocked else { throw ReaderFailure.message("PDF 无法读取或尚未解锁。") }
                book.title = doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? book.title
                book.author = doc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String ?? ""
            } else {
                let content = try EPUBLoader.load(file: destination, cache: root.appendingPathComponent("Cache"))
                if !content.title.isEmpty { book.title = content.title }
                book.author = content.author
            }
            book.coverFilename = try? prepareCover(for:book,root:root)
            return book
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private func refreshMissingCovers() async {
        guard !generatingCovers else { return }
        generatingCovers = true; defer { generatingCovers = false }
        let candidates = books.filter { book in
            guard let filename = book.coverFilename else { return true }
            return !FileManager.default.fileExists(atPath:root.appendingPathComponent("Covers").appendingPathComponent(filename).path)
        }
        let localRoot = root
        for book in candidates {
            let filename = await Task.detached(priority:.utility) { try? Self.prepareCover(for:book,root:localRoot) }.value
            if let filename { mutate(book.id) { $0.coverFilename = filename }; if selectedID == book.id { refreshMonet() } }
        }
    }

    nonisolated private static func prepareCover(for book:Book,root:URL) throws -> String? {
        let source = root.appendingPathComponent("Books").appendingPathComponent(book.filename)
        let data: Data?
        if book.kind == "pdf" {
            let image = PDFDocument(url:source)?.page(at:0)?.thumbnail(of:NSSize(width:320,height:440),for:.cropBox)
            data = image?.tiffRepresentation.flatMap { NSBitmapImageRep(data:$0)?.representation(using:.png,properties:[:]) }
        } else {
            let content = try EPUBLoader.load(file:source,cache:root.appendingPathComponent("Cache"))
            if let url = content.coverURL, let imageSource = CGImageSourceCreateWithURL(url as CFURL,nil),
               let image = CGImageSourceCreateThumbnailAtIndex(imageSource,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:440,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) {
                data = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])
            } else { data = nil }
        }
        guard let data else { return nil }
        let directory = root.appendingPathComponent("Covers",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let filename = book.id.uuidString + ".png"
        try data.write(to:directory.appendingPathComponent(filename),options:.atomic)
        return filename
    }

    // MARK: - Cloud Drive Integration (iCloud Drive, OneDrive, Google Drive)

    private func bookmarkKey(for provider: CloudProvider) -> String { "cloudBookmark.\(provider.rawValue)" }
    private func pathKey(for provider: CloudProvider) -> String { "cloudPath.\(provider.rawValue)" }
    private func syncDateKey(for provider: CloudProvider) -> String { "cloudLastSync.\(provider.rawValue)" }

    func restoreCloudConnections() {
        let prefs = UserDefaults.standard
        for provider in CloudProvider.allCases {
            var state = CloudDriveState(provider: provider)
            if let path = prefs.string(forKey: pathKey(for: provider)), !path.isEmpty,
               FileManager.default.fileExists(atPath: path) {
                state.isConnected = true
                state.folderPath = path
                state.lastSynced = prefs.object(forKey: syncDateKey(for: provider)) as? Date
                state.syncedBookCount = books.count
            }
            cloudStates[provider] = state
        }
    }

    func connectCloud(_ provider: CloudProvider) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.text("接入 \(provider.title)")
        panel.message = L10n.text("选择 \(provider.title) 同步目录")
        if let existing = cloudStates[provider]?.folderPath, !existing.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: existing)
        } else if let detected = provider.discoverDefaultDirectory() {
            panel.directoryURL = detected
        }
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let prefs = UserDefaults.standard
        prefs.set(false, forKey: "cloudDisabled.\(provider.rawValue)")
        prefs.set(folder.path, forKey: pathKey(for: provider))
        if let bookmark = try? folder.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            prefs.set(bookmark, forKey: bookmarkKey(for: provider))
        }
        cloudStates[provider] = CloudDriveState(
            provider: provider,
            isConnected: true,
            folderPath: folder.path,
            lastSynced: cloudStates[provider]?.lastSynced,
            syncedBookCount: books.count
        )
        syncCloud(provider)
    }

    func disconnectCloud(_ provider: CloudProvider) {
        let prefs = UserDefaults.standard
        prefs.set(true, forKey: "cloudDisabled.\(provider.rawValue)")
        prefs.removeObject(forKey: pathKey(for: provider))
        prefs.removeObject(forKey: bookmarkKey(for: provider))
        prefs.removeObject(forKey: syncDateKey(for: provider))
        cloudStates[provider] = CloudDriveState(provider: provider, isConnected: false)
    }

    private func resolveCloudDirectory(for provider: CloudProvider) -> (url: URL, scoped: Bool)? {
        let prefs = UserDefaults.standard
        if let bookmarkData = prefs.data(forKey: bookmarkKey(for: provider)) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
                let accessed = url.startAccessingSecurityScopedResource()
                return (url, accessed)
            }
        }
        if let path = cloudStates[provider]?.folderPath, !path.isEmpty {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return (url, false)
            }
        }
        if let discovered = provider.discoverDefaultDirectory() {
            return (discovered, false)
        }
        return nil
    }

    func syncCloud(_ provider: CloudProvider) {
        guard !isSyncingCloud else { return }
        Task { await performCloudSync(provider) }
    }

    private func performCloudSync(_ provider: CloudProvider) async {
        guard persistenceReady, !isSyncingCloud else { return }
        guard let resolved = resolveCloudDirectory(for: provider) else {
            error = "请重新选择 \(provider.title) 的同步目录。"
            return
        }
        isSyncingCloud = true
        activity.pause()
        flush()
        defer {
            if resolved.scoped { resolved.url.stopAccessingSecurityScopedResource() }
            isSyncingCloud = false
            activity.interaction()
            if syncRequested { syncRequested = false; scheduleCloudSync() }
        }
        let original = books
        let ledger = activity.ledger
        let groupSnapshot = collections
        let localRoot = root
        let directory = resolved.url
        do {
            let result = try await Task.detached(priority: .utility) {
                try CloudSyncEngine.exchange(directory: directory, localRoot: localRoot,
                                             books: original, ledger: ledger, provider: provider, collections:groupSnapshot)
            }.value
            guard cloudStates[provider]?.isConnected == true, cloudStates[provider]?.folderPath == directory.path else { return }
            // Preserve edits made while file transfers were running.
            books = CloudSyncEngine.mergeBooks(local: books, remote: result.books, provider: provider)
            activity.merge(with: result.ledger)
            collections = LibraryGroups.merge(local:collections,remote:result.collections)
            await reloadFonts()
            reader?.refreshAnnotations()
            Task { await refreshMissingCovers() }
            let now = Date()
            UserDefaults.standard.set(now, forKey: syncDateKey(for: provider))
            cloudStates[provider] = CloudDriveState(provider: provider, isConnected: true,
                folderPath: directory.path, lastSynced: now,
                syncedBookCount: books.count)
            save(sync: false)
            flush()
        } catch {
            DiagnosticManager.shared.record(.cloudSyncFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)])
            self.error = "\(provider.title) 同步失败：\(error.localizedDescription)"
        }
    }

    func syncAllConnectedClouds() {
        if isSyncingCloud { syncRequested = true; return }
        Task {
            for provider in CloudProvider.allCases where cloudStates[provider]?.isConnected == true {
                await performCloudSync(provider)
            }
        }
    }

    private func scheduleCloudSync() {
        guard cloudStates.values.contains(where: { $0.isConnected }) else { return }
        // Event-driven debounce: no periodic cloud polling while the reader is idle.
        cloudSaveTask?.cancel()
        cloudSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.syncAllConnectedClouds()
        }
    }

    @discardableResult
    func addBookmark(position:Int,title:String) -> Bool {
        guard let id = selectedID, let book = books.first(where:{ $0.id == id }) else { return false }
        guard !(book.bookmarks ?? []).contains(where:{ mark in
            guard mark.position == position else { return false }
            if let a = mark.anchor, let b = book.readerAnchor { return a.start == b.start && a.quote == b.quote }
            return abs((mark.offset ?? 0)-(book.readerOffset ?? 0)) < 0.01
        }) else { return false }
        mutate(id) { book in
            var marks = book.bookmarks ?? []
            marks.append(ReadingBookmark(title:title,position:position,offset:book.readerOffset,anchor:book.readerAnchor)); book.bookmarks = marks
        }
        return true
    }

    func removeBookmark(_ mark: ReadingBookmark, from id: UUID) {
        mutate(id) { book in
            book.bookmarks = (book.bookmarks ?? []).filter { $0.id != mark.id }
            book.deletedBookmarks = book.deletedBookmarks ?? [:]
            book.deletedBookmarks?[mark.id.uuidString] = Date()
        }
    }

    // MARK: - Notes Management

    func add(_ note: ReadingNote, to bookID: UUID, undo: UndoManager?) {
        var restored = note
        restored.modifiedAt = Date()
        mutate(bookID) { $0.notes.append(restored) }
        selectedNoteID = note.id
        reader?.refreshAnnotations()
        undo?.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated { store.remove(note.id, from: bookID, undo: undo) }
        }
        undo?.setActionName("添加批注")
    }

    func remove(_ noteID: UUID, from bookID: UUID, undo: UndoManager?) {
        removeNotes([noteID],from:bookID,undo:undo)
    }

    func removeNotes(_ ids:[UUID],from bookID:UUID,undo:UndoManager?) {
        let targets = Set(ids)
        guard let book = books.first(where:{ $0.id == bookID }) else { return }
        let removed = book.notes.filter { targets.contains($0.id) }
        guard !removed.isEmpty else { return }
        mutate(bookID) { NoteActions.remove(targets,from:&$0,at:Date()) }
        if let selected = selectedNoteID, targets.contains(selected) { selectedNoteID = nil }
        reader?.refreshAnnotations()
        undo?.registerUndo(withTarget:self) { store in
            MainActor.assumeIsolated { store.restoreNotes(removed,in:bookID,undo:undo) }
        }
        undo?.setActionName("取消标注和笔记")
    }

    private func restoreNotes(_ notes:[ReadingNote],in bookID:UUID,undo:UndoManager?) {
        mutate(bookID) { NoteActions.restore(notes,in:&$0,at:Date()) }
        reader?.refreshAnnotations()
        undo?.registerUndo(withTarget:self) { store in
            MainActor.assumeIsolated { store.removeNotes(notes.map(\.id),from:bookID,undo:undo) }
        }
        undo?.setActionName("取消标注和笔记")
    }

    func edit(_ noteID: UUID, in bookID: UUID, text: String? = nil, ink: Ink? = nil) {
        mutate(bookID) { book in
            guard let i = book.notes.firstIndex(where: { $0.id == noteID }) else { return }
            book.notes[i].modifiedAt = Date()
            if let text { book.notes[i].note = text }
            if let ink { book.notes[i].ink = ink; book.notes[i].colorHex = nil }
        }
        if ink != nil { reader?.refreshAnnotations() }
        else if let text { reader?.updateNoteText(noteID,text:text) }
    }

    func exportNotes() {
        guard let book = selectedBook else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = book.title + "-批注.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = "# \(book.title)\n\n" + book.notes.map {
            "> " + $0.quote.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n" + $0.note + "\n\n*\($0.ink.title)*\n"
        }.joined(separator: "\n---\n\n")
        do { try text.write(to: url, atomically: true, encoding: .utf8) }
        catch { self.error = error.localizedDescription }
    }
}
