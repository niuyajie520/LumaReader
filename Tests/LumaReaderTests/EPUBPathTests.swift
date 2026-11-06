import Foundation
import Testing
@testable import LumaReader

struct EPUBPathTests {
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
