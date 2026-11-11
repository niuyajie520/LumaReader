import Foundation
import Testing
@testable import LumaReader

struct ReadingExperienceTests {
    private func preferences(size: Double = 19, theme: String = "paper") -> BookReadingPreferences {
        BookReadingPreferences(font:"serif",size:size,width:680,lineHeight:1.75,paragraphSpacing:1.35,
                               indent:false,theme:theme,appearance:"跟随系统",monetEnabled:true,monetSource:"cover",
                               monetStyle:"tonalSpot",monetSeed:0xFF8C7862,monetLocked:false,pageTurnStyle:"natural",pageTurnAnimation:true)
    }
    @Test func bookSpecificSettingsDoNotLeakToAnotherBook() throws {
        let a = UUID(), b = UUID()
        var archive = BookReadingPreferencesArchive(defaults:preferences())
        archive.record(preferences(size:25,theme:"mint"),for:a,perBook:true)
        #expect(archive.value(for:b,perBook:true).size == 19)
        archive.record(preferences(size:17,theme:"midnight"),for:b,perBook:true)
        archive.record(preferences(size:21),for:nil,perBook:true)
        let restored = try JSONDecoder().decode(BookReadingPreferencesArchive.self,from:JSONEncoder().encode(archive))
        #expect(restored.value(for:a,perBook:true).size == 25)
        #expect(restored.value(for:a,perBook:true).theme == "mint")
        #expect(restored.value(for:b,perBook:true).theme == "midnight")
        #expect(restored.value(for:nil,perBook:true).size == 21)
        #expect(restored.value(for:a,perBook:false).size == 21)
    }
    @Test func lastChapterIsNotCompleteUntilItsLastSpread() {
        #expect(ReadingProgress.epub(chapter:9,chapterCount:10,offset:0,canForward:true) == 0.9)
        #expect(ReadingProgress.epub(chapter:9,chapterCount:10,offset:0.5,canForward:true) < 1)
        #expect(ReadingProgress.epub(chapter:9,chapterCount:10,offset:1,canForward:false) == 1)
        #expect(ReadingProgress.epub(chapter:0,chapterCount:1,offset:0,canForward:true) == 0)
        #expect(ReadingProgress.epub(chapter:0,chapterCount:0,offset:.nan,canForward:false) == 0)
    }
    @Test func oldLibraryAndBookmarksDecodeWithoutTextAnchors() throws {
        let oldBook = Book(title:"旧书库",filename:"old.epub",kind:"epub")
        var object = try JSONSerialization.jsonObject(with:JSONEncoder().encode(oldBook)) as! [String:Any]
        object.removeValue(forKey:"readerAnchor")
        let book = try JSONDecoder().decode(Book.self,from:JSONSerialization.data(withJSONObject:object))
        #expect(book.readerAnchor == nil)
        let oldMark = ReadingBookmark(title:"旧书签",position:2,offset:0.3)
        var markObject = try JSONSerialization.jsonObject(with:JSONEncoder().encode(oldMark)) as! [String:Any]
        markObject.removeValue(forKey:"anchor")
        let mark = try JSONDecoder().decode(ReadingBookmark.self,from:JSONSerialization.data(withJSONObject:markObject))
        #expect(mark.anchor == nil); #expect(mark.offset == 0.3)
    }
    @Test func newestCloudProgressCarriesItsOwnAnchor() throws {
        var local = Book(title:"书",filename:"book.epub",kind:"epub")
        local.position = 1; local.readerAnchor = .init(start:500,quote:"旧位置"); local.progressUpdatedAt = Date(timeIntervalSince1970:100)
        var remote = local
        remote.position = 2; remote.readerAnchor = .init(start:900,quote:"新位置"); remote.progressUpdatedAt = Date(timeIntervalSince1970:200)
        let book = CloudSyncEngine.mergeBooks(local:[local],remote:[remote],provider:.oneDrive)[0]
        #expect(book.position == 2); #expect(book.readerAnchor == remote.readerAnchor)
        let decoded = try JSONDecoder().decode(Book.self,from:JSONEncoder().encode(book))
        #expect(decoded.readerAnchor == remote.readerAnchor)
    }
    @Test func directorySearchKeepsAncestorsAndCurrentLocation() {
        let child = ReadingOutlineItem(id:"small",title:"小标题：论证",chapterIndex:2,fragment:"argument",headingIndex:3)
        let parent = ReadingOutlineItem(id:"big",title:"第三章",chapterIndex:2,children:[child])
        let items = [parent,ReadingOutlineItem(id:"other",title:"其他章节",chapterIndex:3)]
        let filtered = ReadingOutlineNavigation.filter(items,query:"论证")
        #expect(filtered.map(\.id) == ["big"])
        #expect(filtered[0].children.map(\.id) == ["small"])
        #expect(ReadingOutlineNavigation.currentID(items,chapter:2,headingIndex:3,headingID:"argument") == "small")
        #expect(ReadingOutlineNavigation.ancestors(of:"small",in:items) == Set(["big"]))
    }
    @Test func malformedBridgeAnchorsAreRejected() {
        #expect(ReaderTextAnchor(message:["version":2,"start":0,"quote":"text","prefix":""]) == nil)
        #expect(ReaderTextAnchor(message:["version":1,"start":-1,"quote":"text","prefix":""]) == nil)
        #expect(ReaderTextAnchor(message:["version":1,"start":5,"quote":"阅读📖","prefix":"前文"])?.start == 5)
    }
}
