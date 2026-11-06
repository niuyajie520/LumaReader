import Foundation
import Testing
@testable import LumaReader

struct NoteActionsTests {
    @Test func overlapRespectsUTF16BoundariesAndChapter() {
        var first = ReadingNote(quote:"📖推理",ink:.yellow); first.start = 0; first.end = 4
        var adjacent = ReadingNote(quote:"相邻",ink:.blue); adjacent.start = 4; adjacent.end = 6
        var other = first; other.id = UUID(); other.chapter = 1
        #expect(NoteActions.webTargets([first,adjacent,other],chapter:0,start:1,end:4) == [first.id])
        #expect(NoteActions.webTargets([first],chapter:0,start:4,end:5).isEmpty)
        #expect(NoteActions.webTargets([first],chapter:0,start:-1,end:4).isEmpty)
    }
    @Test func pdfSelectionOnlyTargetsIntersectingPage() {
        var note = ReadingNote(quote:"正文",ink:.pink)
        note.rects = [PageRect(page:1,x:10,y:10,width:30,height:15)]
        #expect(NoteActions.pdfTargets([note],selection:[PageRect(page:0,x:10,y:10,width:30,height:15)]).isEmpty)
        #expect(NoteActions.pdfTargets([note],selection:[PageRect(page:1,x:20,y:12,width:10,height:10)]) == [note.id])
        #expect(NoteActions.pdfTargets([note],selection:[PageRect(page:1,x:40,y:10,width:10,height:10)]).isEmpty)
    }
    @Test func batchDeletionAndUndoPreserveOtherNotesAndSyncTombstones() {
        var book = Book(title:"Book",filename:"book.epub",kind:"epub")
        let a = ReadingNote(quote:"one",ink:.yellow), b = ReadingNote(quote:"two",ink:.blue), c = ReadingNote(quote:"keep",ink:.pink)
        book.notes = [a,b,c]; let date = Date(timeIntervalSince1970:1000)
        NoteActions.remove([a.id,b.id],from:&book,at:date)
        #expect(book.notes == [c]); #expect(book.deletedNotes?.count == 2)
        NoteActions.remove([a.id],from:&book,at:date.addingTimeInterval(1))
        #expect(book.deletedNotes?[a.id.uuidString] == date)
        NoteActions.restore([a,b],in:&book,at:date.addingTimeInterval(2))
        NoteActions.restore([a,b],in:&book,at:date.addingTimeInterval(3))
        #expect(book.notes.count == 3); #expect(book.deletedNotes?.isEmpty == true)
        #expect(book.notes.first(where:{$0.id == a.id})?.modifiedAt == date.addingTimeInterval(2))
    }
}
