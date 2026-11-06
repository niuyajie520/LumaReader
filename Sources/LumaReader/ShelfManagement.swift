import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShelfBookPreferences: Codable, Equatable, Sendable {
    var isRead: Bool?
    var wantRead = false
    var coverStyle: String?
    var removed = false
    var modifiedAt = Date()
}
extension Book {
    var isFinished: Bool { shelf?.isRead ?? (progress >= 1) }
}
extension LibraryStore {
    var shelfBooks: [Book] { books.filter { $0.shelf?.removed != true } }
    func editShelf(_ id: UUID, _ edit: (inout ShelfBookPreferences) -> Void) {
        mutate(id) { book in
            var value = book.shelf ?? ShelfBookPreferences()
            edit(&value); value.modifiedAt = Date(); book.shelf = value
        }
    }
    private func localShelfURL(_ book:Book) -> URL? {
        let directory = root.appendingPathComponent("Books").resolvingSymlinksInPath().standardizedFileURL
        let url = directory.appendingPathComponent(book.filename).resolvingSymlinksInPath().standardizedFileURL
        guard !book.filename.contains("/"), !book.filename.contains("\\"),
              url.deletingLastPathComponent() == directory else { return nil }
        return url
    }
    func shareBook(_ book: Book) {
        guard let url = localShelfURL(book) else { error = "图书文件路径无效。"; return }
        guard FileManager.default.isReadableFile(atPath:url.path) else { error = "文件尚未下载、已移除或没有读取权限，请先同步。"; return }
        guard let view = NSApp.keyWindow?.contentView else { error = "没有可用的分享窗口。"; return }
        NSSharingServicePicker(items:[url]).show(relativeTo:CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1),of:view,preferredEdge:.minY)
    }
    func removeFromShelf(_ book: Book) {
        editShelf(book.id) { $0.removed = true }
        if selectedID == book.id { returnToLibrary() }
    }
    func deleteLocalDownload(_ book: Book) {
        let alert = NSAlert(); alert.alertStyle = .warning
        alert.messageText = L10n.text("删除本地下载？")
        alert.informativeText = L10n.text("仅将 Luma 内的本地图书副本移到废纸篓，保留书签、笔记和云端原文件。同步后可能重新下载。")
        alert.addButton(withTitle:L10n.text("取消")); alert.addButton(withTitle:L10n.text("删除本地下载"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        guard let url = localShelfURL(book) else { error = "图书文件路径无效。"; return }
        guard FileManager.default.fileExists(atPath:url.path) else { error = "本地下载不存在。"; return }
        if selectedID == book.id { returnToLibrary() }
        do { try FileManager.default.trashItem(at:url,resultingItemURL:nil) } catch { self.error = error.localizedDescription }
    }
    func acceptBookDrop(_ values: [String], groupID: UUID) -> Bool {
        let ids = values.compactMap { value -> UUID? in
            guard value.hasPrefix("luma-book:") else { return nil }; return UUID(uuidString:String(value.dropFirst(10)))
        }
        guard !ids.isEmpty else { return false }
        for id in ids where shelfBooks.contains(where: { $0.id == id }) { collections.set(book:id,in:groupID,included:true) }
        flushShelfGroups()
        return true
    }
    func acceptFileDrop(_ providers: [NSItemProvider], groupID: UUID? = nil) -> Bool {
        let files = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !files.isEmpty else { return false }
        Task {
            var urls: [URL] = []
            for provider in files {
                let data: Data? = await withCheckedContinuation { continuation in
                    provider.loadDataRepresentation(forTypeIdentifier:UTType.fileURL.identifier) { data,_ in continuation.resume(returning:data) }
                }
                guard let data, let url = URL(dataRepresentation:data,relativeTo:nil) else { error = "拖入的文件地址无法读取。"; continue }
                guard ["epub","pdf"].contains(url.pathExtension.lowercased()) else { error = "仅支持 EPUB 和 PDF 文件。"; continue }
                urls.append(url)
            }
            _ = await importFiles(urls,provider:nil,groupID:groupID)
        }
        return true
    }
}

struct ShelfSettings: View {
    @Bindable var store: LibraryStore
    @State private var bookID: UUID?
    var body: some View {
        Section(L10n.text("书库与管理")) {
            Picker(L10n.text("封面显示样式"),selection:$store.shelfCoverStyle) {
                Text(L10n.text("莫奈风格")).tag("monet"); Text(L10n.text("原始封面")).tag("original")
            }
            LabeledContent(L10n.text("书架卡片大小")) { Slider(value:$store.shelfCardWidth,in:145...215,step:5) }
            Picker(L10n.text("单本书封面"),selection:$bookID) {
                Text(L10n.text("选择图书")).tag(nil as UUID?)
                ForEach(store.shelfBooks) { book in Text(book.title).tag(Optional(book.id)) }
            }
            if let id = bookID, let book = store.shelfBooks.first(where: { $0.id == id }) {
                Picker(L10n.text("封面显示样式"),selection:Binding(get:{ book.shelf?.coverStyle ?? "global" },set:{ value in store.editShelf(id) { $0.coverStyle = value == "global" ? nil:value } })) {
                    Text(L10n.text("跟随全局设置")).tag("global"); Text(L10n.text("莫奈风格")).tag("monet"); Text(L10n.text("原始封面")).tag("original")
                }
            }
        }
    }
}

struct PageMotionPicker: View {
    @Bindable var store: LibraryStore
    var body: some View {
        Picker(L10n.text("翻页动画模式"),selection:$store.pageMotionMode) {
            Text(L10n.text("原有翻页（默认）")).tag("original")
            Text(L10n.text("3D 纸张卷曲（待原生验收）")).tag("curl3D")
            Text(L10n.text("无动画")).tag("none")
        }
        if store.pageMotionMode == "curl3D" {
            Text(L10n.text("3D 卷页尚未通过原生验收，阅读器继续使用原有翻页。独立实验位于包内 Experiments/PageCurlLab.html。"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
