import AppKit

@main
struct NoteCreationLayoutProbe {
    static func main() {
        let primary = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let source = NSRect(x: 100, y: 500, width: 300, height: 200)
        let besideSource = NoteCreationLayout.frame(
            near: source,
            size: NSSize(width: 300, height: 200),
            in: primary
        )
        guard besideSource == NSRect(x: 412, y: 500, width: 300, height: 200) else { exit(1) }

        let sourceNearRightEdge = NSRect(x: 1120, y: 500, width: 300, height: 200)
        let belowSource = NoteCreationLayout.frame(
            near: sourceNearRightEdge,
            size: NSSize(width: 300, height: 200),
            in: primary
        )
        guard belowSource == NSRect(x: 1120, y: 288, width: 300, height: 200) else { exit(2) }

        let secondary = NSRect(x: 1440, y: -120, width: 1200, height: 800)
        let sourceOnSecondary = NSRect(x: 1500, y: 300, width: 300, height: 200)
        let onSecondary = NoteCreationLayout.frame(
            near: sourceOnSecondary,
            size: NSSize(width: 300, height: 200),
            in: secondary
        )
        guard secondary.insetBy(dx: 16, dy: 16).contains(onSecondary),
              onSecondary.minX == sourceOnSecondary.maxX + 12 else { exit(3) }

        print("note creation layout: pass")
    }
}
