import Foundation

/// Target only the selected anchors/geometry; deleting never touches the book itself.
enum NoteActions {
    static func webTargets(_ notes:[ReadingNote],chapter:Int,start:Int,end:Int) -> [UUID] {
        guard start >= 0, end > start else { return [] }
        return notes.filter { note in
            guard note.chapter == chapter, let a = note.start, let b = note.end, a >= 0, b > a else { return false }
            return a < end && start < b
        }.map(\.id)
    }
    static func pdfTargets(_ notes:[ReadingNote],selection:[PageRect]) -> [UUID] {
        notes.filter { note in note.rects.contains { rect in
            selection.contains { selected in
                guard rect.page == selected.page, !rect.cgRect.isEmpty, !selected.cgRect.isEmpty else { return false }
                return !rect.cgRect.intersection(selected.cgRect).isEmpty
            }
        }}.map(\.id)
    }
    static func remove(_ ids:Set<UUID>,from book:inout Book,at date:Date) {
        let existing = book.notes.filter { ids.contains($0.id) }
        guard !existing.isEmpty else { return }
        book.notes.removeAll { ids.contains($0.id) }
        if book.deletedNotes == nil { book.deletedNotes = [:] }
        for note in existing { book.deletedNotes?[note.id.uuidString] = date }
    }
    static func restore(_ notes:[ReadingNote],in book:inout Book,at date:Date) {
        for note in notes where !book.notes.contains(where:{ $0.id == note.id }) {
            var restored = note; restored.modifiedAt = date
            book.notes.append(restored); book.deletedNotes?.removeValue(forKey:note.id.uuidString)
        }
    }
}
