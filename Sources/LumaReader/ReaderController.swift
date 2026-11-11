import Observation
import UniformTypeIdentifiers
import SwiftUI
import PDFKit
import WebKit

@MainActor @Observable
final class ReaderController: NSObject {
    var searchResults: [BookSearchHit] = []
    var isSearching = false
    var searchError: String?
    var recentSearches = RecentBookSearches.read()
    var presentationReady = false
    @ObservationIgnored private var initialPaperCover: NSView?
    var isTurning = false
    var hasSelection = false
    var location = ""
    var chapters: [Chapter] = []
    var outline: [ReadingOutlineItem] = []
    @ObservationIgnored private var pendingOutline: ReadingOutlineItem?
    @ObservationIgnored private var pdfOutlineTargets: [String:PDFDestination] = [:]
    var chapterIndex = 0
    var currentHeadingIndex = -1
    var currentHeadingID = ""
    @ObservationIgnored private var currentTextAnchor: ReaderTextAnchor?
    @ObservationIgnored private var bookmarkAnchor: ReaderTextAnchor?
    @ObservationIgnored private var recoveryAnchor: ReaderTextAnchor?
    @ObservationIgnored private var pdfViewportDestination: PDFDestination?
    @ObservationIgnored private var viewportToken: UUID?
    @ObservationIgnored private var viewportFinishTask: Task<Void,Never>?
    @ObservationIgnored private var viewportWatchdog: Task<Void,Never>?
    @ObservationIgnored private var pendingNoteID: UUID?
    var canGoBack = false
    var canGoForward = false
    var selectedQuote = ""
    var bookmarkFeedback = ""
    var bookmarkPulse = 0
    private var bookmarkPage = ReaderBookmarkPage()
    private var readingJumpHistory = ReadingJumpHistory()
    var canReturnToReading: Bool { !readingJumpHistory.isEmpty }
    var imagePreview: ReaderImage?
    @ObservationIgnored private var bookmarkFeedbackTask: Task<Void,Never>?
    @ObservationIgnored private var menuNoteIDs:[UUID] = []
    @ObservationIgnored weak var store: LibraryStore?
    @ObservationIgnored weak var undo: UndoManager?
    @ObservationIgnored private weak var attachedContainer: NSView?
    @ObservationIgnored private var bookID: UUID?
    @ObservationIgnored private var pdfView: PDFView?
    @ObservationIgnored private var webView: WKWebView?
    @ObservationIgnored private var epub: EPUBContent?
    @ObservationIgnored private var selection: PDFSelection?
    @ObservationIgnored private var htmlSelection: (start: Int, end: Int, quote: String)?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var renderedPDFNotes: [UUID: ReadingNote] = [:]
    @ObservationIgnored private var managedPDFAnnotations: [UUID: [PDFAnnotation]] = [:]
    @ObservationIgnored private var lastWebAnnotations = ""
    @ObservationIgnored private var lastSettings = ""
    @ObservationIgnored private var webCanGoBack = false
    @ObservationIgnored private var webCanGoForward = false
    @ObservationIgnored private var webReady = false
    @ObservationIgnored private var bookmarkOffset: Double?
    @ObservationIgnored private var pageCover: PageTurnCover?
    @ObservationIgnored private var edgeDrag: (id:UUID, forward:Bool, progress:Double, commit:Bool?)?
    @ObservationIgnored private var queuedMove: Int?
    @ObservationIgnored private var navigationID = UUID()
    @ObservationIgnored private var pendingForward = true
    @ObservationIgnored private var presentationOffset = 0.0
    @ObservationIgnored private var recoveryChapter: Int?
    @ObservationIgnored private var recoveryOffset = 0.0
    @ObservationIgnored private var isRecovering = false
    @ObservationIgnored private var searchTask: Task<Void,Never>?
    @ObservationIgnored private var searchIndex: [SearchChapter]?
    @ObservationIgnored private var currentSearchQuery = ""
    @ObservationIgnored private var pendingSearchHit: BookSearchHit?
    @ObservationIgnored private var navigationDeadline: Task<Void,Never>?
    @ObservationIgnored private let world = WKContentWorld.world(name: "LumaReader")

    var imageRoot:URL? { epub?.root }
    var currentPDFPage:PDFPage? { pdfView?.currentPage }
    var illustrationWebView:WKWebView? { webView }

    var currentChapterTitle: String {
        guard chapters.indices.contains(chapterIndex) else { return "" }
        return chapters[chapterIndex].title
    }

    func attach(to container: NSView, book: Book, store: LibraryStore, undo: UndoManager?) {
        self.store = store; self.undo = undo; store.reader = self
        container.wantsLayer = true; container.layer?.masksToBounds = true; container.layer?.backgroundColor = paperColor.cgColor
        (pdfView as? SelectablePDFView)?.aiIconColor = NSColor(store.accent)
        if bookID == book.id, attachedContainer === container, pdfView != nil || webView != nil { updateSettings(); return }
        teardown()
        bookID = book.id
        attachedContainer = container
        container.subviews.forEach { $0.removeFromSuperview() }
        do {
            if book.kind == "pdf" {
                guard let document = PDFDocument(url: store.fileURL(book)) else { throw ReaderFailure.message("PDF 无法读取。") }
                let view = SelectablePDFView(frame: container.bounds)
                view.autoresizingMask = [.width, .height]
                view.autoScales = true
                view.displayMode = .twoUp
                view.displaysAsBook = true
                view.displaysPageBreaks = true
                view.backgroundColor = paperColor
                view.document = document
                chapters = (0..<document.pageCount).map { Chapter(id:$0,title:"第 \($0+1) 页",url:store.fileURL(book)) }
                func pdfOutline(_ parent: PDFOutline, path: String) -> [ReadingOutlineItem] {
                    (0..<parent.numberOfChildren).compactMap { i in
                        guard let child = parent.child(at:i) else { return nil }
                        let destination = child.destination ?? (child.action as? PDFActionGoTo)?.destination
                        let page: Int?
                        if let targetPage = destination?.page { page = document.index(for:targetPage) } else { page = nil }
                        let id = path+"/"+String(i)
                        if let destination { pdfOutlineTargets[id] = destination }
                        return ReadingOutlineItem(id:id,title:child.label ?? "目录",chapterIndex:page,children:pdfOutline(child,path:path+"/"+String(i)))
                    }
                }
                if let root = document.outlineRoot { outline = pdfOutline(root,path:"pdf") }
                if outline.isEmpty { outline = chapters.map { ReadingOutlineItem(id:"page/\($0.id)",title:$0.title,chapterIndex:$0.id) } }
                view.noteIDsForSelection = { [weak self] in self?.selectedNoteIDs ?? [] }
                view.onDeleteNotes = { [weak self] ids in self?.removeNotes(ids) }
                view.onWheelTurn = { [weak self] direction in self?.move(direction) }
                view.onBlankClick = { [weak self] in if self?.store?.aiPanelPinned != true { self?.store?.aiPanelVisible = false } }
                view.onCopyText = { [weak self] in self?.showCopyFeedback() }
                view.onCreateNote = { [weak self] in if let self, let store = self.store { self.highlight(store.activeInk); store.showInspector = true } }
                view.onEditNote = { [weak self] id in self?.editNote(id) }
                view.quoteForNote = { [weak self] id in self?.store?.selectedBook?.notes.first(where:{ $0.id == id })?.quote }
                view.onDeleteNote = { [weak self] noteID in self?.deleteNote(noteID) }
                view.setNoteAppearance(paper:NSColor(store.chrome(dark:usesDarkPaper)),ink:NSColor(store.readingPalette(dark:usesDarkPaper).ink),accent:NSColor(store.accent),glass:store.effectiveGlassEffectsEnabled)
                view.onAskAI = { [weak self] quote in self?.askAI(selection:quote) }
                container.addSubview(view); pdfView = view
                if let page = document.page(at: min(max(0,book.position), max(0,document.pageCount-1))) { view.go(to: page) }
                observers.append(NotificationCenter.default.addObserver(forName: .PDFViewSelectionChanged, object: view, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.capturePDFSelection() }
                })
                observers.append(NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.updatePDFLocation() }
                })
                refreshAnnotations(); updatePDFLocation(); presentationReady = true; DiagnosticManager.shared.finish(.bookLoad)
            } else {
                let content = try EPUBLoader.load(file: store.fileURL(book), cache: store.root.appendingPathComponent("Cache"))
                epub = content; chapters = content.chapters; outline = content.outline
                chapterIndex = min(max(0,book.position), chapters.count-1)
                let config = WKWebViewConfiguration()
                // The bridge is in an isolated world, inaccessible to imported book scripts.
                config.userContentController.add(self, contentWorld: world, name: "reader")
                let js = try ReaderResources.text(name:"Reader",fileExtension:"js")
                config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
                let view = PagedWebView(frame: container.bounds, configuration: config)
                view.onWheelTurn = { [weak self] direction in self?.move(direction) }
                view.autoresizingMask = [.width, .height]; view.navigationDelegate = self
                view.underPageBackgroundColor = paperColor
                view.appearance = NSAppearance(named:usesDarkPaper ? .darkAqua:.aqua)
                container.addSubview(view); webView = view
                let cover = NSView(frame:container.bounds)
                cover.autoresizingMask = [.width,.height]; cover.wantsLayer = true
                cover.layer?.backgroundColor = paperColor.cgColor
                container.addSubview(cover,positioned:.above,relativeTo:view); initialPaperCover = cover
                try loadChapter()
            }
        installEdgeGestures(in:container)
        } catch { DiagnosticManager.shared.record(.bookLoadFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)]); DiagnosticManager.shared.cancel(.bookLoad); teardown(); store.error = error.localizedDescription }
    }

    func teardown() {
        initialPaperCover?.removeFromSuperview(); initialPaperCover = nil
        cancelViewportChange()
        currentTextAnchor = nil; bookmarkAnchor = nil; recoveryAnchor = nil; pendingNoteID = nil
        bookmarkPage = ReaderBookmarkPage(); readingJumpHistory = ReadingJumpHistory()
        currentHeadingIndex = -1; currentHeadingID = ""
        searchTask?.cancel(); searchTask = nil; searchIndex = nil; searchResults = []; currentSearchQuery = ""; pendingSearchHit = nil; isSearching = false
        navigationID = UUID(); navigationDeadline?.cancel(); navigationDeadline = nil
        edgeDrag = nil; queuedMove = nil; presentationReady = false
        pageCover?.layer?.removeAllAnimations(); pageCover?.removeFromSuperview(); pageCover = nil
        isTurning = false; isRecovering = false; recoveryChapter = nil; bookmarkOffset = nil
        observers.forEach(NotificationCenter.default.removeObserver); observers = []
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "reader", contentWorld: world)
        managedPDFAnnotations.removeAll(); renderedPDFNotes.removeAll()
        lastWebAnnotations = ""; lastSettings = ""; webReady = false
        pdfView?.removeFromSuperview(); webView?.removeFromSuperview()
        attachedContainer = nil
        pdfView = nil; webView = nil; epub = nil; bookID = nil
        bookmarkFeedbackTask?.cancel(); bookmarkFeedback = ""; imagePreview = nil
        selection = nil; htmlSelection = nil; chapters = []; outline = []; pendingOutline = nil; pdfOutlineTargets = [:]; hasSelection = false; selectedQuote = ""
    }

    func detach(from container:NSView) {
        guard attachedContainer === container else { return }
        teardown()
    }

    private func evaluate(_ script: String) {
        webView?.evaluateJavaScript(script, in: nil, in: world, completionHandler: { _ in })
    }

    private func capturePDFSelection() {
        selection = pdfView?.currentSelection?.copy() as? PDFSelection
        selectedQuote = selection?.string ?? ""
        hasSelection = !selectedQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updatePDFLocation() {
        guard let view = pdfView, let page = view.currentPage, let document = view.document, let id = bookID else { return }
        let index = document.index(for: page)
        chapterIndex = index
        location = "第 \(index+1) / \(document.pageCount) 页"
        canGoBack = index > 0; canGoForward = index < document.pageCount-1
        store?.mutate(id) { $0.position = index; $0.progress = Double(index+1) / Double(max(1,document.pageCount)) }
    }

    func highlight(_ ink: Ink, monet: Bool = false) {
        guard let id = bookID, let store else { return }
        store.activeInk = ink
        if let view = pdfView, let document = view.document, let selection, hasSelection {
            var rects: [PageRect] = []
            for line in selection.selectionsByLine() {
                for page in line.pages {
                    let bounds = line.bounds(for: page)
                    guard !bounds.isEmpty, bounds.width.isFinite, bounds.height.isFinite else { continue }
                    rects.append(PageRect(page: document.index(for: page), x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: bounds.height))
                }
            }
            guard !rects.isEmpty else { return }
            var note = ReadingNote(quote: selection.string ?? "", ink: ink, rects: rects)
            if monet { note.colorHex = ReadingPalette.hex(store.accent) }
            store.add(note, to:id, undo:undo)
            view.clearSelection(); self.selection = nil; hasSelection = false
        } else if webView != nil, let selected = htmlSelection, hasSelection {
            var note = ReadingNote(quote:selected.quote, ink:ink, chapter:chapterIndex, start:selected.start, end:selected.end)
            if monet { note.colorHex = ReadingPalette.hex(store.accent) }
            store.add(note, to:id, undo:undo)
            htmlSelection = nil; hasSelection = false
            evaluate("window.Luma?.clear()")
        }
        if !store.immersive { store.showInspector = true }
    }

    func refreshAnnotations() {
        guard let id = bookID, let book = store?.books.first(where: { $0.id == id }) else { return }
        if let document = pdfView?.document {
            let desired = Dictionary(book.notes.map { ($0.id,$0) }, uniquingKeysWith: { _, newer in newer })
            for id in Array(renderedPDFNotes.keys) where desired[id] == nil {
                managedPDFAnnotations.removeValue(forKey:id)?.forEach { $0.page?.removeAnnotation($0) }
                renderedPDFNotes.removeValue(forKey:id)
            }
            for note in book.notes {
                let old = renderedPDFNotes[note.id]
                if old == note { continue }
                if let old, old.rects == note.rects, old.highlightHex == note.highlightHex {
                    // Editing note text changes annotation contents, not page geometry.
                    managedPDFAnnotations[note.id]?.forEach { $0.contents = note.note.isEmpty ? note.quote : note.note }
                } else {
                    managedPDFAnnotations.removeValue(forKey:note.id)?.forEach { $0.page?.removeAnnotation($0) }
                    var created: [PDFAnnotation] = []
                    for rect in note.rects {
                        guard let page = document.page(at:rect.page) else { continue }
                        let annotation = PDFAnnotation(bounds:rect.cgRect,forType:.highlight,withProperties:nil)
                        annotation.color = NSColor(Color(hex:note.highlightHex)).withAlphaComponent(0.42)
                        annotation.userName = "Luma:" + note.id.uuidString
                        annotation.contents = note.note.isEmpty ? note.quote : note.note
                        page.addAnnotation(annotation); created.append(annotation)
                    }
                    managedPDFAnnotations[note.id] = created
                }
                renderedPDFNotes[note.id] = note
            }
        } else if webReady {
            let notes: [[String: Any]] = book.notes.filter { $0.chapter == chapterIndex && $0.start != nil }.map {
                ["id":$0.id.uuidString,"start":$0.start!,"end":$0.end ?? $0.start!,"color":"#"+$0.highlightHex]
            }
            if let data = try? JSONSerialization.data(withJSONObject:notes,options:.sortedKeys),
               let json = String(data:data,encoding:.utf8), json != lastWebAnnotations {
                lastWebAnnotations = json
                evaluate("window.Luma?.render(\(json))")
            }
        }
    }

    func updateNoteText(_ id: UUID, text: String) {
        guard var note = renderedPDFNotes[id] else { return }
        note.note = text
        renderedPDFNotes[id] = note
        managedPDFAnnotations[id]?.forEach { $0.contents = text.isEmpty ? note.quote : text }
    }

    func jump(to note: ReadingNote) {
        guard presentationReady, !isTurning, viewportToken == nil,
              pdfView != nil || chapters.indices.contains(note.chapter) else { return }
        rememberReadingJump()
        if let view = pdfView, let page = view.document?.page(at: note.rects.first?.page ?? 0), let rect = note.rects.first {
            view.go(to: rect.cgRect, on: page)
        } else if epub != nil {
            if chapterIndex != note.chapter {
                pendingNoteID = note.id
                navigate(to:note.chapter, offset:0)
            } else { evaluate("window.Luma?.jump('\(note.id.uuidString)')") }
        }
    }

    var currentBookmark: ReadingBookmark? {
        guard let book = store?.selectedBook else { return nil }
        let position = pdfView.flatMap { view in view.currentPage.flatMap { view.document?.index(for:$0) } } ?? chapterIndex
        return book.bookmarks?.first { mark in
            guard mark.position == position else { return false }
            if pdfView != nil { return true }
            return bookmarkPage.contains(mark,currentAnchor:currentTextAnchor ?? book.readerAnchor,offset:book.readerOffset ?? 0)
        }
    }

    func addBookmark() {
        guard let store, presentationReady, !isTurning, viewportToken == nil, store.selectedID == bookID else { return }
        let position: Int
        if let view = pdfView, let page = view.currentPage, let document = view.document { position = document.index(for: page) }
        else { position = chapterIndex }
        let title = epub == nil ? location : location + " · \(Int((store.selectedBook?.readerOffset ?? 0) * 100))%"
        if let mark = currentBookmark, let id = store.selectedID {
            store.removeBookmark(mark,from:id)
            bookmarkFeedback = "已删除书签"
        } else {
            let inserted = store.addBookmark(position:position,title:title)
            bookmarkFeedback = inserted ? "已添加书签":"本页已有书签"
        }
        bookmarkPulse += 1
        bookmarkFeedbackTask?.cancel()
        bookmarkFeedbackTask = Task { [weak self] in
            do { try await Task.sleep(for:.seconds(1.4)) } catch { return }
            self?.bookmarkFeedback = ""
        }
    }

    func jump(to bookmark: ReadingBookmark) {
        guard presentationReady, !isTurning, viewportToken == nil,
              pdfView != nil || chapters.indices.contains(bookmark.position) else { return }
        rememberReadingJump()
        store?.selectedNoteID = nil
        if let view = pdfView, let page = view.document?.page(at: bookmark.position) { view.go(to: page) }
        else if chapters.indices.contains(bookmark.position) {
            if bookmark.position == chapterIndex, webReady {
                evaluate("window.Luma?.restore(\(bookmark.offset ?? 0),\(bookmark.anchor?.json ?? "null"))")
            } else {
                bookmarkAnchor = bookmark.anchor
                navigate(to:bookmark.position, offset:bookmark.offset ?? 0)
            }
        }
    }

    func move(_ delta: Int) {
        if store?.aiPanelPinned != true { store?.aiPanelVisible = false }
        if viewportToken != nil, !isTurning {
            queuedMove = max(-4,min(4,(queuedMove ?? 0)+(delta < 0 ? -1:1))); return
        }
        cancelViewportChange()
        guard edgeDrag == nil else { return }
        if isTurning { queuedMove = max(-4,min(4,(queuedMove ?? 0)+(delta < 0 ? -1:1))); return }
        hasSelection = false; htmlSelection = nil; selection = nil
        if let view = pdfView {
            let canMove = delta < 0 ? canGoBack : canGoForward
            guard canMove, let container = attachedContainer else { queuedMove = nil; return }
            isTurning = true
            if turnDuration > 0, pageCover == nil {
                let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds)
                var image: NSImage?
                if let bitmap {
                    view.cacheDisplay(in:view.bounds,to:bitmap)
                    let picture = NSImage(size:view.bounds.size); picture.addRepresentation(bitmap); image = picture
                }
                installCover(image, in:container)
            }
            delta < 0 ? view.goToPreviousPage(nil) : view.goToNextPage(nil)
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            DispatchQueue.main.async { [weak self] in self?.finishTurn(forward:delta > 0) }
        } else if (delta < 0 ? webCanGoBack : webCanGoForward) {
            turnWithinChapter(delta)
        } else if !chapters.isEmpty {
            let index = min(max(chapterIndex + delta, 0), chapters.count-1)
            guard index != chapterIndex else { queuedMove = nil; return }
            navigate(to:index, offset:delta < 0 ? 1:0)
        }
    }

    private func turnWithinChapter(_ delta: Int) {
        guard let view = webView, let container = attachedContainer else { return }
        isTurning = true
        navigationID = UUID(); let token = navigationID
        pendingForward = delta > 0
        recoveryChapter = chapterIndex; recoveryOffset = store?.selectedBook?.readerOffset ?? 0
        armNavigationDeadline(token)
        let configuration = WKSnapshotConfiguration(); configuration.rect = view.bounds
        evaluate("window.Luma?.dismissHover()")
        // During battery saving, avoid allocating a full-page GPU snapshot.
        if turnDuration == 0 || pageCover != nil {
            view.evaluateJavaScript("window.Luma?.turn(\(delta))",in:nil,in:world) { [weak self] result in
                MainActor.assumeIsolated {
                    guard let self, self.navigationID == token else { return }
                    if case .success(let value) = result, value as? Bool == true {
                        self.evaluate("window.Luma?.preparePresentation('\(token.uuidString)')")
                    } else {
                        self.isTurning = false
                        self.navigationDeadline?.cancel(); self.navigationDeadline = nil
                    }
                }
            }
            return
        }
        view.takeSnapshot(with:configuration) { [weak self, weak view, weak container] image, _ in
            MainActor.assumeIsolated {
                guard let self, let view, let container, self.navigationID == token, self.webView === view else { return }
                self.installCover(image,in:container)
                view.evaluateJavaScript("window.Luma?.turn(\(delta))",in:nil,in:self.world) { [weak self] result in
                    MainActor.assumeIsolated {
                        guard let self, self.navigationID == token else { return }
                        if case .success(let value) = result, value as? Bool == true {
                            self.evaluate("window.Luma?.preparePresentation('\(token.uuidString)')")
                        } else {
                            self.pageCover?.removeFromSuperview(); self.pageCover = nil; self.isTurning = false
                            self.navigationDeadline?.cancel(); self.navigationDeadline = nil
                        }
                    }
                }
            }
        }
    }

    func goToChapter(_ index: Int) {
        guard presentationReady, !isTurning, viewportToken == nil, chapters.indices.contains(index) else { return }
        rememberReadingJump()
        store?.selectedNoteID = nil
        if pdfView != nil {
            guard let page = pdfView?.document?.page(at:index) else { return }
            pdfView?.go(to:page)
        } else { navigate(to:index,offset:0) }
    }

    func goToOutline(_ item: ReadingOutlineItem) {
        guard presentationReady, !isTurning, viewportToken == nil, let index = item.chapterIndex, chapters.indices.contains(index) else { return }
        rememberReadingJump()
        store?.selectedNoteID = nil; pendingNoteID = nil
        if let pdfView {
            if let destination = pdfOutlineTargets[item.id] { pdfView.go(to:destination) }
            else if let page = pdfView.document?.page(at:index) { pdfView.go(to:page) }
            return
        }
        if index == chapterIndex { jumpToOutline(item) }
        else { pendingOutline = item; navigate(to:index,offset:0) }
    }
    private func jumpToOutline(_ item: ReadingOutlineItem) {
        if item.fragment == nil && item.headingIndex == nil { evaluate("window.Luma?.restore(0)"); return }
        let target: [String:Any] = ["fragment":item.fragment ?? "","headingIndex":item.headingIndex ?? -1]
        guard let data = try? JSONSerialization.data(withJSONObject:target), let json = String(data:data,encoding:.utf8) else { return }
        evaluate("window.Luma?.jumpToHeading(\(json))")
    }

    private func rememberReadingJump() {
        guard presentationReady, !isTurning, store?.selectedID == bookID else { return }
        if let view = pdfView, let page = view.currentPage, let document = view.document {
            let destination = view.currentDestination
            let point = destination?.point ?? CGPoint(x:0,y:page.bounds(for:view.displayBox).maxY)
            let destinationPage = destination?.page ?? page
            readingJumpHistory.remember(.pdf(page:document.index(for:destinationPage),x:Double(point.x),y:Double(point.y),zoom:Double(destination?.zoom ?? 0)))
        } else if webReady {
            readingJumpHistory.remember(.epub(chapter:chapterIndex,offset:presentationOffset,anchor:currentTextAnchor ?? store?.selectedBook?.readerAnchor))
        }
    }

    func returnToReadingPosition() {
        guard presentationReady, !isTurning, viewportToken == nil, store?.selectedID == bookID,
              let position = readingJumpHistory.pop() else { return }
        store?.selectedNoteID = nil; pendingNoteID = nil; pendingOutline = nil; pendingSearchHit = nil
        switch position {
        case let .epub(chapter,offset,anchor):
            guard chapters.indices.contains(chapter), webReady else { readingJumpHistory.remember(position); return }
            if chapter == chapterIndex {
                evaluate("window.Luma?.restore(\(offset),\(anchor?.json ?? "null"))")
            } else {
                bookmarkAnchor = anchor
                navigate(to:chapter,offset:offset)
            }
        case let .pdf(index,x,y,zoom):
            guard let view = pdfView, let page = view.document?.page(at:index) else { readingJumpHistory.remember(position); return }
            let destination = PDFDestination(page:page,at:CGPoint(x:x,y:y))
            if zoom > 0 { destination.zoom = CGFloat(zoom) }
            view.go(to:destination)
        }
        focusReadingSurface()
    }

    func focusReadingSurface() {
        guard let bookID, store?.selectedID == bookID else { return }
        if let webView { webView.window?.makeFirstResponder(webView) }
        else if let pdfView { pdfView.window?.makeFirstResponder(pdfView) }
    }

    private func persistReadingPosition(bookID id: UUID) {
        let progress = ReadingProgress.epub(chapter:chapterIndex,chapterCount:chapters.count,offset:presentationOffset,canForward:canGoForward)
        store?.mutate(id) {
            $0.position = chapterIndex; $0.readerOffset = presentationOffset
            $0.readerAnchor = currentTextAnchor; $0.progress = progress
        }
    }

    /// AppKit resizes the live view. Defer pagination only; never replace the page with a scaled screenshot.
    func beginViewportChange(autoFinish:Bool = false) {
        guard let bookID, store?.selectedID == bookID else { return }
        viewportFinishTask?.cancel()
        if let pdfView {
            DiagnosticManager.shared.begin(.viewport)
            if pdfViewportDestination == nil { pdfViewportDestination = pdfView.currentDestination }
        } else if webReady && !isTurning {
            DiagnosticManager.shared.begin(.viewport)
            let token = UUID(); viewportToken = token
            evaluate("window.Luma?.beginViewportChange('\(token.uuidString)')")
        }
        viewportWatchdog?.cancel()
        viewportWatchdog = Task { [weak self] in
            do { try await Task.sleep(for:.seconds(8)) } catch { return }
            self?.finishViewportChange()
        }
        if autoFinish {
            viewportFinishTask = Task { [weak self] in
                do { try await Task.sleep(for:.milliseconds(180)) } catch { return }
                self?.finishViewportChange()
            }
        }
    }
    func finishViewportChange() {
        viewportFinishTask?.cancel(); viewportFinishTask = nil
        if let destination = pdfViewportDestination { pdfView?.go(to:destination); pdfViewportDestination = nil; DiagnosticManager.shared.finish(.viewport) }
        guard let token = viewportToken else { return }
        evaluate("window.Luma?.endViewportChange('\(token.uuidString)')")
        viewportWatchdog?.cancel()
        viewportWatchdog = Task { [weak self] in
            do { try await Task.sleep(for:.seconds(1)) } catch { return }
            guard let self, self.viewportToken == token else { return }
            self.evaluate("window.Luma?.endViewportChange('\(token.uuidString)')")
        }
    }
    private func clearViewportChange() {
        viewportWatchdog?.cancel(); viewportWatchdog = nil
        viewportToken = nil
    }
    private func cancelViewportChange() {
        DiagnosticManager.shared.cancel(.viewport)
        viewportFinishTask?.cancel(); viewportFinishTask = nil; pdfViewportDestination = nil
        if let token = viewportToken { evaluate("window.Luma?.endViewportChange('\(token.uuidString)')") }
        clearViewportChange()
    }

    private var usesDarkPaper: Bool { store?.isDarkAppearance ?? false }

    private var paperColor: NSColor { store.map { NSColor($0.paper(dark:usesDarkPaper)) } ?? .windowBackgroundColor }

    private var settingsScript: String {
        guard let store else { return "" }
        let customCSS = epub.map { store.readerFontCSS(in:$0.root) } ?? ""
        let options: [String:Any] = ["customFontCSS":customCSS,"customFontKey":customCSS.isEmpty ? "":store.readerCustomFont,
                                     "colors":store.readingPalette(dark:usesDarkPaper).webColors,
                                     "lineHeight":store.readerLineHeight,"paragraphSpacing":store.readerParagraphSpacing,
                                     "indent":store.readerIndent,"focus":store.immersive,"language":L10n.code]
        guard let data = try? JSONSerialization.data(withJSONObject:options,options:.sortedKeys),
              let json = String(data:data,encoding:.utf8) else { return "" }
        return "window.Luma?.settings(\(store.readerSize),\(store.readerWidth),\(usesDarkPaper),'\(store.theme.rawValue)','\(store.readerFontFamily.rawValue)',\(json));document.documentElement.dataset.reduceVisualEffects='\(store.effectiveMotionLevel == .off ? "true":"false")'"

    }

    func updateSettings() {
        guard let bookID, store?.selectedID == bookID else { return }
        if turnDuration == 0, let drag = edgeDrag {
            edgeDrag = nil; pageCover?.removeFromSuperview(); pageCover = nil
            if drag.commit == true { move(drag.forward ? 1:-1) }
        }
        attachedContainer?.layer?.backgroundColor = paperColor.cgColor
        initialPaperCover?.layer?.backgroundColor = paperColor.cgColor
        webView?.underPageBackgroundColor = paperColor
        let appearance = usesDarkPaper ? NSAppearance.Name.darkAqua:.aqua
        if webView?.appearance?.name != appearance { webView?.appearance = NSAppearance(named:appearance) }
        pdfView?.backgroundColor = paperColor
        if let view = pdfView as? SelectablePDFView, let store {
            view.setNoteAppearance(paper:NSColor(store.chrome(dark:usesDarkPaper)),ink:NSColor(store.readingPalette(dark:usesDarkPaper).ink),accent:NSColor(store.accent),glass:store.effectiveGlassEffectsEnabled)
        }
        guard webReady else { return }
        let script = settingsScript
        guard script != lastSettings else { return }
        lastSettings = script; evaluate(script)
    }

    private func armNavigationDeadline(_ token:UUID) {
        navigationDeadline?.cancel()
        navigationDeadline = Task { [weak self] in
            do { try await Task.sleep(for:.seconds(12)) } catch { return }
            guard let self, self.navigationID == token, self.isTurning || !self.presentationReady else { return }
            self.failNavigation(ReaderFailure.message("页面尚未就绪，请重试或检查本地书籍文件。"))
        }
    }

    private func installCover(_ image: NSImage?, in container: NSView) {
        if pageCover != nil { return }
        let cover = PageTurnCover(frame:container.bounds,image:image,paper:paperColor)
        container.addSubview(cover,positioned:.above,relativeTo:nil)
        pageCover = cover
    }

    private func finishTurn(forward: Bool) {
        navigationDeadline?.cancel(); navigationDeadline = nil
        let token = navigationID
        let duration = turnDuration
        guard let cover = pageCover else { isTurning = false; drainQueuedMove(); return }
        cover.turn(forward:forward,style:store?.pageTurnStyle ?? .natural,duration:duration) { [weak self] in
            guard let self, self.navigationID == token else { return }
            self.pageCover = nil; self.isTurning = false; self.drainQueuedMove()
        }
    }

    private var turnDuration: Double {
        guard store?.pageTurnStyle != PageTurnStyle.none, store?.pageMotionMode != "none" else { return 0 }
        let base = ReaderMotionPolicy.pageTurnDuration(enabled:store?.pageTurnAnimation == true && store?.effectiveMotionLevel != .off,
            reduceMotion:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            systemLowPower:store?.systemLowPower == true,energySaving:store?.effectiveEnergySaving == true)
        guard base > 0 else { return 0 }
        if queuedMove != nil { return min(base,0.20) }
        return store?.pageTurnStyle == .natural && store?.effectiveMotionLevel == .enhanced ? 0.52:base
    }

    private func drainQueuedMove() {
        guard let delta = queuedMove else { return }
        guard delta != 0 else { queuedMove = nil; return }
        let direction = delta < 0 ? -1:1
        let remaining = delta-direction
        queuedMove = remaining == 0 ? nil:remaining
        DispatchQueue.main.async { [weak self] in self?.move(direction) }
    }

    private func installEdgeGestures(in container:NSView) {
        let edges = ReaderEdgeTurnView(frame:container.bounds)
        edges.autoresizingMask = [.width,.height]
        edges.onBegin = { [weak self] forward in self?.beginEdgeDrag(forward:forward) }
        edges.onChange = { [weak self] progress in
            guard let self, var drag = self.edgeDrag else { return }
            drag.progress = progress; self.edgeDrag = drag
            self.pageCover?.preview(progress,forward:drag.forward,style:self.store?.pageTurnStyle ?? .natural)
        }
        edges.onEnd = { [weak self] progress,velocity in
            guard let self, var drag = self.edgeDrag else { return }
            drag.progress = progress
            drag.commit = ReaderMotionPolicy.commitsDrag(progress:progress,velocity:velocity)
            self.edgeDrag = drag
            if self.pageCover != nil || self.turnDuration == 0 { self.resolveEdgeDrag() }
        }
        container.addSubview(edges)
    }

    private func beginEdgeDrag(forward:Bool) {
        guard !isTurning, edgeDrag == nil, (forward ? canGoForward:canGoBack),
              let container = attachedContainer else { return }
        let token = UUID(); edgeDrag = (token,forward,0,nil)
        guard turnDuration > 0 else { return }
        if let webView {
            let configuration = WKSnapshotConfiguration(); configuration.rect = webView.bounds
            webView.takeSnapshot(with:configuration) { [weak self,weak container] image,_ in
                MainActor.assumeIsolated {
                    guard let self, let container, let drag = self.edgeDrag, drag.id == token else { return }
                    self.installCover(image,in:container)
                    self.pageCover?.preview(drag.progress,forward:drag.forward,style:self.store?.pageTurnStyle ?? .natural)
                    if drag.commit != nil { self.resolveEdgeDrag() }
                }
            }
        } else if let view = pdfView {
            var image:NSImage?
            if let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                view.cacheDisplay(in:view.bounds,to:bitmap)
                let picture = NSImage(size:view.bounds.size); picture.addRepresentation(bitmap); image = picture
            }
            installCover(image,in:container)
            pageCover?.preview(0,forward:forward,style:store?.pageTurnStyle ?? .natural)
        }
    }

    private func resolveEdgeDrag() {
        guard let drag = edgeDrag, let commit = drag.commit else { return }
        edgeDrag = nil
        if commit { move(drag.forward ? 1:-1) }
        else if let cover = pageCover {
            isTurning = true
            cover.cancel { [weak self,weak cover] in
                guard let self, self.pageCover === cover else { return }
                self.pageCover = nil; self.isTurning = false; self.drainQueuedMove()
            }
        }
    }

    private func navigate(to index: Int, offset: Double) {
        guard !isTurning, chapters.indices.contains(index), let view = webView, let container = attachedContainer else { return }
        isTurning = true
        let token = UUID(); navigationID = token
        pendingForward = index >= chapterIndex
        recoveryChapter = chapterIndex
        recoveryOffset = store?.selectedBook?.readerOffset ?? 0
        recoveryAnchor = currentTextAnchor
        isRecovering = false
        armNavigationDeadline(token)
        if pageCover != nil || turnDuration == 0 {
            if pageCover == nil { installCover(nil,in:container) }
            chapterIndex = index; bookmarkOffset = offset
            do { try loadChapter() } catch { failNavigation(error) }
            return
        }
        let configuration = WKSnapshotConfiguration(); configuration.rect = view.bounds
        view.takeSnapshot(with:configuration) { [weak self, weak view, weak container] image, _ in
            MainActor.assumeIsolated {
                guard let self, let view, let container, self.navigationID == token, self.webView === view else { return }
                self.installCover(image, in:container)
                self.chapterIndex = index; self.bookmarkOffset = offset
                do { try self.loadChapter() } catch { self.failNavigation(error) }
            }
        }
    }

    private func failNavigation(_ error: Error) {
        DiagnosticManager.shared.record(.bookLoadFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)])
        DiagnosticManager.shared.cancel(.bookLoad)
        pendingOutline = nil
        edgeDrag = nil; queuedMove = nil
        navigationDeadline?.cancel(); navigationDeadline = nil
        webView?.stopLoading()
        store?.error = "章节未能加载：" + error.localizedDescription
        if !isRecovering, let previous = recoveryChapter {
            isRecovering = true
            chapterIndex = previous; bookmarkOffset = recoveryOffset; bookmarkAnchor = recoveryAnchor
            navigationID = UUID()
            do { try loadChapter(); return } catch { store?.error = error.localizedDescription }
        }
        isTurning = false
        // Keep the last page visible rather than exposing an empty WebKit surface.
    }

    func captureAIContext(selection:String? = nil,completion:@escaping (AIReadingContext?) -> Void) {
        guard let store, let book = store.selectedBook else { completion(nil); return }
        let context = AIReadingContext(bookID:book.id,title:book.title,author:book.author,chapter:currentChapterTitle.isEmpty ? location:currentChapterTitle,selectedText:selection ?? "")
        if let view = pdfView {
            var context = context
            context.selectedText = selection ?? view.currentSelection?.string ?? ""
            context.visibleText = String((view.currentPage?.string ?? "").prefix(6000))
            completion(context)
        } else if let view = webView, webReady {
            let id = book.id
            view.evaluateJavaScript("window.Luma?.readingContext()",in:nil,in:world) { [weak self] result in
                MainActor.assumeIsolated {
                    guard self?.bookID == id else { completion(nil); return }
                    var context = context
                    if case .success(let value) = result, let value = value as? [String:Any] {
                        context.visibleText = String((value["visibleText"] as? String ?? "").prefix(6000))
                        context.selectedText = selection ?? value["selection"] as? String ?? ""
                    }
                    completion(context)
                }
            }
        } else { completion(context) }
    }

    func askAI(selection:String? = nil) {
        captureAIContext(selection:selection) { [weak self] context in
            guard let self else { return }
            self.store?.ai.prepare(context)
            NotificationCenter.default.post(name:.lumaAskAI,object:nil)
        }
    }

    var selectedNoteIDs:[UUID] {
        guard let book = store?.selectedBook else { return [] }
        if let selected = htmlSelection {
            return NoteActions.webTargets(book.notes,chapter:chapterIndex,start:selected.start,end:selected.end)
        }
        if let selection, let document = pdfView?.document {
            var rects:[PageRect] = []
            for line in selection.selectionsByLine() {
                for page in line.pages {
                    let bounds = line.bounds(for:page)
                    if !bounds.isEmpty { rects.append(PageRect(page:document.index(for:page),x:bounds.minX,y:bounds.minY,width:bounds.width,height:bounds.height)) }
                }
            }
            return NoteActions.pdfTargets(book.notes,selection:rects)
        }
        return []
    }

    func cancelSelectedNotes() { removeNotes(selectedNoteIDs) }

    private func removeNotes(_ ids:[UUID]) {
        guard let bookID, !ids.isEmpty else { return }
        store?.removeNotes(ids,from:bookID,undo:undo)
        htmlSelection = nil; selection = nil; hasSelection = false; selectedQuote = ""
        pdfView?.clearSelection(); evaluate("window.Luma?.clear()")
    }

    func editNote(_ id: UUID) {
        guard store?.selectedBook?.notes.contains(where:{ $0.id == id }) == true else { return }
        store?.selectedNoteID = id
        store?.showInspector = true
    }

    private func showWebContextMenu(_ body:[String:Any]) {
        guard let view = webView, let start = body["start"] as? Int, let end = body["end"] as? Int,
              let quote = body["quote"] as? String, start >= 0, end > start, !quote.isEmpty else { return }
        htmlSelection = (start,end,quote); selectedQuote = quote; hasSelection = true
        if let raw = body["noteID"] as? String, let id = UUID(uuidString:raw), store?.selectedBook?.notes.contains(where:{ $0.id == id }) == true { menuNoteIDs = [id] }
        else { menuNoteIDs = selectedNoteIDs }
        let menu = NSMenu(); menu.autoenablesItems = false
        let copy = NSMenuItem(title:L10n.text("复制文本"),action:#selector(copyFromWebMenu),keyEquivalent:"")
        copy.image = NSImage(systemSymbolName:"doc.on.doc",accessibilityDescription:"复制文本"); copy.target = self; menu.addItem(copy)
        let edit = NSMenuItem(title:L10n.text("编辑笔记"),action:#selector(editFromWebMenu),keyEquivalent:"")
        edit.target = self; menu.addItem(edit)
        let ask = NSMenuItem(title:"AI",action:#selector(askFromWebMenu),keyEquivalent:"")
        ask.image = NSImage(systemSymbolName:"sparkles",accessibilityDescription:"问 AI")?.withSymbolConfiguration(.init(paletteColors:[NSColor(store?.accent ?? .accentColor)]))
        ask.toolTip = "询问 AI"; ask.target = self; menu.addItem(ask)
        let remove = NSMenuItem(title:L10n.text("取消标注和笔记"),action:#selector(removeFromWebMenu),keyEquivalent:"")
        remove.image = NSImage(systemSymbolName:"trash",accessibilityDescription:"取消标注和笔记")
        remove.target = self; remove.isEnabled = !menuNoteIDs.isEmpty; menu.addItem(remove)
        let x = body["x"] as? Double ?? 0, y = body["y"] as? Double ?? 0
        let point = NSPoint(x:CGFloat(x),y:view.isFlipped ? CGFloat(y):view.bounds.height-CGFloat(y))
        menu.popUp(positioning:nil,at:point,in:view)
    }
    @objc private func copyFromWebMenu() {
        let text = htmlSelection?.quote ?? selectedQuote
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text,forType:.string)
        showCopyFeedback()
    }
    private func showCopyFeedback() {
        bookmarkFeedbackTask?.cancel(); bookmarkFeedback = "已复制文本"
        bookmarkFeedbackTask = Task { [weak self] in
            do { try await Task.sleep(for:.seconds(1.4)) } catch { return }
            self?.bookmarkFeedback = ""
        }
    }
    @objc private func editFromWebMenu() {
        if let id = menuNoteIDs.first { editNote(id) }
        else if let store { highlight(store.activeInk); store.showInspector = true }
    }
    @objc private func askFromWebMenu() { askAI(selection:htmlSelection?.quote ?? selectedQuote) }
    @objc private func removeFromWebMenu() { removeNotes(menuNoteIDs); menuNoteIDs = [] }

    func searchBook(_ raw: String) {
        searchTask?.cancel()
        let query = raw.trimmingCharacters(in:.whitespacesAndNewlines)
        currentSearchQuery = query; searchError = nil
        pendingSearchHit = nil; searchResults = []
        guard !query.isEmpty else {
            isSearching = false; pdfView?.highlightedSelections = nil
            evaluate("window.Luma?.search('',-1)"); return
        }
        isSearching = true
        let requestedBook = bookID
        let chapters = self.chapters
        let existingIndex = searchIndex
        let pdfURL: URL?
        if let store, let book = store.selectedBook, book.kind == "pdf" { pdfURL = store.fileURL(book) } else { pdfURL = nil }
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for:.milliseconds(250))
                let worker = Task.detached(priority:.utility) { () throws -> ([SearchChapter],[BookSearchHit]) in
                    let index: [SearchChapter]
                    if let existingIndex { index = existingIndex }
                    else if let pdfURL {
                        guard let document = PDFDocument(url:pdfURL) else { throw ReaderFailure.message("PDF 无法读取。") }
                        index = try (0..<document.pageCount).map { page in
                            try Task.checkCancellation()
                            return SearchChapter(index:page,title:"第 \(page+1) 页",text:document.page(at:page)?.string ?? "")
                        }
                    } else { index = try BookSearchEngine.index(chapters:chapters) }
                    return (index,try BookSearchEngine.search(query,in:index))
                }
                let (index,hits) = try await withTaskCancellationHandler(operation:{ try await worker.value },onCancel:{ worker.cancel() })
                guard !Task.isCancelled, let self, self.bookID == requestedBook else { return }
                self.searchIndex = index; self.searchResults = hits; self.isSearching = false
                self.pdfView?.highlightedSelections = nil
                self.applySearchHighlight(occurrence:-1)
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; self?.isSearching = false; self?.searchError = error.localizedDescription }
        }
    }

    func rememberSearch(_ query: String) { recentSearches = RecentBookSearches.remember(query) }

    func clearRecentSearches() { RecentBookSearches.clear(); recentSearches = [] }

    func jump(to hit: BookSearchHit) {
        guard presentationReady, !isTurning, viewportToken == nil, chapters.indices.contains(hit.chapter) else { return }
        rememberReadingJump()
        rememberSearch(currentSearchQuery)
        store?.selectedNoteID = nil
        if let view = pdfView, let page = view.document?.page(at:hit.chapter), let selection = page.selection(for:hit.range) {
            selection.color = .systemYellow
            view.highlightedSelections = [selection]
            view.go(to:selection)
        } else {
            pendingSearchHit = hit
            if chapterIndex == hit.chapter { applySearchHighlight(occurrence:hit.occurrence); pendingSearchHit = nil }
            else { navigate(to:hit.chapter,offset:0) }
        }
    }

    private func applySearchHighlight(occurrence: Int) {
        guard let encoded = try? JSONEncoder().encode(currentSearchQuery), let query = String(data:encoded,encoding:.utf8) else { return }
        evaluate("window.Luma?.search(\(query),\(occurrence))")
    }

    private func deleteNote(_ id: UUID) {
        guard let bookID else { return }
        store?.remove(id,from:bookID,undo:undo)
    }

    private func loadChapter() throws {
        guard let epub, chapters.indices.contains(chapterIndex), let store else { return }
        hasSelection = false; htmlSelection = nil
        isTurning = true
        currentTextAnchor = nil; currentHeadingIndex = -1; currentHeadingID = ""
        webReady = false; lastWebAnnotations = ""; lastSettings = ""
        let chapter = chapters[chapterIndex]
        let original = try String(contentsOf: chapter.url, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: "<body\\b[^>]*>([\\s\\S]*?)</body>", options: .caseInsensitive)
        let ns = original as NSString
        let content: String
        if let match = regex.firstMatch(in: original, range: NSRange(location:0,length:ns.length)) { content = ns.substring(with:match.range(at:1)) }
        else { content = original }
        let css = try ReaderResources.text(name:"Reader",fileExtension:"css")
        // Book scripts, remote requests, frames and forms are blocked; local images remain available.
        let appearanceCSS = ":root{--paper:\(paperColor.lumaCSSHex);--text:#\(store.readingPalette(dark:usesDarkPaper).inkHex);--reader-leading:\(store.readerLineHeight);--reader-paragraph:\(store.readerParagraphSpacing)em;--reader-indent:\(store.readerIndent ? "2em":"0");--reader-size:\(store.readerSize)px;--reader-width:\(store.readerWidth)px;--reader-font:\(store.readerFontFamily.cssStack);color-scheme:\(usesDarkPaper ? "dark":"light")}"
        let customFontCSS = store.readerFontCSS(in:epub.root)
        let html = """
        <!doctype html><html data-paged data-focus="\(store.immersive)"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src file: data:; style-src 'unsafe-inline'; font-src file: data:; script-src 'none'; form-action 'none'; base-uri 'none'"><style>\(css)\n\(appearanceCSS)</style><style id="luma-custom-font">\(customFontCSS)</style></head><body><div id="luma-viewport"><main id="luma-content">\(content)</main></div><div id="luma-page-numbers" aria-hidden="true"></div></body></html>
        """
        let rendered = chapter.url.deletingLastPathComponent().appendingPathComponent(".luma-\(chapterIndex).html")
        let renderedData = Data(html.utf8)
        // Revisit an unchanged chapter without rewriting the generated HTML cache.
        if (try? Data(contentsOf:rendered)) != renderedData {
            try renderedData.write(to:rendered,options:.atomic)
        }
        webView?.loadFileURL(rendered, allowingReadAccessTo: epub.root)
        armNavigationDeadline(navigationID)
    }

    func exportPDF() {
        guard let document = pdfView?.document else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = (store?.selectedBook?.title ?? "图书") + "-含批注.pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard document.write(to: url) else { store?.error = "PDF 导出失败。"; return }
    }
}

extension ReaderController: WKScriptMessageHandler, WKNavigationDelegate {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let activeBookID = bookID, store?.selectedID == activeBookID else { return }
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        if type == "readerBlankClicked", store?.aiPanelPinned != true { store?.aiPanelVisible = false }
        if type == "contextMenu" { showWebContextMenu(body) }
        if type == "askAI", let quote = body["quote"] as? String, !quote.isEmpty { askAI(selection:quote) }
        if type == "image", let source = body["source"] as? String { previewImage(source) }
        if type == "illustration", let x = body["x"] as? Double, let y = body["y"] as? Double, let width = body["width"] as? Double, let height = body["height"] as? Double,
           [x,y,width,height].allSatisfy({ $0.isFinite }) { previewIllustration(rect:NSRect(x:x,y:y,width:width,height:height)) }
        if type == "ready" {
            webReady = true
            refreshAnnotations(); updateSettings()
            let explicitNavigation = bookmarkOffset != nil
            let anchor = bookmarkAnchor ?? (explicitNavigation ? nil:store?.selectedBook?.readerAnchor)
            bookmarkAnchor = nil
            let offset = bookmarkOffset ?? store?.selectedBook?.readerOffset ?? 0
            presentationOffset = min(1,max(0,offset.isFinite ? offset:0))
            bookmarkOffset = nil
            evaluate("window.Luma?.restore(\(offset.isFinite ? min(1,max(0,offset)) : 0),\(anchor?.json ?? "null"))")
            if let target = pendingOutline { jumpToOutline(target); pendingOutline = nil }
            if let noteID = pendingNoteID ?? store?.selectedNoteID { evaluate("window.Luma?.jump('\(noteID.uuidString)')") }; pendingNoteID = nil
            applySearchHighlight(occurrence:pendingSearchHit?.occurrence ?? -1)
            pendingSearchHit = nil
            evaluate("window.Luma?.preparePresentation('\(navigationID.uuidString)')")
        }
        if type == "painted", body["token"] as? String == navigationID.uuidString {
            initialPaperCover?.removeFromSuperview(); initialPaperCover = nil
            presentationReady = true
            DiagnosticManager.shared.finish(.bookLoad)
            location = "第 \(chapterIndex+1) / \(chapters.count) 节"
            canGoBack = webCanGoBack || chapterIndex > 0; canGoForward = webCanGoForward || chapterIndex < chapters.count-1
            if let id = bookID {
                persistReadingPosition(bookID:id)

            }
            recoveryChapter = nil
            if isRecovering { pageCover?.removeFromSuperview(); pageCover = nil; isTurning = false; isRecovering = false; navigationDeadline?.cancel() }
            else { finishTurn(forward:pendingForward) }
        }
        if type == "viewportSettled", let raw = body["token"] as? String, raw == viewportToken?.uuidString { DiagnosticManager.shared.finish(.viewport); clearViewportChange(); drainQueuedMove() }
        if type == "pagination", webReady {
            DiagnosticManager.shared.validatePagination(body)
            webCanGoBack = body["canBack"] as? Bool ?? false
            webCanGoForward = body["canForward"] as? Bool ?? false
            canGoBack = webCanGoBack || chapterIndex > 0
            canGoForward = webCanGoForward || chapterIndex < chapters.count-1
            let start = body["textStart"] as? Int, end = body["textEnd"] as? Int
            bookmarkPage = ReaderBookmarkPage(index:body["index"] as? Int ?? 0,count:body["count"] as? Int ?? 1,columns:body["columns"] as? Int ?? 1,
                                              textStart:start,textEnd:end)
            currentTextAnchor = ReaderTextAnchor(message:body["anchor"])
            currentHeadingIndex = body["headingIndex"] as? Int ?? -1
            currentHeadingID = body["headingID"] as? String ?? ""
            if let offset = body["offset"] as? Double, offset.isFinite {
                presentationOffset = min(1,max(0,offset))
                if !isTurning, let id = bookID { persistReadingPosition(bookID:id) }
            }
        }
        if type == "turn", let delta = body["delta"] as? Int, abs(delta) == 1 { move(delta) }
        if type == "deleteNote", let raw = body["id"] as? String, let id = UUID(uuidString:raw) { deleteNote(id) }
        if type == "location", webReady, !isTurning, let offset = body["offset"] as? Double, offset.isFinite, let id = bookID {
            let bounded = min(1,max(0,offset))
            let anchor = ReaderTextAnchor(message:body["anchor"])
            store?.mutate(id) { $0.readerOffset = bounded; $0.readerAnchor = anchor }
        }
        if type == "selectionCleared" { htmlSelection = nil; hasSelection = false; selectedQuote = "" }
        if type == "selection", let start = body["start"] as? Int, let end = body["end"] as? Int, let quote = body["quote"] as? String, end > start {
            htmlSelection = (start,end,quote); hasSelection = true; selectedQuote = quote
        }
        if type == "note", let raw = body["id"] as? String, let id = UUID(uuidString: raw) {
            store?.selectedNoteID = id
            if store?.immersive != true { store?.showInspector = true }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if (error as NSError).code != NSURLErrorCancelled { failNavigation(error) } }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if (error as NSError).code != NSURLErrorCancelled { failNavigation(error) } }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failNavigation(ReaderFailure.message("阅读进程已停止，正在重新加载。"))
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.navigationType == .linkActivated {
            let sameDocument = url.isFileURL && url.deletingPathExtension().lastPathComponent.hasPrefix(".luma-") && url.fragment != nil &&
                url.deletingLastPathComponent().standardizedFileURL == webView.url?.deletingLastPathComponent().standardizedFileURL
            decisionHandler(sameDocument ? .allow : .cancel); return
        }
        let allowed = url.isFileURL && epub.map { url.standardizedFileURL.path.hasPrefix($0.root.standardizedFileURL.path + "/") } == true
        decisionHandler(allowed ? .allow : .cancel)
    }
}

final class SelectablePDFView: PDFView {
    var onBlankClick:(()->Void)?
    private var blankMouseDown:(NSPoint,Bool)?
    override func mouseDown(with event:NSEvent) {
        blankMouseDown = (convert(event.locationInWindow,from:nil),!(currentSelection?.string?.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ?? true))
        super.mouseDown(with:event)
    }
    override func mouseUp(with event:NSEvent) {
        super.mouseUp(with:event)
        defer { blankMouseDown = nil }
        guard let (start,hadSelection) = blankMouseDown,!hadSelection else { return }
        let end = convert(event.locationInWindow,from:nil)
        guard hypot(end.x-start.x,end.y-start.y)<=5,
              currentSelection?.string?.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty != false,
              note(at:end) == nil else { return }
        onBlankClick?()
    }
    var onCopyText:(()->Void)?
    var onCreateNote:(()->Void)?
    var onWheelTurn: ((Int)->Void)?
    private var wheelGate = PageWheelGate()
    var onEditNote:((UUID)->Void)?
    var onDeleteNote:((UUID)->Void)?
    var onDeleteNotes:(([UUID])->Void)?
    var noteIDsForSelection:(()->[UUID])?
    var quoteForNote:((UUID)->String?)?
    var onAskAI:((String)->Void)?
    var aiIconColor:NSColor = .labelColor
    private var notePanelColor:NSColor = .controlBackgroundColor
    private var noteInkColor:NSColor = .labelColor
    private var noteGlass = false
    func setNoteAppearance(paper:NSColor,ink:NSColor,accent:NSColor,glass:Bool) {
        notePanelColor = paper; noteInkColor = ink; aiIconColor = accent; noteGlass = glass
        noteActions.layer?.backgroundColor = paper.withAlphaComponent(glass ? 0.78:1).cgColor
        noteActions.layer?.borderColor = accent.withAlphaComponent(0.22).cgColor
        noteActions.subviews.compactMap { $0 as? NSVisualEffectView }.first?.isHidden = !glass
        for (index,button) in noteActions.subviews.compactMap({ $0 as? NSButton }).enumerated() { button.contentTintColor = index == 0 ? accent:ink }
    }
    private var hoverTracking:NSTrackingArea?
    private var hoveredNoteID:UUID?
    private var hoverRegion:NSRect = .zero
    private var contextIDs:[UUID] = []
    private var contextQuote = ""
    private lazy var noteActions:NSView = {
        let panel = NSView(frame:NSRect(x:0,y:0,width:88,height:44))
        let material = NSVisualEffectView(frame:panel.bounds)
        material.autoresizingMask = [.width,.height]
        material.material = .popover; material.blendingMode = .withinWindow; material.state = .active
        material.isHidden = !noteGlass; panel.addSubview(material)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = notePanelColor.withAlphaComponent(noteGlass ? 0.78:1).cgColor
        panel.layer?.borderWidth = 0.7; panel.layer?.borderColor = aiIconColor.withAlphaComponent(0.22).cgColor
        panel.layer?.cornerRadius = 9; panel.layer?.masksToBounds = true
        let ai = NSButton(image:NSImage(systemSymbolName:"sparkles",accessibilityDescription:"问 AI")!,target:self,action:#selector(askHoveredNote))
        ai.frame = NSRect(x:0,y:0,width:44,height:44); ai.isBordered = false; ai.toolTip = "问 AI"; ai.contentTintColor = aiIconColor
        let trash = NSButton(image:NSImage(systemSymbolName:"trash",accessibilityDescription:"删除此划线与批注")!,target:self,action:#selector(deleteHoveredNote))
        trash.frame = NSRect(x:44,y:0,width:44,height:44); trash.isBordered = false; trash.contentTintColor = noteInkColor; trash.toolTip = "取消标注和笔记 · ⌘Z 撤销"
        panel.addSubview(ai); panel.addSubview(trash); panel.isHidden = true; addSubview(panel); return panel
    }()
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect:bounds,options:[.mouseMoved,.mouseEnteredAndExited,.activeInKeyWindow,.inVisibleRect],owner:self,userInfo:nil)
        addTrackingArea(area); hoverTracking = area
    }
    private func note(at point:NSPoint) -> (UUID,NSRect)? {
        guard let page = page(for:point,nearest:false) else { return nil }
        let pagePoint = convert(point,to:page)
        guard let annotation = page.annotations.reversed().first(where:{ $0.userName?.hasPrefix("Luma:") == true && $0.bounds.contains(pagePoint) }),
              let name = annotation.userName, let id = UUID(uuidString:String(name.dropFirst(5))) else { return nil }
        return (id,convert(annotation.bounds,from:page))
    }
    override func mouseMoved(with event:NSEvent) {
        let point = convert(event.locationInWindow,from:nil)
        if !noteActions.isHidden && noteActions.frame.insetBy(dx:-10,dy:-10).contains(point) { return }
        if let (id,rect) = note(at:point) {
            hoveredNoteID = id
            noteActions.frame.origin = NSPoint(x:min(max(4,rect.maxX+6),max(4,bounds.width-92)),y:min(max(4,rect.maxY+6),max(4,bounds.height-48)))
            hoverRegion = rect.union(noteActions.frame).insetBy(dx:-12,dy:-12)
            noteActions.subviews.compactMap { $0 as? NSButton }.first?.contentTintColor = aiIconColor
            noteActions.isHidden = false
        } else if !hoverRegion.contains(point) { hideActions() }
    }
    override func mouseExited(with event:NSEvent) { hideActions() }
    override func scrollWheel(with event:NSEvent) {
        hideActions()
        guard !event.modifierFlags.contains(.control), let onWheelTurn else { super.scrollWheel(with:event); return }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX:event.scrollingDeltaY
        if let direction = wheelGate.consume(delta:Double(delta),began:event.phase.contains(.began),
            momentum:!event.momentumPhase.isEmpty,phased:!event.phase.isEmpty || !event.momentumPhase.isEmpty,time:event.timestamp) { onWheelTurn(direction) }
    }
    private func hideActions() { noteActions.isHidden = true; hoveredNoteID = nil; hoverRegion = .zero }
    @objc private func deleteHoveredNote() { guard let id = hoveredNoteID else { return }; hideActions(); onDeleteNote?(id) }
    @objc private func askHoveredNote() { guard let id = hoveredNoteID, let quote = quoteForNote?(id) else { return }; hideActions(); onAskAI?(quote) }
    override func menu(for event:NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow,from:nil)
        let id = note(at:point)?.0
        contextQuote = currentSelection?.string ?? ""
        contextIDs = noteIDsForSelection?() ?? []
        if let id { contextQuote = quoteForNote?(id) ?? ""; contextIDs = [id] }
        guard !contextQuote.isEmpty else { return nil }
        let menu = NSMenu(); menu.autoenablesItems = false
        let ask = NSMenuItem(title:"AI",action:#selector(askAIFromMenu),keyEquivalent:"")
        ask.image = NSImage(systemSymbolName:"sparkles",accessibilityDescription:"问 AI")?.withSymbolConfiguration(.init(paletteColors:[aiIconColor])); ask.target = self
        let remove = NSMenuItem(title:L10n.text("取消标注和笔记"),action:#selector(removeNotesFromMenu),keyEquivalent:"")
        remove.image = NSImage(systemSymbolName:"trash",accessibilityDescription:"取消标注和笔记"); remove.target = self; remove.isEnabled = !contextIDs.isEmpty
        let edit = NSMenuItem(title:L10n.text("编辑笔记"),action:#selector(editNoteFromMenu),keyEquivalent:"")
        edit.target = self; edit.isEnabled = true
        let copy = NSMenuItem(title:L10n.text("复制文本"),action:#selector(copyTextFromMenu),keyEquivalent:"")
        copy.image = NSImage(systemSymbolName:"doc.on.doc",accessibilityDescription:"复制文本"); copy.target = self
        menu.addItem(copy); menu.addItem(edit); menu.addItem(ask); menu.addItem(remove); return menu
    }
    @objc private func copyTextFromMenu() {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(contextQuote,forType:.string); onCopyText?()
    }
    @objc private func editNoteFromMenu() { if let id = contextIDs.first { onEditNote?(id) } else { onCreateNote?() } }
    @objc private func askAIFromMenu() { onAskAI?(contextQuote) }
    @objc private func removeNotesFromMenu() { onDeleteNotes?(contextIDs); contextIDs = [] }
}

struct ReaderSurface: NSViewRepresentable {
    let book: Book
    let store: LibraryStore
    let controller: ReaderController
    let undo: UndoManager?
    func makeNSView(context: Context) -> NSView {
        let view = ReadingContainerView()
        view.onWindowChange = { [weak activity = store.activity] window in activity?.setReadingWindow(window) }
        return view
    }
    func makeCoordinator() -> Coordinator { Coordinator(controller:controller) }
    func updateNSView(_ nsView:NSView,context:Context) { controller.attach(to:nsView,book:book,store:store,undo:undo) }
    static func dismantleNSView(_ view:NSView,coordinator:Coordinator) { coordinator.controller.detach(from:view) }
    @MainActor final class Coordinator {
        let controller:ReaderController
        init(controller:ReaderController) { self.controller = controller }
    }
}

private final class ReadingContainerView: NSView {
    var onWindowChange:((NSWindow?)->Void)?
    override func resizeSubviews(withOldSize oldSize:NSSize) {
        // Native autoresizing is synchronous. The previous timer left an exposed, stale frame for 120 ms.
        super.resizeSubviews(withOldSize:oldSize)
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); onWindowChange?(window) }
}

private enum ReaderResources {
    static func text(name:String,fileExtension ext:String) throws -> String {
        guard let url = AppResources.url(forResource:name,withExtension:ext) else {
            throw ReaderFailure.message("阅读界面资源缺失，请重新安装完整程序。")
        }
        return try String(contentsOf:url,encoding:.utf8)
    }
}


private extension NSColor {
    var lumaCSSHex: String {
        let rgb = usingColorSpace(.sRGB) ?? .black
        return String(format:"#%02X%02X%02X",Int(rgb.redComponent*255),Int(rgb.greenComponent*255),Int(rgb.blueComponent*255))
    }
}

