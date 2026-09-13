import AppKit

@main
struct WindowLayoutProbe {
    static func main() {
        let screen = NSRect(x: 0, y: 0, width: 1200, height: 800)
        let frames = NoteWindowLayout.alignedFrames(
            sizes: [
                NSSize(width: 300, height: 200),
                NSSize(width: 300, height: 200),
                NSSize(width: 300, height: 200),
                NSSize(width: 300, height: 200),
                NSSize(width: 300, height: 200)
            ],
            in: screen
        )

        guard frames.count == 5 else { exit(1) }
        guard frames[0].minX == 16,
              frames[1].minX == 16,
              frames[2].minX == 16,
              frames[3].minX == 16 else { exit(2) }
        guard frames[0].maxY == 784 else { exit(3) }
        guard frames[1].maxY == frames[0].minY - 12 else { exit(4) }
        guard frames[3].minY == 16 else { exit(5) }
        guard frames[4].minX == 328, frames[4].maxY == 784 else { exit(6) }

        let oversized = NoteWindowLayout.alignedFrames(
            sizes: [NSSize(width: 2000, height: 1000)],
            in: screen
        )[0]
        guard oversized == NSRect(x: 16, y: 16, width: 1168, height: 768) else { exit(7) }

        let manyFrames = NoteWindowLayout.alignedFrames(
            sizes: Array(repeating: NSSize(width: 300, height: 200), count: 12),
            in: screen
        )
        guard manyFrames.allSatisfy({ screen.insetBy(dx: 16, dy: 16).contains($0) }) else { exit(8) }
        let rowsByColumn = Dictionary(grouping: manyFrames, by: { $0.minX })
        guard rowsByColumn.values.allSatisfy({ $0.count <= 4 }) else { exit(9) }
        for firstIndex in manyFrames.indices {
            for secondIndex in manyFrames.indices where secondIndex > firstIndex {
                guard !manyFrames[firstIndex].intersects(manyFrames[secondIndex]) else { exit(10) }
            }
        }

        print("window layout: pass")
    }
}
