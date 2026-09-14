import Foundation

enum NoteHistory {
    static func activeNotes(in notes: [StickyNote]) -> [StickyNote] {
        notes.filter { $0.completedAt == nil }
    }

    static func completedNotes(in notes: [StickyNote]) -> [StickyNote] {
        notes
            .filter { $0.completedAt != nil }
            .sorted { lhs, rhs in
                let leftDate = lhs.completedAt ?? .distantPast
                let rightDate = rhs.completedAt ?? .distantPast
                if leftDate == rightDate { return lhs.id.uuidString < rhs.id.uuidString }
                return leftDate > rightDate
            }
    }

    @discardableResult
    static func complete(id: UUID, in notes: inout [StickyNote], at date: Date = Date()) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id && $0.completedAt == nil }) else { return false }
        notes[index].completedAt = date
        notes[index].updatedAt = date
        notes[index].isPinned = false
        notes[index].isHidden = true
        notes[index].reminderDate = nil
        return true
    }

    @discardableResult
    static func restore(id: UUID, in notes: inout [StickyNote], at date: Date = Date()) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id && $0.completedAt != nil }) else { return false }
        notes[index].completedAt = nil
        notes[index].updatedAt = date
        notes[index].isPinned = false
        notes[index].isHidden = false
        return true
    }

    @discardableResult
    static func permanentlyDelete(id: UUID, in notes: inout [StickyNote]) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id && $0.completedAt != nil }) else { return false }
        notes.remove(at: index)
        return true
    }

    static func clearCompleted(in notes: inout [StickyNote]) {
        notes.removeAll { $0.completedAt != nil }
    }
}
