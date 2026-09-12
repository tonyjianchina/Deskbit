import Foundation
import AppKit

/// 便签数据持久化：保存在 ~/Library/Application Support/com.codex.desktopsticky/notes.json
/// 与原始应用使用相同的 bundle id 与目录，便于复用已有数据。
final class NoteStore {

    static let shared = NoteStore()

    /// 数据目录（与原始应用一致）
    static var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("com.codex.desktopsticky", isDirectory: true)
    }

    static var dataFileURL: URL {
        return dataDirectory.appendingPathComponent("notes.json")
    }

    private(set) var notes: [Note] = []

    /// 变更后的自动保存（防抖）
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "note.store.save", qos: .utility)

    init() {
        load()
    }

    // MARK: - 读写

    func load() {
        let url = Self.dataFileURL
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            let file = try JSONDecoder().decode(NotesFile.self, from: data)
            notes = file.notes
            NSLog("NoteStore loaded %d notes from %@", notes.count, url.path)
        } catch {
            NSLog("NoteStore load failed: %@", error.localizedDescription)
        }
    }

    func saveNow() {
        saveWorkItem?.cancel()
        let snapshot = notes
        saveQueue.async {
            let url = Self.dataFileURL
            do {
                try FileManager.default.createDirectory(at: Self.dataDirectory,
                                                        withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let file = NotesFile(notes: snapshot)
                let data = try encoder.encode(file)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("NoteStore save failed: %@", error.localizedDescription)
            }
        }
    }

    /// 防抖保存：连续编辑时最后才落盘
    func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = item
        saveQueue.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    // MARK: - CRUD

    @discardableResult
    func add(_ note: Note) -> Note {
        notes.append(note)
        scheduleSave()
        return note
    }

    func update(_ note: Note) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var n = note
        n.updatedAt = Date().timeIntervalSince1970 * 1000
        notes[idx] = n
        scheduleSave()
    }

    func remove(id: String) {
        notes.removeAll { $0.id == id }
        scheduleSave()
    }

    func note(id: String) -> Note? {
        return notes.first { $0.id == id }
    }
}
