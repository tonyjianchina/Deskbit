import AppKit

@main
struct AppearanceProbe {
    static func main() {
        guard NoteAppearance.defaultSize == NSSize(width: 300, height: 200) else { exit(1) }
        guard NoteAppearance.minimumSize == NSSize(width: 280, height: 160) else { exit(2) }
        guard NoteAppearance.bodyFontSize == 13 else { exit(3) }

        let font = NoteAppearance.bodyFont()
        guard font.pointSize == 13 else { exit(4) }
        let note = StickyNote.fresh()
        guard note.frame.rect.size == NoteAppearance.defaultSize else { exit(5) }
        print("appearance defaults: pass")
    }
}
