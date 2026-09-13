import AppKit

@main
struct SelectionProbe {
    static func main() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let frames = [
            first: NSRect(x: 10, y: 10, width: 100, height: 100),
            second: NSRect(x: 130, y: 10, width: 100, height: 100),
            third: NSRect(x: 300, y: 300, width: 100, height: 100)
        ]
        let selected = NoteSelection.ids(
            intersecting: NSRect(x: 0, y: 0, width: 250, height: 130),
            noteFrames: frames
        )
        guard selected == Set([first, second]) else { exit(1) }

        let translated = NoteSelection.translatedFrames(
            frames,
            from: NSPoint(x: 10, y: 10),
            to: NSPoint(x: 35, y: 2)
        )
        guard translated[first]?.origin == NSPoint(x: 35, y: 2),
              translated[second]?.origin == NSPoint(x: 155, y: 2),
              translated[third]?.origin == NSPoint(x: 325, y: 292) else { exit(2) }

        let screen = NSRect(x: 0, y: 0, width: 500, height: 500)
        let accepted = NoteSelection.constrainedTranslation(
            frames,
            from: .zero,
            to: NSPoint(x: 30, y: 30),
            fallbackOffset: .zero,
            visibleFrames: [screen]
        )
        guard accepted.acceptedRequestedOffset, accepted.offset == NSPoint(x: 30, y: 30) else { exit(3) }

        let rejected = NoteSelection.constrainedTranslation(
            frames,
            from: .zero,
            to: NSPoint(x: 1_000, y: 1_000),
            fallbackOffset: NSPoint(x: 30, y: 30),
            visibleFrames: [screen]
        )
        guard !rejected.acceptedRequestedOffset,
              rejected.offset == NSPoint(x: 30, y: 30),
              NoteSelection.toolbarsRemainVisible(in: rejected.frames, visibleFrames: [screen]) else { exit(4) }

        let selectedPinTargets = NoteSelection.operationIDs(
            triggering: first,
            selectedIDs: Set([first, second])
        )
        guard selectedPinTargets == Set([first, second]) else { exit(5) }
        let unselectedPinTarget = NoteSelection.operationIDs(
            triggering: third,
            selectedIDs: Set([first, second])
        )
        guard unselectedPinTarget == Set([third]) else { exit(6) }
        let groupPin = NoteSelection.pinOperation(
            triggering: first,
            triggeringIsPinned: false,
            selectedIDs: Set([first, second])
        )
        guard groupPin.ids == Set([first, second]), groupPin.isPinned else { exit(7) }
        let groupUnpin = NoteSelection.pinOperation(
            triggering: first,
            triggeringIsPinned: true,
            selectedIDs: Set([first, second])
        )
        guard groupUnpin.ids == Set([first, second]), !groupUnpin.isPinned else { exit(8) }

        print("selection geometry: pass")
    }
}
