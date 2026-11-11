import Foundation
import Testing
import ZIPFoundation
@testable import LumaReader

struct EPUBImportTests {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        return url
    }
    private func book(at base: URL, opfPath: String = "OEBPS/content.opf") throws -> URL {
        let source = base.appendingPathComponent("source")
        try FileManager.default.createDirectory(at:source.appendingPathComponent("META-INF"),withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:source.appendingPathComponent("OEBPS"),withIntermediateDirectories:true)
        let container = "<container xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"\(opfPath)\"/></rootfiles></container>"
        let opf = "<package xmlns=\"http://www.idpf.org/2007/opf\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>测试书籍</dc:title><dc:creator>Luma Test</dc:creator></metadata><manifest><item id=\"one\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/></manifest><spine><itemref idref=\"one\"/></spine></package>"
        try container.write(to:source.appendingPathComponent("META-INF/container.xml"),atomically:true,encoding:.utf8)
        try opf.write(to:source.appendingPathComponent("OEBPS/content.opf"),atomically:true,encoding:.utf8)
        try "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><p>文字测试 📖</p></body></html>".write(to:source.appendingPathComponent("OEBPS/chapter.xhtml"),atomically:true,encoding:.utf8)
        let epub = base.appendingPathComponent("book.epub")
        try FileManager.default.zipItem(at:source,to:epub,shouldKeepParent:false)
        return epub
    }
    @Test func importsXMLMetadataAndChapterAndReusesCache() throws {
        let base = try fixture();defer { try? FileManager.default.removeItem(at:base) }
        let file = try book(at:base)
        let cache = base.appendingPathComponent("cache")
        let first = try EPUBLoader.load(file:file,cache:cache)
        #expect(first.title == "测试书籍")
        #expect(first.author == "Luma Test")
        #expect(first.chapters.count == 1)
        #expect(try String(contentsOf:first.chapters[0].url,encoding:.utf8).contains("📖"))
        let marker = first.root.appendingPathComponent(".complete")
        let modified = try marker.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate
        _ = try EPUBLoader.load(file:file,cache:cache)
        #expect(try marker.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate == modified)
    }
    @Test func rejectsContainerPathOutsideBook() throws {
        let base = try fixture();defer { try? FileManager.default.removeItem(at:base) }
        let file = try book(at:base,opfPath:"../outside.opf")
        #expect(throws:(any Error).self) { try EPUBLoader.load(file:file,cache:base.appendingPathComponent("cache")) }
    }
    @Test func corruptZIPDoesNotLeaveCompletedCache() throws {
        let base = try fixture();defer { try? FileManager.default.removeItem(at:base) }
        let file = base.appendingPathComponent("bad.epub")
        try Data("not a zip file".utf8).write(to:file)
        let cache = base.appendingPathComponent("cache")
        #expect(throws:(any Error).self) { try EPUBLoader.load(file:file,cache:cache) }
        #expect(!FileManager.default.fileExists(atPath:cache.appendingPathComponent("bad").path))
    }
    @Test func navigationTitlesAndCoverAreReadFromManifest() throws {
        let base = try fixture(); defer { try? FileManager.default.removeItem(at:base) }
        let file = try book(at:base)
        let source = base.appendingPathComponent("source")
        let opfURL = source.appendingPathComponent("OEBPS/content.opf")
        let original = try String(contentsOf:opfURL,encoding:.utf8)
        let additions = "<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/><item id=\"cover\" href=\"cover.png\" media-type=\"image/png\" properties=\"cover-image\"/></manifest>"
        try original.replacingOccurrences(of:"</manifest>",with:additions).write(to:opfURL,atomically:true,encoding:.utf8)
        try "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><nav><ol><li><a href=\"chapter.xhtml#start\">第一章 阅读与思考</a></li></ol></nav></body></html>".write(to:source.appendingPathComponent("OEBPS/nav.xhtml"),atomically:true,encoding:.utf8)
        try Data("fixture-image".utf8).write(to:source.appendingPathComponent("OEBPS/cover.png"))
        try FileManager.default.removeItem(at:file)
        try FileManager.default.zipItem(at:source,to:file,shouldKeepParent:false)
        let loaded = try EPUBLoader.load(file:file,cache:base.appendingPathComponent("cache"))
        #expect(loaded.chapters.first?.title == "第一章 阅读与思考")
        #expect(loaded.coverURL?.lastPathComponent == "cover.png")
    }

}
