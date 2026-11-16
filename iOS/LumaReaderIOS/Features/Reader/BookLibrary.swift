import Foundation
import Observation

struct Book: Identifiable, Hashable {
    let id: String
    var title: String
    var author: String
    var chapters: [Chapter]
    var addedAt: Date
    var progress: Double

    // 书目身份只由 id 决定，避免把整章 HTML 参与哈希。
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Chapter: Identifiable, Hashable {
    let id: String
    var title: String
    var html: String
}

enum BookImportError: LocalizedError {
    case unreadableFile
    case unsupportedFormat
    case invalidEPUB(String)
    case archiveFailed(String)
    case emptyBook

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "无法读取这个文件，请确认文件没有被移动或加密。"
        case .unsupportedFormat:
            return "不支持这种文件格式，请导入 EPUB、ZIP、TXT、Markdown 或 HTML 文件。"
        case .invalidEPUB(let reason):
            return reason
        case .archiveFailed(let reason):
            return "压缩包解析失败：\(reason)"
        case .emptyBook:
            return "这个文件里没有可以阅读的文字。"
        }
    }
}

@Observable
final class BookLibrary {

    private(set) var books: [Book] = []
    private(set) var lastError: String?

    let booksRoot: URL

    init(booksRoot: URL = BookLibrary.defaultBooksRoot()) {
        self.booksRoot = booksRoot
        do {
            try load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func defaultBooksRoot() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Books", isDirectory: true)
    }

    var indexURL: URL {
        booksRoot.appendingPathComponent("books.json", isDirectory: false)
    }

    func bookDirectory(for bookID: String) -> URL {
        booksRoot.appendingPathComponent(bookID, isDirectory: true)
    }

    // MARK: - 读取与持久化

    func load() throws {
        try FileManager.default.createDirectory(at: booksRoot, withIntermediateDirectories: true)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: indexURL),
           let entries = try? decoder.decode([LibraryIndexEntry].self, from: data) {
            var restored: [Book] = []
            for entry in entries {
                if let book = loadBook(id: entry.id, fallback: entry) {
                    restored.append(book)
                }
            }
            books = restored
            try saveIndex()
            return
        }

        books = loadFromDirectories(decoder: decoder)
        try saveIndex()
    }

    private func loadBook(id: String, fallback: LibraryIndexEntry?) -> Book? {
        let directory = bookDirectory(for: id)
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("book.json")) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode(StoredBook.self, from: data) else { return nil }

        var chapters: [Chapter] = []
        for (index, meta) in stored.chapters.enumerated() {
            guard let fileURL = safeChild(meta.file, in: directory),
                  let html = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            chapters.append(Chapter(id: meta.id.isEmpty ? "ch-\(index)" : meta.id,
                                    title: meta.title.isEmpty ? "第 \(index + 1) 章" : meta.title,
                                    html: html))
        }
        guard !chapters.isEmpty else { return nil }

        let progress = min(max(fallback?.progress ?? 0, 0), 1)
        return Book(id: stored.id.isEmpty ? id : stored.id,
                    title: stored.title.isEmpty ? (fallback?.title ?? "未命名书籍") : stored.title,
                    author: stored.author,
                    chapters: chapters,
                    addedAt: stored.addedAt,
                    progress: progress)
    }

    private func loadFromDirectories(decoder: JSONDecoder) -> [Book] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: booksRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [Book] = []
        for url in contents {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }
            if let book = loadBook(id: url.lastPathComponent, fallback: nil) {
                result.append(book)
            }
        }
        return result.sorted { $0.addedAt > $1.addedAt }
    }

    private func saveIndex() throws {
        let entries = books.map {
            LibraryIndexEntry(id: $0.id,
                              title: $0.title,
                              author: $0.author,
                              addedAt: $0.addedAt,
                              progress: $0.progress)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        try FileManager.default.createDirectory(at: booksRoot, withIntermediateDirectories: true)
        try data.write(to: indexURL, options: .atomic)
    }

    private func write(book: Book, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var storedChapters: [StoredChapter] = []
        for (index, chapter) in book.chapters.enumerated() {
            let fileName = "ch-\(index).html"
            let fileURL = directory.appendingPathComponent(fileName)
            try Data(chapter.html.utf8).write(to: fileURL, options: .atomic)
            storedChapters.append(StoredChapter(id: chapter.id,
                                                title: chapter.title,
                                                file: fileName))
        }

        let stored = StoredBook(id: book.id,
                                title: book.title,
                                author: book.author,
                                addedAt: book.addedAt,
                                chapters: storedChapters)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stored)
        try data.write(to: directory.appendingPathComponent("book.json"), options: .atomic)
    }

    private func safeChild(_ relativePath: String, in directory: URL) -> URL? {
        let base = directory.standardizedFileURL
        let candidate = directory.appendingPathComponent(relativePath).standardizedFileURL
        guard candidate.path == base.path || candidate.path.hasPrefix(base.path + "/") else {
            return nil
        }
        return candidate
    }

    // MARK: - 导入

    @discardableResult
    func importBook(from url: URL) throws -> Book {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw BookImportError.unreadableFile
        }

        let displayName = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension.lowercased()
        let bookID = Self.makeBookID()
        let directory = bookDirectory(for: bookID)
        var createdDirectory = false

        do {
            let imported: ImportedBook
            if Self.isZipArchive(data) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                createdDirectory = true
                imported = try importArchive(data: data, displayName: displayName, directory: directory)
            } else {
                imported = try importStandalone(data: data,
                                                pathExtension: pathExtension,
                                                displayName: displayName)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                createdDirectory = true
            }

            let book = Book(id: bookID,
                            title: imported.title,
                            author: imported.author,
                            chapters: imported.chapters,
                            addedAt: Date(),
                            progress: 0)
            try write(book: book, to: directory)
            books.insert(book, at: 0)
            do {
                try saveIndex()
            } catch {
                books.removeAll { $0.id == bookID }
                throw error
            }
            lastError = nil
            return book
        } catch {
            if createdDirectory {
                try? FileManager.default.removeItem(at: directory)
            }
            throw error
        }
    }

    private func importArchive(data: Data, displayName: String, directory: URL) throws -> ImportedBook {
        let entries: [String: Data]
        do {
            entries = try MiniZip.unzip(data)
        } catch {
            throw BookImportError.archiveFailed(error.localizedDescription)
        }

        let looksLikeEPUB = entries.keys.contains { $0.lowercased() == "meta-inf/container.xml" }
            || entries.keys.contains { $0.lowercased().hasSuffix(".opf") }
        guard looksLikeEPUB else {
            throw BookImportError.invalidEPUB("这个压缩包里没有 EPUB 书籍目录，无法作为电子书导入。")
        }

        try extract(entries: entries, to: directory)
        return try parseEPUB(entries: entries, root: directory, displayName: displayName)
    }

    private func importStandalone(data: Data, pathExtension: String, displayName: String) throws -> ImportedBook {
        let textExtensions: Set<String> = ["txt", "text", "md", "markdown", "html", "htm", "xhtml"]
        guard textExtensions.contains(pathExtension) else {
            throw BookImportError.unsupportedFormat
        }
        guard let text = decodeString(data) else {
            throw BookImportError.unsupportedFormat
        }
        let fallbackName = displayName.isEmpty ? "未命名书籍" : displayName
        let isHTML = ["html", "htm", "xhtml"].contains(pathExtension)
        let html = isHTML ? sanitizeChapter(text) : paragraphHTML(from: text)
        guard !plainText(from: html).isEmpty else {
            throw BookImportError.emptyBook
        }

        var title = fallbackName
        if isHTML,
           let pageTitle = firstCapture(#"<title\b[^>]*>([\s\S]*?)</title>"#, in: text) {
            let cleaned = plainText(from: pageTitle)
            if !cleaned.isEmpty {
                title = cleaned
            }
        }

        return ImportedBook(title: title,
                            author: "",
                            chapters: [Chapter(id: "ch-0", title: title, html: html)])
    }

    private func extract(entries: [String: Data], to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = directory.standardizedFileURL
        for (path, data) in entries {
            let target = directory.appendingPathComponent(path).standardizedFileURL
            guard target.path == base.path || target.path.hasPrefix(base.path + "/") else {
                continue
            }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
        }
    }

    // MARK: - EPUB 解析

    private func parseEPUB(entries: [String: Data], root: URL, displayName: String) throws -> ImportedBook {
        let containerText: String? = findEntry(named: "META-INF/container.xml", in: entries)
            .flatMap { key in
                guard let data = entries[key] else { return nil }
                return decodeString(data)
            }

        var opfPath = containerText.flatMap {
            firstCapture(#"<rootfile\b[^>]*\bfull-path\s*=\s*["']([^"']+)["']"#, in: $0)
        }
        if opfPath == nil {
            opfPath = entries.keys
                .filter { $0.lowercased().hasSuffix(".opf") }
                .sorted { $0.count < $1.count }
                .first
        }
        guard var opfPath else {
            throw BookImportError.invalidEPUB("没有找到 EPUB 的书籍目录文件，无法读取章节。")
        }
        if let decoded = opfPath.removingPercentEncoding {
            opfPath = decoded
        }
        opfPath = Self.normalizePath(opfPath)

        guard let opfKey = findEntry(named: opfPath, in: entries),
              let opfData = entries[opfKey],
              let opfText = decodeString(opfData) else {
            throw BookImportError.invalidEPUB("EPUB 的书籍目录文件无法读取。")
        }

        let metadataTitle = firstCapture(#"<(?:\w+:)?title\b[^>]*>([\s\S]*?)</(?:\w+:)?title>"#, in: opfText)
            .map { plainText(from: $0) } ?? ""
        let metadataCreator = firstCapture(#"<(?:\w+:)?creator\b[^>]*>([\s\S]*?)</(?:\w+:)?creator>"#, in: opfText)
            .map { plainText(from: $0) } ?? ""

        var manifest: [String: ManifestItem] = [:]
        var orderedItems: [ManifestItem] = []
        for tag in matches(#"<item\b([^>]*?)/?>"#, in: opfText) {
            guard let id = attribute("id", in: tag),
                  let href = attribute("href", in: tag) else {
                continue
            }
            let item = ManifestItem(id: id,
                                    href: href,
                                    mediaType: (attribute("media-type", in: tag) ?? "").lowercased(),
                                    properties: (attribute("properties", in: tag) ?? "").lowercased())
            manifest[id] = item
            orderedItems.append(item)
        }

        var spineIDs: [String] = []
        for tag in matches(#"<itemref\b([^>]*?)/?>"#, in: opfText) {
            guard let idref = attribute("idref", in: tag) else { continue }
            if attribute("linear", in: tag)?.lowercased() == "no" { continue }
            spineIDs.append(idref)
        }

        var chosen: [ManifestItem] = []
        if !spineIDs.isEmpty {
            chosen = spineIDs.compactMap { manifest[$0] }.filter(isReadableChapter)
        } else {
            chosen = orderedItems.filter {
                isReadableChapter($0) && !$0.properties.split(separator: " ").contains(where: { $0 == "nav" })
            }
        }

        guard !chosen.isEmpty else {
            throw BookImportError.invalidEPUB("没有找到可阅读的 EPUB 章节，暂不支持 DRM 加密书籍。")
        }

        let baseDirectory = Self.normalizePath((opfKey as NSString).deletingLastPathComponent)
        var chapters: [Chapter] = []
        var seen: Set<String> = []

        for item in chosen {
            guard let entryKey = resolveEntry(href: item.href, relativeTo: baseDirectory, entries: entries),
                  !seen.contains(entryKey),
                  let entryData = entries[entryKey],
                  let rawHTML = decodeString(entryData) else {
                continue
            }
            seen.insert(entryKey)

            let chapterHTML = sanitizeChapter(rawHTML)
            guard !plainText(from: chapterHTML).isEmpty else { continue }

            let title = chapterTitle(from: chapterHTML) ?? "第 \(chapters.count + 1) 章"
            let rewritten = rewriteAssetReferences(in: chapterHTML,
                                                   chapterPath: entryKey,
                                                   entries: entries,
                                                   root: root)
            chapters.append(Chapter(id: "ch-\(chapters.count)", title: title, html: rewritten))
        }

        guard !chapters.isEmpty else {
            throw BookImportError.invalidEPUB("没有找到可阅读的 EPUB 章节，暂不支持 DRM 加密书籍。")
        }

        let title: String
        if !metadataTitle.isEmpty {
            title = metadataTitle
        } else if !displayName.isEmpty {
            title = displayName
        } else {
            title = "未命名书籍"
        }

        return ImportedBook(title: title, author: metadataCreator, chapters: chapters)
    }

    private func isReadableChapter(_ item: ManifestItem) -> Bool {
        if item.mediaType == "application/xhtml+xml" || item.mediaType == "text/html" {
            return true
        }
        let ext = (item.href as NSString).pathExtension.lowercased()
        return ["xhtml", "html", "htm"].contains(ext)
    }

    private func sanitizeChapter(_ html: String) -> String {
        var content = firstCapture(#"<body\b[^>]*>([\s\S]*?)</body>"#, in: html) ?? html
        content = replacing(#"<script\b[^>]*>[\s\S]*?</script>"#, in: content, with: "")
        content = replacing(#"<style\b[^>]*>[\s\S]*?</style>"#, in: content, with: "")
        content = replacing(#"\son[a-z]+\s*=\s*("[^"]*"|'[^']*')"#, in: content, with: "")
        content = replacing(#"(href|src)\s*=\s*(["'])\s*javascript:[^"']*\2"#, in: content, with: "")
        return content
    }

    private func chapterTitle(from html: String) -> String? {
        guard let heading = firstCapture(#"<h[1-3]\b[^>]*>([\s\S]*?)</h[1-3]>"#, in: html) else {
            return nil
        }
        let title = plainText(from: heading)
        guard !title.isEmpty else { return nil }
        return String(title.prefix(48))
    }

    // MARK: - 资源路径

    private func rewriteAssetReferences(in content: String,
                                        chapterPath: String,
                                        entries: [String: Data],
                                        root: URL) -> String {
        let chapterBase = Self.normalizePath((chapterPath as NSString).deletingLastPathComponent)
        let tagPattern = #"<(?:img|image|source|video|audio|track|embed|object)\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive]) else {
            return content
        }

        let original = content as NSString
        let found = regex.matches(in: content, range: NSRange(location: 0, length: original.length))
        var result = original
        for match in found.reversed() {
            let tag = original.substring(with: match.range)
            let rewritten = rewriteTag(tag, chapterBase: chapterBase, entries: entries, root: root)
            result = result.replacingCharacters(in: match.range, with: rewritten) as NSString
        }
        return result as String
    }

    private func rewriteTag(_ tag: String,
                            chapterBase: String,
                            entries: [String: Data],
                            root: URL) -> String {
        let pattern = #"(src|xlink:href|href|poster)\s*=\s*(["'])([^"']+)\2"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return tag
        }

        let original = tag as NSString
        let found = regex.matches(in: tag, range: NSRange(location: 0, length: original.length))
        var result = original
        for match in found.reversed() {
            let name = original.substring(with: match.range(at: 1))
            let value = original.substring(with: match.range(at: 3))
            let lower = value.lowercased()
            if lower.hasPrefix("data:") || lower.hasPrefix("http://") || lower.hasPrefix("https://") || value.hasPrefix("#") {
                continue
            }
            guard let entryKey = resolveAsset(value, chapterBase: chapterBase, entries: entries) else {
                continue
            }

            var fileURL = root
            for component in entryKey.split(separator: "/") {
                fileURL.appendPathComponent(String(component))
            }
            let replacement = "\(name)=\"\(escapeAttribute(fileURL.standardizedFileURL.absoluteString))\""
            result = result.replacingCharacters(in: match.range, with: replacement) as NSString
        }
        return result as String
    }

    private func resolveAsset(_ rawValue: String, chapterBase: String, entries: [String: Data]) -> String? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hashIndex = value.firstIndex(of: "#") {
            value = String(value[..<hashIndex])
        }
        if let queryIndex = value.firstIndex(of: "?") {
            value = String(value[..<queryIndex])
        }
        value = value.removingPercentEncoding ?? value
        guard !value.isEmpty, !value.hasPrefix("//") else { return nil }

        let combined = value.hasPrefix("/")
            ? String(value.dropFirst())
            : (chapterBase.isEmpty ? value : chapterBase + "/" + value)
        let normalized = Self.normalizePath(combined)
        return findEntry(named: normalized, in: entries)
    }

    private func findEntry(named path: String, in entries: [String: Data]) -> String? {
        if entries[path] != nil { return path }
        let lower = path.lowercased()
        return entries.keys.first { $0.lowercased() == lower }
    }

    private func resolveEntry(href: String, relativeTo base: String, entries: [String: Data]) -> String? {
        var value = href.removingPercentEncoding ?? href
        if let hashIndex = value.firstIndex(of: "#") {
            value = String(value[..<hashIndex])
        }
        if let queryIndex = value.firstIndex(of: "?") {
            value = String(value[..<queryIndex])
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let combined = value.hasPrefix("/")
            ? String(value.dropFirst())
            : (base.isEmpty ? value : base + "/" + value)
        return findEntry(named: Self.normalizePath(combined), in: entries)
    }

    // MARK: - 文本处理

    private func sanitizeForSearch(_ html: String) -> String {
        plainText(from: html)
    }

    private func plainText(from html: String) -> String {
        var text = html
        text = replacing(#"<(script|style)\b[^>]*>[\s\S]*?</\1>"#, in: text, with: " ")
        text = replacing(#"<br\s*/?>"#, in: text, with: "\n")
        text = replacing(#"</(?:p|div|h[1-6]|li|tr|blockquote|section|article)\s*>"#, in: text, with: "\n")
        text = replacing(#"<[^>]+>"#, in: text, with: " ")
        text = decodeHTMLEntities(text)
        return text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let named: [String: String] = [
            "&nbsp;": " ",
            "&#160;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&#8216;": "‘",
            "&#8217;": "’",
            "&#8220;": "“",
            "&#8221;": "”",
            "&ldquo;": "“",
            "&rdquo;": "”",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…"
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity,
                                                 with: replacement,
                                                 options: .caseInsensitive)
        }

        guard let regex = try? NSRegularExpression(pattern: #"&#(x?[0-9A-Fa-f]+);"#) else {
            return result
        }
        let original = result as NSString
        let found = regex.matches(in: result, range: NSRange(location: 0, length: original.length))
        for match in found.reversed() {
            let token = original.substring(with: match.range(at: 1))
            let scalarValue: UInt32?
            if token.lowercased().hasPrefix("x") {
                scalarValue = UInt32(token.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(token)
            }
            guard let scalarValue, let scalar = Unicode.Scalar(scalarValue) else { continue }
            result = (result as NSString).replacingCharacters(in: match.range, with: String(scalar))
        }
        return result
    }

    private func paragraphHTML(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var paragraphs: [String] = []
        for chunk in normalized.components(separatedBy: "\n\n") {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lines = trimmed.components(separatedBy: "\n")
                .map { escapeHTML($0.trimmingCharacters(in: .whitespaces)) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }
            paragraphs.append("<p>" + lines.joined(separator: "<br>") + "</p>")
        }

        if paragraphs.isEmpty {
            let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append("<p>" + escapeHTML(trimmed) + "</p>")
            }
        }
        return paragraphs.joined(separator: "\n")
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func escapeAttribute(_ text: String) -> String {
        escapeHTML(text).replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func decodeString(_ data: Data) -> String? {
        if data.isEmpty { return "" }
        if data.starts(with: Data([0xFF, 0xFE])) || data.starts(with: Data([0xFE, 0xFF])) {
            return String(data: data, encoding: .utf16)
        }
        if let value = String(data: data, encoding: .utf8) {
            return value
        }
        if let value = String(data: data, encoding: .utf16) {
            return value
        }
        // 中文 TXT 常见的 GB18030：放在 Latin-1 前面，否则会解成一屏乱码。
        let gbEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let value = String(data: data, encoding: String.Encoding(rawValue: gbEncoding)) {
            return value
        }
        if let value = String(data: data, encoding: .isoLatin1) {
            return value
        }
        return nil
    }

    // MARK: - 正则工具

    private func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).map {
            (text as NSString).substring(with: $0.range)
        }
    }

    private func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1 else {
            return nil
        }
        let capture = match.range(at: 1)
        guard capture.location != NSNotFound else { return nil }
        return (text as NSString).substring(with: capture)
    }

    private func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private func attribute(_ name: String, in tag: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = "(?:^|\\s)" + escaped + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        guard let match = regex.firstMatch(in: tag, range: range) else { return nil }
        for index in 1..<match.numberOfRanges {
            let capture = match.range(at: index)
            if capture.location != NSNotFound {
                return (tag as NSString).substring(with: capture)
            }
        }
        return nil
    }

    // MARK: - 查询与修改

    func delete(_ book: Book) {
        do {
            try FileManager.default.removeItem(at: bookDirectory(for: book.id))
        } catch {
            lastError = error.localizedDescription
        }
        books.removeAll { $0.id == book.id }
        do {
            try saveIndex()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateProgress(bookID: String, value: Double) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        let clamped = min(max(value, 0), 1)
        guard abs(books[index].progress - clamped) > 0.0001 else { return }
        books[index].progress = clamped
        do {
            try saveIndex()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func search(_ query: String) -> [(book: Book, chapterIndex: Int, snippet: String)] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        var results: [(book: Book, chapterIndex: Int, snippet: String)] = []
        for book in books {
            for (index, chapter) in book.chapters.enumerated() {
                let text = sanitizeForSearch(chapter.html)
                guard !text.isEmpty else { continue }
                let original = text as NSString
                let range = original.range(of: needle,
                                           options: [.caseInsensitive, .diacriticInsensitive],
                                           range: NSRange(location: 0, length: original.length))
                guard range.location != NSNotFound else { continue }

                let start = max(0, range.location - 36)
                let end = min(original.length, max(range.location + range.length + 36, start + 80))
                var snippet = original.substring(with: NSRange(location: start, length: end - start))
                snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
                if start > 0 { snippet = "…" + snippet }
                if end < original.length { snippet += "…" }
                results.append((book: book, chapterIndex: index, snippet: snippet))
            }
        }
        return results
    }

    // MARK: - 工具

    private static func isZipArchive(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let base = data.startIndex
        return data[base] == 0x50
            && data[base + 1] == 0x4B
            && data[base + 2] == 0x03
            && data[base + 3] == 0x04
    }

    private static func makeBookID() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = String(UUID().uuidString.prefix(6)).lowercased()
        return "book-\(formatter.string(from: Date()))-\(suffix)"
    }

    /// 解析 `.` 与 `..`，并去掉开头的斜杠，保证结果始终是相对路径。
    private static func normalizePath(_ raw: String) -> String {
        let replaced = raw.replacingOccurrences(of: "\\", with: "/")
        var stack: [String] = []
        for component in replaced.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".":
                continue
            case "..":
                if !stack.isEmpty { stack.removeLast() }
            default:
                stack.append(String(component))
            }
        }
        return stack.joined(separator: "/")
    }
}

// MARK: - 持久化结构

private struct LibraryIndexEntry: Codable {
    var id: String
    var title: String
    var author: String
    var addedAt: Date
    var progress: Double
}

private struct StoredBook: Codable {
    var id: String
    var title: String
    var author: String
    var addedAt: Date
    var chapters: [StoredChapter]
}

private struct StoredChapter: Codable {
    var id: String
    var title: String
    var file: String
}

private struct ManifestItem {
    var id: String
    var href: String
    var mediaType: String
    var properties: String
}

private struct ImportedBook {
    var title: String
    var author: String
    var chapters: [Chapter]
}
