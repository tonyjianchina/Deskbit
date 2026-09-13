import Foundation

@main
struct StorageProbe {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }

        let legacyDirectoryName = ["Desktop", "Sticky"].joined()

        let migrationBase = root.appendingPathComponent("migration", isDirectory: true)
        let legacyDirectory = migrationBase.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        try manager.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacyFile = legacyDirectory.appendingPathComponent("notes.json")
        let savedNotes = Data("saved notes".utf8)
        try savedNotes.write(to: legacyFile)

        let migratedFile = NoteStorage.resolveFileURL(in: migrationBase, manager: manager)
        precondition(migratedFile == migrationBase.appendingPathComponent("Deskbit/notes.json"))
        let migratedNotes = try Data(contentsOf: migratedFile)
        precondition(migratedNotes == savedNotes)

        let fallbackBase = root.appendingPathComponent("fallback", isDirectory: true)
        let fallbackLegacyDirectory = fallbackBase.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        try manager.createDirectory(at: fallbackLegacyDirectory, withIntermediateDirectories: true)
        let fallbackLegacyFile = fallbackLegacyDirectory.appendingPathComponent("notes.json")
        try savedNotes.write(to: fallbackLegacyFile)
        try manager.createDirectory(at: fallbackBase, withIntermediateDirectories: true)
        try Data("blocked".utf8).write(to: fallbackBase.appendingPathComponent("Deskbit"))

        let fallbackFile = NoteStorage.resolveFileURL(in: fallbackBase, manager: manager)
        precondition(fallbackFile == fallbackLegacyFile)
        let fallbackNotes = try Data(contentsOf: fallbackFile)
        precondition(fallbackNotes == savedNotes)

        print("storage migration: pass")
    }
}
