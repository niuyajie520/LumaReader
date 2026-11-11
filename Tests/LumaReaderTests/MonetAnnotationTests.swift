import Foundation
import Testing
@testable import LumaReader

struct MonetAnnotationTests {
    @Test func olderNotesDecodeAndInvalidColorsFallBack() throws {
        let original = ReadingNote(quote:"Old highlight",ink:.green)
        let encoded = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(ReadingNote.self,from:encoded)
        #expect(restored.colorHex == nil)
        #expect(restored.highlightHex == original.ink.hex)
        var invalid = restored; invalid.colorHex = "xyz123"
        #expect(invalid.highlightHex == original.ink.hex)
    }
    @Test func cloudRoundTripKeepsMonetColorAndCrossPageRange() throws {
        var note = ReadingNote(quote:"First page and continuation",ink:.yellow,chapter:2,start:32,end:1432)
        note.colorHex = "8C7862"
        var book = Book(title:"Book",filename:"book.epub",kind:"epub"); book.notes = [note]
        let restored = try JSONDecoder().decode(Book.self,from:JSONEncoder().encode(book))
        #expect(restored.notes.first?.highlightHex == "8C7862")
        #expect(restored.notes.first?.start == 32)
        #expect(restored.notes.first?.end == 1432)
        let merged = CloudSyncEngine.mergeBooks(local:[],remote:[restored],provider:.iCloud)
        #expect(merged.first?.notes.first?.colorHex == note.colorHex)
    }
}
