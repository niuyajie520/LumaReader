import Foundation
import Testing
@testable import LumaReader

struct BookmarkReturnTests {
    @Test func bookmarkFollowsItsTextAcrossPagesAndReflow() {
        let mark = ReadingBookmark(title:"Saved",position:0,offset:0.2,anchor:ReaderTextAnchor(start:200,quote:"原文"))
        let initial = ReaderBookmarkPage(index:0,count:10,columns:1,textStart:0,textEnd:500)
        let next = ReaderBookmarkPage(index:1,count:10,columns:1,textStart:500,textEnd:1000)
        let reflow = ReaderBookmarkPage(index:1,count:20,columns:1,textStart:150,textEnd:300)
        #expect(initial.contains(mark,currentAnchor:nil,offset:0))
        #expect(!next.contains(mark,currentAnchor:nil,offset:0.1))
        #expect(reflow.contains(mark,currentAnchor:ReaderTextAnchor(start:150,quote:"新页首"),offset:0.05))
        #expect(mark.anchor?.start == 200)
        let boundary = ReaderBookmarkPage(index:2,count:20,columns:1,textStart:0,textEnd:200)
        #expect(!boundary.contains(mark,currentAnchor:nil,offset:0))
    }
    @Test func legacyBookmarksUseTheirRestoredSpread() {
        let mark = ReadingBookmark(title:"Old",position:0,offset:0.4)
        #expect(ReaderBookmarkPage(index:4,count:11,columns:2).contains(mark,currentAnchor:nil,offset:0))
        #expect(!ReaderBookmarkPage(index:6,count:11,columns:2).contains(mark,currentAnchor:nil,offset:0))
        #expect(ReaderBookmarkPage().contains(mark,currentAnchor:nil,offset:0))
    }
    @Test func returnStackDoesNotRecordReturnOperations() {
        let original = ReadingJumpPosition.epub(chapter:9,offset:0.4,anchor:ReaderTextAnchor(start:10000,quote:"原位置"))
        let bookmark = ReadingJumpPosition.epub(chapter:2,offset:0.3,anchor:ReaderTextAnchor(start:2500,quote:"书签"))
        var history = ReadingJumpHistory()
        history.remember(original); history.remember(bookmark); history.remember(bookmark)
        #expect(history.positions.count == 2)
        #expect(history.pop() == bookmark); #expect(history.pop() == original)
        #expect(history.pop() == nil); #expect(history.isEmpty)
    }
    @Test func pdfCoordinatesAndHistoryLimitArePreserved() {
        var history = ReadingJumpHistory()
        for page in 0..<40 { history.remember(.pdf(page:page,x:12,y:740,zoom:1.3)) }
        #expect(history.positions.count == 32)
        #expect(history.pop() == .pdf(page:39,x:12,y:740,zoom:1.3))
    }
    @Test func shelfFlagsSyncWithoutOverwritingReadingPosition() {
        var local = Book(title:"Book",filename:"book.epub",kind:"epub")
        local.position = 7; local.progress = 0.37; local.readerAnchor = ReaderTextAnchor(start:200,quote:"原文")
        var remote = local
        remote.shelf = ShelfBookPreferences(isRead:true,wantRead:true,coverStyle:"original",modifiedAt:Date(timeIntervalSince1970:100))
        let merged = CloudSyncEngine.mergeBooks(local:[local],remote:[remote],provider:.iCloud)
        #expect(merged[0].isFinished); #expect(merged[0].position == 7); #expect(merged[0].progress == 0.37)
        #expect(merged[0].readerAnchor == local.readerAnchor)
        #expect(merged[0].shelf?.coverStyle == "original")
    }
}
