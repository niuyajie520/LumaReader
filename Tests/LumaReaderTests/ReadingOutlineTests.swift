import Foundation
import Testing
@testable import LumaReader
#if !os(macOS) && canImport(FoundationXML)
import FoundationXML
#endif

struct ReadingOutlineTests {
    private let root = URL(fileURLWithPath:"/tmp/luma-outline",isDirectory:true)
    private func parse(_ xml: String) throws -> EPUBNavigationParser {
        let delegate = EPUBNavigationParser(base:root,root:root)
        let parser = XMLParser(data:Data(xml.utf8)); parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        #expect(parser.parse()); return delegate
    }
    @Test func nestedEPUB3RetainsFragmentsAndGroupingLabels() throws {
        let delegate = try parse("""
        <html xmlns:epub="http://www.idpf.org/2007/ops"><body>
        <nav epub:type="toc"><ol><li><span>第一部</span><ol>
        <li><a href="one.xhtml#main">第一章</a><ol><li><a href="one.xhtml#small%20title">小标题</a></li></ol></li>
        <li><a href="two.xhtml">第二章</a></li></ol></li></ol></nav>
        <nav epub:type="landmarks"><ol><li><a href="two.xhtml">正文入口</a></li></ol></nav>
        </body></html>
        """)
        let chapters = [Chapter(id:0,title:"第一章",url:root.appendingPathComponent("one.xhtml")),Chapter(id:1,title:"第二章",url:root.appendingPathComponent("two.xhtml"))]
        let outline = delegate.outline(chapters:chapters)
        #expect(outline.count == 1)
        #expect(outline[0].title == "第一部")
        #expect(outline[0].chapterIndex == nil)
        #expect(outline[0].children.count == 2)
        #expect(outline[0].children[0].fragment == "main")
        #expect(outline[0].children[0].children[0].fragment == "small title")
        #expect(outline[0].children[0].children[0].chapterIndex == 0)
    }
    @Test func ncxKeepsParentsAndChildren() throws {
        let delegate = try parse("""
        <ncx><navMap><navPoint><navLabel><text>第一章</text></navLabel><content src="one.xhtml"/>
        <navPoint><navLabel><text>一、例子</text></navLabel><content src="one.xhtml#example"/></navPoint>
        </navPoint></navMap></ncx>
        """)
        let outline = delegate.outline(chapters:[Chapter(id:0,title:"chapter",url:root.appendingPathComponent("one.xhtml"))])
        #expect(outline.first?.children.first?.title == "一、例子")
        #expect(outline.first?.children.first?.fragment == "example")
    }
    @Test func invalidTargetsDoNotBecomeNavigableEntries() throws {
        let delegate = try parse("""
        <nav><ol><li><a href="../outside.xhtml">越界</a></li><li><a href="https://example.com/one.xhtml">远程</a></li>
        <li><a href="one.xhtml">有效</a></li></ol></nav>
        """)
        let outline = delegate.outline(chapters:[Chapter(id:0,title:"chapter",url:root.appendingPathComponent("one.xhtml"))])
        #expect(outline.map(\.title) == ["有效"])
    }
    @Test func fallbackHeadingsNestWithoutChangingTheirDOMIndices() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let file = directory.appendingPathComponent("chapter.xhtml")
        try Data("<html><body><h1 id='main'>大标题</h1><h2>小标题</h2><h3 id='detail'>细节</h3><h2>另一个小标题</h2></body></html>".utf8).write(to:file)
        let items = EPUBHeadingParser.outline(chapter:Chapter(id:2,title:"章节",url:file))
        #expect(items.count == 1)
        #expect(items[0].children.count == 2)
        #expect(items[0].children[0].headingIndex == 1)
        #expect(items[0].children[0].children[0].fragment == "detail")
        #expect(items[0].children[1].headingIndex == 3)
    }
}
