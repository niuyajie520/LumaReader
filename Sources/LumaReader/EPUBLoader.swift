import Foundation
#if !os(macOS) && canImport(FoundationXML)
import FoundationXML
#endif
import ZIPFoundation

struct EPUBContent {
    var title: String
    var author: String
    var root: URL
    var chapters: [Chapter]
    var coverURL: URL? = nil
    var outline: [ReadingOutlineItem] = []
}

// Extraction is bounded and rejects symlinks and paths outside the book cache.
enum EPUBLoader {
    static func load(file: URL, cache: URL) throws -> EPUBContent {
        let root = cache.appendingPathComponent(file.deletingPathExtension().lastPathComponent, isDirectory: true)
        let lock = EPUBCacheLocks.shared.forPath(root.standardizedFileURL.path)
        lock.lock(); defer { lock.unlock() }
        let marker = root.appendingPathComponent(".complete")
        if !FileManager.default.fileExists(atPath: marker.path) {
            if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            do {
                let archive = try Archive(url: file, accessMode: .read)
                var total: UInt64 = 0
                var count = 0
                for entry in archive {
                    count += 1
                    total += UInt64(entry.uncompressedSize)
                    guard count <= 10000, total <= 200 * 1024 * 1024, entry.type != .symlink else {
                        throw ReaderFailure.message("这本 EPUB 太大，或包含不支持的链接文件。")
                    }
                    let destination = try contained(entry.path, in: root)
                    let checksum = try archive.extract(entry, to: destination)
                    guard checksum == entry.checksum else { throw ReaderFailure.message("EPUB 文件校验失败。") }
                }
                try Data().write(to: marker)
            } catch {
                try? FileManager.default.removeItem(at: root)
                throw error
            }
        }
        let containerURL = root.appendingPathComponent("META-INF/container.xml")
        let container = try parse(containerURL)
        guard let opfPath = container.opfPath else { throw ReaderFailure.message("EPUB 缺少书籍目录。") }
        let opfURL = try contained(opfPath, in: root)
        let metadata = try parse(opfURL)
        var chapterTitles: [String:String] = [:]
        var navigation: EPUBNavigationParser?
        if let navigationPath = metadata.navigationPath {
            let decoded = navigationPath.removingPercentEncoding ?? navigationPath
            let navigationURL = opfURL.deletingLastPathComponent().appendingPathComponent(decoded).standardizedFileURL
            if navigationURL.path.hasPrefix(root.standardizedFileURL.path + "/"), let data = try? Data(contentsOf:navigationURL) {
                let delegate = EPUBNavigationParser(base:navigationURL.deletingLastPathComponent(),root:root)
                let parser = XMLParser(data:data); parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false; parser.delegate = delegate
                if parser.parse() { chapterTitles = delegate.titles; navigation = delegate }
            }
        }
        var chapters: [Chapter] = []
        for id in metadata.spine {
            guard let item = metadata.items[id], item.media == "application/xhtml+xml" || item.media == "text/html" else { continue }
            let decoded = item.href.removingPercentEncoding ?? item.href
            let url = opfURL.deletingLastPathComponent().appendingPathComponent(decoded).standardizedFileURL
            guard url.path.hasPrefix(root.standardizedFileURL.path + "/"), FileManager.default.fileExists(atPath: url.path) else {
                throw ReaderFailure.message("EPUB 的章节路径无效。")
            }
            chapters.append(Chapter(id: chapters.count, title: chapterTitles[url.path] ?? "第 \(chapters.count + 1) 节", url: url))
        }
        guard !chapters.isEmpty else { throw ReaderFailure.message("没有找到可阅读的 EPUB 章节；不支持 DRM 加密书籍。") }
        var coverURL: URL?
        if let id = metadata.coverID, let item = metadata.items[id] {
            let url = opfURL.deletingLastPathComponent().appendingPathComponent(item.href.removingPercentEncoding ?? item.href).standardizedFileURL
            if url.path.hasPrefix(root.standardizedFileURL.path+"/"), FileManager.default.fileExists(atPath:url.path) { coverURL = url }
        }
        var outline = navigation?.outline(chapters:chapters) ?? []
        var headingCache: [Int:[ReadingOutlineItem]] = [:]
        func headings(_ index: Int) -> [ReadingOutlineItem] {
            if let cached = headingCache[index] { return cached }
            let result = EPUBHeadingParser.outline(chapter:chapters[index]); headingCache[index] = result; return result
        }
        func enrich(_ items: [ReadingOutlineItem]) -> [ReadingOutlineItem] {
            items.map { item in
                var node = item
                if node.children.isEmpty, node.fragment == nil, let index = node.chapterIndex {
                    var children = headings(index)
                    if children.count == 1, children[0].title == node.title { children = children[0].children }
                    node.children = children
                } else { node.children = enrich(node.children) }
                return node
            }
        }
        if outline.isEmpty { outline = chapters.map { ReadingOutlineItem(id:"chapter/\($0.id)",title:$0.title,chapterIndex:$0.id,children:headings($0.id)) } }
        else { outline = enrich(outline) }
        return EPUBContent(title: metadata.title, author: metadata.author, root: root, chapters: chapters, coverURL:coverURL,outline:outline)
    }

    static func contained(_ path: String, in root: URL) throws -> URL {
        guard !path.hasPrefix("/"), !path.contains("\\"), !path.split(separator: "/").contains("..") else {
            throw ReaderFailure.message("EPUB 包含无效路径。")
        }
        let url = root.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path + "/") else { throw ReaderFailure.message("EPUB 路径越界。") }
        return url
    }

    private static func parse(_ url: URL) throws -> OPFParser {
        let delegate = OPFParser()
        let parser = XMLParser(data: try Data(contentsOf: url))
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? ReaderFailure.message("EPUB 目录解析失败。") }
        return delegate
    }
}

private final class OPFParser: NSObject, XMLParserDelegate {
    var opfPath: String?
    var navigationPath: String?
    var coverID: String?
    var title = ""
    var author = ""
    var items: [String: (href: String, media: String)] = [:]
    var spine: [String] = []
    private var capture: String?
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "meta", attributes["name"] == "cover" { coverID = attributes["content"] }
        if name == "rootfile" { opfPath = attributes["full-path"] }
        if name == "item", let id = attributes["id"], let href = attributes["href"] {
            items[id] = (href, attributes["media-type"] ?? "")
            if (attributes["properties"] ?? "").split(separator:" ").contains("cover-image") { coverID = id }
            if (attributes["properties"] ?? "").split(separator:" ").contains("nav") { navigationPath = href }
            else if navigationPath == nil && attributes["media-type"] == "application/x-dtbncx+xml" { navigationPath = href }
        }
        if name == "itemref", attributes["linear"] != "no", let id = attributes["idref"] { spine.append(id) }
        if name == "title" || name == "creator" { capture = name }
    }
    func parser(_ parser: XMLParser, foundCharacters text: String) {
        if capture == "title" { title += text }
        if capture == "creator" { author += text }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == capture { capture = nil }
    }
}


private final class EPUBCacheLocks: @unchecked Sendable {
    static let shared = EPUBCacheLocks()
    private let gate = NSLock()
    private var entries: [String:NSLock] = [:]
    func forPath(_ path:String) -> NSLock {
        gate.lock(); defer { gate.unlock() }
        if let existing = entries[path] { return existing }
        let lock = NSLock(); entries[path] = lock; return lock
    }
}
