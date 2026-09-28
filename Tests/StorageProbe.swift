import Foundation

@main
struct StorageProbe {
    @MainActor
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

        let firstLaunchBase = root.appendingPathComponent("first-launch", isDirectory: true)
        let firstLaunchStore = NoteStore(baseURL: firstLaunchBase, manager: manager)
        precondition(firstLaunchStore.isFirstLaunch)
        let guide = firstLaunchStore.add(text: "Welcome to Deskbit")
        precondition(guide.text == "Welcome to Deskbit")

        let reopenedStore = NoteStore(baseURL: firstLaunchBase, manager: manager)
        precondition(!reopenedStore.isFirstLaunch)
        precondition(reopenedStore.activeNotes.map(\.text) == ["Welcome to Deskbit"])

        print("storage migration and first-launch detection: pass")
    }
}
