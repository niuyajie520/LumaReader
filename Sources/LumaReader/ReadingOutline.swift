import Foundation
#if !os(macOS) && canImport(FoundationXML)
import FoundationXML
#endif

struct ReadingOutlineItem: Identifiable, Sendable {
    var id: String
    var title: String
    var chapterIndex: Int?
    var fragment: String? = nil
    var headingIndex: Int? = nil
    var children: [ReadingOutlineItem] = []
    var descendantIDs: Set<String> { Set([id]).union(children.flatMap { $0.descendantIDs }) }
}

/// EPUB3 nav and EPUB2 NCX keep hierarchy and fragment targets independently of spine order.
final class EPUBNavigationParser: NSObject, XMLParserDelegate {
    final class Node {
        var title = ""
        var href: String?
        var children: [Node] = []
    }
    private(set) var nodes: [Node] = []
    private let base: URL
    private let root: URL
    private var stack: [Node] = []
    private var depth = 0
    private var scopeDepth: Int?
    private var captureDepth: Int?
    private var label = ""
    init(base: URL, root: URL) { self.base = base; self.root = root }
    private func target(_ href: String) -> (String,String?)? {
        guard URL(string:href)?.scheme == nil, !href.hasPrefix("//"), !href.hasPrefix("/") else { return nil }
        let parts = href.split(separator:"#",maxSplits:1,omittingEmptySubsequences:false)
        guard let path = parts.first, !path.isEmpty else { return nil }
        let url = base.appendingPathComponent(String(path).removingPercentEncoding ?? String(path)).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path+"/") else { return nil }
        let fragment = parts.count > 1 ? String(parts[1]).removingPercentEncoding ?? String(parts[1]):nil
        return (url.path,fragment)
    }
    var titles: [String:String] {
        var result: [String:String] = [:]
        func visit(_ list: [Node]) {
            for node in list {
                if let href = node.href, let (path,_) = target(href), !node.title.isEmpty, result[path] == nil { result[path] = node.title }
                visit(node.children)
            }
        }
        visit(nodes); return result
    }
    func outline(chapters: [Chapter]) -> [ReadingOutlineItem] {
        let indices = Dictionary(chapters.map { ($0.url.standardizedFileURL.path,$0.id) },uniquingKeysWith:{ first,_ in first })
        func convert(_ list: [Node], path: String) -> [ReadingOutlineItem] {
            list.enumerated().compactMap { i,node in
                let id = path+"/"+String(i)
                let children = convert(node.children,path:id)
                let destination = node.href.flatMap(target)
                let chapter = destination.flatMap { indices[$0.0] }
                guard chapter != nil || !children.isEmpty else { return nil }
                return ReadingOutlineItem(id:id,title:node.title.isEmpty ? "目录":node.title,chapterIndex:chapter,fragment:destination?.1,children:children)
            }
        }
        return convert(nodes,path:"nav")
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String:String]) {
        depth += 1
        if name == "navMap" { scopeDepth = depth }
        if name == "nav" {
            let type = attributes["epub:type"] ?? attributes["type"] ?? ""
            if type.split(separator:" ").contains("toc") || attributes["role"] == "doc-toc" || (type.isEmpty && nodes.isEmpty) { scopeDepth = depth }
        }
        guard scopeDepth != nil else { return }
        if name == "li" || name == "navPoint" {
            let node = Node()
            if let parent = stack.last { parent.children.append(node) } else { nodes.append(node) }
            stack.append(node)
        }
        if name == "a" { stack.last?.href = attributes["href"] }
        if name == "content" { stack.last?.href = attributes["src"] }
        if captureDepth == nil, name == "a" || name == "span" || name == "navLabel" {
            captureDepth = depth; label = ""
        }
    }
    func parser(_ parser: XMLParser, foundCharacters text: String) { if captureDepth != nil { label += text } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if captureDepth == depth {
            stack.last?.title = label.split(whereSeparator: { $0.isWhitespace }).joined(separator:" ")
            captureDepth = nil
        }
        if scopeDepth != nil, name == "li" || name == "navPoint" { if !stack.isEmpty { stack.removeLast() } }
        if scopeDepth == depth { scopeDepth = nil }
        depth -= 1
    }
}

/// Books with a flat/missing nav still expose nested h1…h6 headings.
final class EPUBHeadingParser: NSObject, XMLParserDelegate {
    struct Heading { let title: String; let level: Int; let fragment: String?; let index: Int }
    private var headings: [Heading] = []
    private var current: (level:Int,fragment:String?,depth:Int)?
    private var depth = 0
    private var label = ""
    static func outline(chapter: Chapter) -> [ReadingOutlineItem] {
        guard let data = try? Data(contentsOf:chapter.url) else { return [] }
        let delegate = EPUBHeadingParser()
        let parser = XMLParser(data:data); parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse() else { return [] }
        final class Branch {
            let heading: Heading
            var children: [Branch] = []
            init(_ heading: Heading) { self.heading = heading }
        }
        var roots: [Branch] = [], stack: [Branch] = []
        for h in delegate.headings {
            let node = Branch(h)
            while let last = stack.last, last.heading.level >= h.level { stack.removeLast() }
            if let parent = stack.last { parent.children.append(node) } else { roots.append(node) }
            stack.append(node)
        }
        func convert(_ nodes: [Branch]) -> [ReadingOutlineItem] {
            nodes.map { node in
                let h = node.heading
                return ReadingOutlineItem(id:"heading/\(chapter.id)/\(h.index)",title:h.title,chapterIndex:chapter.id,fragment:h.fragment,headingIndex:h.index,children:convert(node.children))
            }
        }
        return convert(roots)
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String:String]) {
        depth += 1
        if name.count == 2, name.first == "h", let n = name.last?.wholeNumberValue, (1...6).contains(n) {
            current = (n,attributes["id"],depth); label = ""
        }
    }
    func parser(_ parser: XMLParser, foundCharacters text: String) { if current != nil { label += text } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if let c = current, c.depth == depth {
            headings.append(Heading(title:label.trimmingCharacters(in:.whitespacesAndNewlines),level:c.level,fragment:c.fragment,index:headings.count))
            current = nil
        }
        depth -= 1
    }
}

enum ReadingOutlineNavigation {
    static func filter(_ items: [ReadingOutlineItem], query: String) -> [ReadingOutlineItem] {
        let term = query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !term.isEmpty else { return items }
        return items.compactMap { item in
            if item.title.localizedCaseInsensitiveContains(term) { return item }
            var result = item; result.children = filter(item.children,query:term)
            return result.children.isEmpty ? nil:result
        }
    }
    static func currentID(_ items: [ReadingOutlineItem], chapter: Int, headingIndex: Int, headingID: String) -> String? {
        var best: (id:String,score:Int)?
        func visit(_ nodes: [ReadingOutlineItem]) {
            for node in nodes {
                if node.chapterIndex == chapter {
                    let exactFragment = !headingID.isEmpty && node.fragment == headingID
                    let exactHeading = headingIndex >= 0 && node.headingIndex == headingIndex
                    let score = exactFragment || exactHeading ? 3:(node.fragment == nil && node.headingIndex == nil ? 1:0)
                    if score > 0 && score >= (best?.score ?? 0) { best = (node.id,score) }
                }
                visit(node.children)
            }
        }
        visit(items); return best?.id
    }
    static func ancestors(of id: String, in items: [ReadingOutlineItem]) -> Set<String> {
        for item in items {
            if item.id == id { return [] }
            if item.descendantIDs.contains(id) { return Set([item.id]).union(ancestors(of:id,in:item.children)) }
        }
        return []
    }
}
