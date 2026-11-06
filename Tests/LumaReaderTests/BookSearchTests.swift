import Foundation
import Testing
@testable import LumaReader

struct BookSearchTests {
    @Test func searchSpansInlineMarkupAndIgnoresScriptsAndHead() throws {
        let html = "<html><head><title>不搜索我</title></head><body><p>逻<b>辑</b>学 📖 &amp; 阅读</p><script>不搜索我</script><style>不搜索我</style></body></html>"
        let plain = BookSearchEngine.plainText(html)
        #expect(plain == "逻辑学 📖 & 阅读")
        let hits = try BookSearchEngine.search("逻辑",in:[SearchChapter(index:2,title:"第二章",text:plain)])
        #expect(hits.count == 1)
        #expect(hits[0].chapter == 2)
        #expect(hits[0].range == NSRange(location:0,length:2))
    }
    @Test func entitiesAndMalformedHTMLRemainSearchable() throws {
        let plain = BookSearchEngine.plainText("<body><p>Book&nbsp;📖 &#x903B;&#36753; &amp; Notes</p><br></body>")
        #expect(plain.contains("Book\u{00a0}📖 逻辑 & Notes"))
        #expect(try BookSearchEngine.search("逻辑",in:[SearchChapter(index:0,title:"Chapter",text:plain)]).count == 1)
    }
    @Test func occurrenceNumbersAndCaseInsensitiveQueriesAreStable() throws {
        let chapters = [SearchChapter(index:0,title:"A",text:"Book book BOOK 📖"),SearchChapter(index:1,title:"B",text:"book")]
        let hits = try BookSearchEngine.search("book",in:chapters)
        #expect(hits.count == 4)
        #expect(hits.map(\.occurrence) == [0,1,2,0])
        #expect(hits.map(\.chapter) == [0,0,0,1])
        #expect(try BookSearchEngine.search("📖",in:chapters)[0].range.length == 2)
    }
    @Test func emptyQueriesAndResultLimit() throws {
        let chapters = [SearchChapter(index:0,title:"A",text:"aaaaa")]
        #expect(try BookSearchEngine.search("  ",in:chapters).isEmpty)
        #expect(try BookSearchEngine.search("a",in:chapters,limit:2).count == 2)
    }
    @Test func recentSearchesPersistDeduplicateKeepTenAndClear() {
        let suite = "LumaSearchTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        for i in 0..<12 { RecentBookSearches.remember("term \(i)",defaults:defaults) }
        #expect(RecentBookSearches.read(defaults:defaults).count == 10)
        #expect(RecentBookSearches.read(defaults:defaults).first == "term 11")
        RecentBookSearches.remember(" WORD ",defaults:defaults)
        let stored = RecentBookSearches.remember("word",defaults:defaults)
        #expect(stored.first == "word")
        #expect(stored.filter { $0.lowercased() == "word" }.count == 1)
        #expect(RecentBookSearches.read(defaults:UserDefaults(suiteName:suite)!) == stored)
        RecentBookSearches.clear(defaults:defaults)
        #expect(RecentBookSearches.read(defaults:defaults).isEmpty)
    }

}
