import AppKit

@main
struct ShortcutProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let editor = StickyTextView()
        var boldCount = 0
        var bulletCount = 0
        var strikeCount = 0
        var indentationDeltas: [Int] = []
        editor.onToggleBold = { boldCount += 1 }
        editor.onToggleBulletList = { bulletCount += 1 }
        editor.onToggleStrikethrough = { strikeCount += 1 }
        editor.onAdjustBulletLevel = { delta in
            indentationDeltas.append(delta)
            return true
        }

        let plainAsterisk = keyEvent(modifiers: [.shift], characters: "*", ignoringModifiers: "*")
        _ = editor.performKeyEquivalent(with: plainAsterisk)
        let markdownAsteriskPassedThrough = bulletCount == 0

        let bold = keyEvent(modifiers: [.command], characters: "b", ignoringModifiers: "b")
        _ = editor.performKeyEquivalent(with: bold)

        let bullet = keyEvent(modifiers: [.command, .shift], characters: "*", ignoringModifiers: "*")
        _ = editor.performKeyEquivalent(with: bullet)

        let strike = keyEvent(modifiers: [.command, .shift], characters: "x", ignoringModifiers: "x")
        _ = editor.performKeyEquivalent(with: strike)

        editor.insertTab(nil)
        editor.insertBacktab(nil)

        let editingShortcuts = [
            StickyEditingShortcut.command(for: [.command], key: "c"),
            StickyEditingShortcut.command(for: [.command], key: "x"),
            StickyEditingShortcut.command(for: [.command], key: "v"),
            StickyEditingShortcut.command(for: [.command], key: "a")
        ]

        print("boldShortcut=\(boldCount == 1) bulletShortcut=\(bulletCount == 1) strikeShortcut=\(strikeCount == 1) markdownAsterisk=\(markdownAsteriskPassedThrough) nestingShortcuts=\(indentationDeltas == [1, -1]) editingShortcuts=\(editingShortcuts == [.copy, .cut, .paste, .selectAll])")
        guard boldCount == 1,
              bulletCount == 1,
              strikeCount == 1,
              markdownAsteriskPassedThrough,
              indentationDeltas == [1, -1],
              editingShortcuts == [.copy, .cut, .paste, .selectAll] else { exit(1) }
    }

    private static func keyEvent(modifiers: NSEvent.ModifierFlags, characters: String, ignoringModifiers: String) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: ignoringModifiers,
            isARepeat: false,
            keyCode: 0
        )!
    }
}
