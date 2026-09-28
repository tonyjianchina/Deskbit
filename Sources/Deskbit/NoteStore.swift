import Foundation

enum NoteStorage {
    static func resolveFileURL(in base: URL, manager: FileManager = .default) -> URL {
        let currentDirectory = base.appendingPathComponent("Deskbit", isDirectory: true)
        let currentFile = currentDirectory.appendingPathComponent("notes.json")
        if manager.fileExists(atPath: currentFile.path) {
            return currentFile
        }

        let legacyDirectoryName = ["Desktop", "Sticky"].joined()
        let legacyFile = base
            .appendingPathComponent(legacyDirectoryName, isDirectory: true)
            .appendingPathComponent("notes.json")

        if manager.fileExists(atPath: legacyFile.path) {
            do {
                try manager.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
                try manager.copyItem(at: legacyFile, to: currentFile)
                return currentFile
            } catch {
                return legacyFile
            }
        }

        try? manager.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        return currentFile
    }
}

@MainActor
final class NoteStore {
    static let shared = NoteStore()

    private(set) var notes: [StickyNote] = []
    private(set) var isFirstLaunch: Bool
    private let fileURL: URL
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

    init(baseURL: URL? = nil, manager: FileManager = .default) {
        let base = baseURL ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = NoteStorage.resolveFileURL(in: base, manager: manager)
        isFirstLaunch = !manager.fileExists(atPath: fileURL.path)
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([StickyNote].self, from: data) else { return }
        notes = decoded
    }

    var activeNotes: [StickyNote] { NoteHistory.activeNotes(in: notes) }
    var completedNotes: [StickyNote] { NoteHistory.completedNotes(in: notes) }

    func note(id: UUID) -> StickyNote? { notes.first { $0.id == id } }

    @discardableResult
    func add(frame: NSRect? = nil, text: String = "") -> StickyNote {
        var note = StickyNote.fresh(index: notes.count, frame: frame)
        note.text = text
        notes.append(note)
        save()
        return note
    }

    @discardableResult
    func add(frame: NSRect? = nil, attributedText: NSAttributedString) -> StickyNote {
        var note = StickyNote.fresh(index: notes.count, frame: frame)
        note.text = attributedText.string
        note.richTextData = RichTextCodec.encode(attributedText)
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

    @discardableResult
    func complete(id: UUID) -> Bool {
        guard NoteHistory.complete(id: id, in: &notes) else { return false }
        save()
        return true
    }

    func restore(id: UUID) -> StickyNote? {
        guard NoteHistory.restore(id: id, in: &notes) else { return nil }
        save()
        return note(id: id)
    }

    @discardableResult
    func permanentlyDelete(id: UUID) -> Bool {
        guard NoteHistory.permanentlyDelete(id: id, in: &notes) else { return false }
        save()
        return true
    }

    func clearCompleted() {
        NoteHistory.clearCompleted(in: &notes)
        save()
    }

    private func save() {
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
