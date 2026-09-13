import Foundation

@MainActor
final class NoteStore {
    static let shared = NoteStore()

    private(set) var notes: [StickyNote] = []
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var fileURL: URL {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("DesktopSticky", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("notes.json")
    }

    private init() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([StickyNote].self, from: data) else { return }
        notes = decoded
    }

    func note(id: UUID) -> StickyNote? { notes.first { $0.id == id } }

    @discardableResult
    func add() -> StickyNote {
        let note = StickyNote.fresh(index: notes.count)
        notes.append(note)
        save()
        return note
    }

    func update(_ note: StickyNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var changed = note
        changed.updatedAt = Date()
        notes[index] = changed
        save()
    }

    func updateFrames(_ frames: [UUID: WindowFrame]) {
        guard !frames.isEmpty else { return }
        let now = Date()
        for index in notes.indices {
            guard let frame = frames[notes[index].id] else { continue }
            notes[index].frame = frame
            notes[index].updatedAt = now
        }
        save()
    }

    func remove(id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
