import AppKit

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
        let attributedGuide = NSMutableAttributedString(string: "Welcome to Deskbit")
        attributedGuide.addAttribute(
            .font,
            value: NoteAppearance.bodyFont(weight: .bold),
            range: NSRange(location: 0, length: 7)
        )
        let guide = firstLaunchStore.add(attributedText: attributedGuide)
        precondition(guide.text == "Welcome to Deskbit")
        precondition(guide.richTextData != nil)

        let reopenedStore = NoteStore(baseURL: firstLaunchBase, manager: manager)
        precondition(!reopenedStore.isFirstLaunch)
        precondition(reopenedStore.activeNotes.map(\.text) == ["Welcome to Deskbit"])
        let restoredGuide = RichTextCodec.decode(reopenedStore.activeNotes.first?.richTextData)
        let restoredFont = restoredGuide?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        precondition(restoredFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true)

        print("storage migration and first-launch detection: pass")
    }
}
