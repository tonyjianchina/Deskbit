import Foundation

@main
struct HistoryProbe {
    static func main() {
        var first = StickyNote.fresh(index: 0)
        first.text = "第一条"
        first.isPinned = true
        first.isHidden = true
        var second = StickyNote.fresh(index: 1)
        second.text = "第二条"
        var notes = [first, second]

        let legacyData = try! JSONEncoder().encode(first)
        let decodedLegacyNote = try! JSONDecoder().decode(StickyNote.self, from: legacyData)
        precondition(decodedLegacyNote.completedAt == nil)

        let earlier = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        precondition(NoteHistory.complete(id: first.id, in: &notes, at: earlier))
        precondition(NoteHistory.complete(id: second.id, in: &notes, at: later))
        precondition(NoteHistory.activeNotes(in: notes).isEmpty)
        precondition(NoteHistory.completedNotes(in: notes).map(\.id) == [second.id, first.id])

        precondition(NoteHistory.restore(id: first.id, in: &notes))
        guard let restored = notes.first(where: { $0.id == first.id }) else { exit(1) }
        precondition(restored.completedAt == nil)
        precondition(!restored.isHidden)
        precondition(!restored.isPinned)
        precondition(NoteHistory.activeNotes(in: notes).map(\.id) == [first.id])

        precondition(NoteHistory.permanentlyDelete(id: second.id, in: &notes))
        precondition(!notes.contains(where: { $0.id == second.id }))

        precondition(NoteHistory.complete(id: first.id, in: &notes, at: later))
        NoteHistory.clearCompleted(in: &notes)
        precondition(notes.isEmpty)

        print("history lifecycle: pass")
    }
}
