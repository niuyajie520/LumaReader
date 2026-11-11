import Foundation
import Testing
@testable import LumaReader

struct EPUBPathTests {
    @Test func readerNavigationAcceptsCanonicalAliasesButRejectsEscapes() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("ReaderNavigation-"+UUID().uuidString)
        let root = base.appendingPathComponent("book")
        try fm.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? fm.removeItem(at:base) }
        let chapter = root.appendingPathComponent("chapter.html")
        try Data("fixture".utf8).write(to:chapter)
        let alias = base.appendingPathComponent("alias")
        try fm.createSymbolicLink(at:alias,withDestinationURL:root)
        #expect(ReaderFileNavigation.contains(chapter.resolvingSymlinksInPath(),in:alias))
        #expect(ReaderFileNavigation.contains(alias.appendingPathComponent("chapter.html"),in:root))
        let outside = base.appendingPathComponent("outside.html")
        try Data("outside".utf8).write(to:outside)
        let escape = root.appendingPathComponent("escape.html")
        try fm.createSymbolicLink(at:escape,withDestinationURL:outside)
        #expect(!ReaderFileNavigation.contains(escape,in:root))
        #expect(!ReaderFileNavigation.contains(root.appendingPathComponent("../outside.html"),in:root))
        #expect(!ReaderFileNavigation.contains(base.appendingPathComponent("book-other/chapter.html"),in:root))
        #expect(!ReaderFileNavigation.contains(URL(string:"https://example.com/chapter.html")!,in:root))
        #expect(!ReaderFileNavigation.contains(root,in:root))
    }
    @Test func nestedChapterStaysInsideRoot() throws {
        let root = URL(fileURLWithPath:"/tmp/luma-book")
        #expect(try EPUBLoader.contained("OEBPS/chapter-1.xhtml",in:root).path == "/tmp/luma-book/OEBPS/chapter-1.xhtml")
    }
    @Test(arguments: ["../library.json","OEBPS/../../outside","/etc/passwd","OEBPS\\..\\outside"])
    func archiveTraversalAndAbsolutePathsAreRejected(path: String) {
        #expect(throws: (any Error).self) {
            try EPUBLoader.contained(path,in:URL(fileURLWithPath:"/tmp/luma-book"))
        }
    }
    @Test func annotationRoundTripPreservesAnchorAndColors() throws {
        let note = ReadingNote(quote:"读慢一点 📖",note:"我的想法",ink:.purple,chapter:2,start:14,end:22)
        let restored = try JSONDecoder().decode(ReadingNote.self,from:JSONEncoder().encode(note))
        #expect(restored == note)
    }
}
