import Foundation
#if !os(macOS) && canImport(FoundationXML)
import FoundationXML
#endif

struct SearchChapter: Sendable {
    var index: Int
    var title: String
    var text: String
}

struct BookSearchHit: Identifiable, Sendable {
    var id: String { "\(chapter):\(range.location)" }
    var chapter: Int
    var title: String
    var snippet: String
    var range: NSRange
    var occurrence: Int
}

enum BookSearchEngine {
    static func index(chapters: [Chapter]) throws -> [SearchChapter] {
        try chapters.map { chapter in
            try Task.checkCancellation()
            let html = try String(contentsOf:chapter.url,encoding:.utf8)
            return SearchChapter(index:chapter.id,title:chapter.title,text:plainText(html))
        }
    }

    static func search(_ query: String, in chapters: [SearchChapter], limit: Int = 1000) throws -> [BookSearchHit] {
        let query = query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !query.isEmpty, limit > 0 else { return [] }
        var hits: [BookSearchHit] = []
        for chapter in chapters {
            try Task.checkCancellation()
            let text = chapter.text as NSString
            var cursor = 0, occurrence = 0
            while cursor < text.length {
                let range = text.range(of:query,options:.caseInsensitive,range:NSRange(location:cursor,length:text.length-cursor))
                guard range.location != NSNotFound, range.length > 0 else { break }
                let start = max(0,range.location-30), end = min(text.length,NSMaxRange(range)+55)
                let snippet = text.substring(with:text.rangeOfComposedCharacterSequences(for:NSRange(location:start,length:end-start)))
                    .replacingOccurrences(of:"\\s+",with:" ",options:.regularExpression)
                hits.append(BookSearchHit(chapter:chapter.index,title:chapter.title,snippet:snippet,range:range,occurrence:occurrence))
                if hits.count >= limit { return hits }
                occurrence += 1; cursor = NSMaxRange(range)
            }
        }
        return hits
    }

    static func plainText(_ html: String) -> String {
        let collector = BodyTextCollector()
        let parser = XMLParser(data:Data(html.utf8))
        parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false
        parser.delegate = collector
        if parser.parse(), parser.parserError == nil, collector.sawBody { return collector.text }
        // Some EPUBs contain HTML entities or malformed XHTML. Preserve the DOM's
        // text-node order rather than inserting extra spaces between inline tags.
        var body = html
        if let expression = try? NSRegularExpression(pattern:"<body\\b[^>]*>([\\s\\S]*?)</body>",options:.caseInsensitive),
           let match = expression.firstMatch(in:html,range:NSRange(html.startIndex...,in:html)),
           let range = Range(match.range(at:1),in:html) { body = String(html[range]) }
        for pattern in ["<!--[\\s\\S]*?-->","<(script|style|noscript)\\b[^>]*>[\\s\\S]*?</\\1\\s*>","<[^>]+>"] {
            body = body.replacingOccurrences(of:pattern,with:"",options:[.regularExpression,.caseInsensitive])
        }
        let entities = ["amp":"&","lt":"<","gt":">","quot":"\"","apos":"'","nbsp":"\u{00a0}","ndash":"–","mdash":"—","hellip":"…","lsquo":"‘","rsquo":"’","ldquo":"“","rdquo":"”","copy":"©"]
        let expression = try! NSRegularExpression(pattern:"&([A-Za-z][A-Za-z0-9]+|#[xX][0-9A-Fa-f]+|#[0-9]+);")
        let source = body as NSString
        for match in expression.matches(in:body,range:NSRange(location:0,length:source.length)).reversed() {
            let entity = source.substring(with:match.range(at:1))
            var replacement = entities[entity]
            if entity.hasPrefix("#") {
                let hex = entity.lowercased().hasPrefix("#x")
                if let value = UInt32(entity.dropFirst(hex ? 2:1),radix:hex ? 16:10), let scalar = UnicodeScalar(value) { replacement = String(scalar) }
            }
            if let replacement, let range = Range(match.range,in:body) { body.replaceSubrange(range,with:replacement) }
        }
        return body.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n")
    }
}

private final class BodyTextCollector: NSObject, XMLParserDelegate {
    var text = ""
    var sawBody = false
    private var insideBody = false
    private var skipped = 0
    func parser(_ parser: XMLParser,didStartElement name: String,namespaceURI: String?,qualifiedName: String?,attributes:[String:String]) {
        if name.lowercased() == "body" { insideBody = true; sawBody = true }
        if ["script","style","noscript"].contains(name.lowercased()) { skipped += 1 }
    }
    func parser(_ parser: XMLParser,didEndElement name:String,namespaceURI:String?,qualifiedName:String?) {
        if name.lowercased() == "body" { insideBody = false }
        if ["script","style","noscript"].contains(name.lowercased()) { skipped = max(0,skipped-1) }
    }
    func parser(_ parser:XMLParser,foundCharacters string:String) { if insideBody && skipped == 0 { text += string } }
    func parser(_ parser:XMLParser,foundCDATA block:Data) { if insideBody && skipped == 0 { text += String(decoding:block,as:UTF8.self) } }
}

enum RecentBookSearches {
    private static let key = "bookRecentSearches"
    static func read(defaults: UserDefaults = .standard) -> [String] { defaults.stringArray(forKey:key) ?? [] }
    @discardableResult static func remember(_ query:String,defaults:UserDefaults = .standard) -> [String] {
        let value = query.trimmingCharacters(in:.whitespacesAndNewlines)
        var items = read(defaults:defaults)
        guard !value.isEmpty else { return items }
        items.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        items.insert(value,at:0); items = Array(items.prefix(10))
        defaults.set(items,forKey:key)
        return items
    }
    static func clear(defaults:UserDefaults = .standard) { defaults.removeObject(forKey:key) }
}
