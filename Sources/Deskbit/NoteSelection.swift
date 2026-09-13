import AppKit

enum NoteSelection {
    struct PinOperation {
        let ids: Set<UUID>
        let isPinned: Bool
    }

    struct GroupTranslation {
        let frames: [UUID: NSRect]
        let offset: NSPoint
        let acceptedRequestedOffset: Bool
    }

    static func ids(intersecting selection: NSRect, noteFrames: [UUID: NSRect]) -> Set<UUID> {
        Set(noteFrames.compactMap { id, frame in frame.intersects(selection) ? id : nil })
    }

    static func operationIDs(triggering id: UUID, selectedIDs: Set<UUID>) -> Set<UUID> {
        selectedIDs.contains(id) ? selectedIDs : Set([id])
    }

    static func pinOperation(
        triggering id: UUID,
        triggeringIsPinned: Bool,
        selectedIDs: Set<UUID>
    ) -> PinOperation {
        PinOperation(
            ids: operationIDs(triggering: id, selectedIDs: selectedIDs),
            isPinned: !triggeringIsPinned
        )
    }

    static func translatedFrames(
        _ frames: [UUID: NSRect],
        from start: NSPoint,
        to current: NSPoint
    ) -> [UUID: NSRect] {
        let delta = NSPoint(x: current.x - start.x, y: current.y - start.y)
        return frames.mapValues { frame in
            frame.offsetBy(dx: delta.x, dy: delta.y)
        }
    }

    static func constrainedTranslation(
        _ frames: [UUID: NSRect],
        from start: NSPoint,
        to current: NSPoint,
        fallbackOffset: NSPoint,
        visibleFrames: [NSRect]
    ) -> GroupTranslation {
        let requestedOffset = NSPoint(x: current.x - start.x, y: current.y - start.y)
        let requestedFrames = offset(frames, by: requestedOffset)
        if toolbarsRemainVisible(in: requestedFrames, visibleFrames: visibleFrames) {
            return GroupTranslation(frames: requestedFrames, offset: requestedOffset, acceptedRequestedOffset: true)
        }
        return GroupTranslation(
            frames: offset(frames, by: fallbackOffset),
            offset: fallbackOffset,
            acceptedRequestedOffset: false
        )
    }

    static func toolbarsRemainVisible(in frames: [UUID: NSRect], visibleFrames: [NSRect]) -> Bool {
        frames.values.allSatisfy { frame in
            let toolbarHeight = min(40, frame.height)
            let toolbar = NSRect(x: frame.minX, y: frame.maxY - toolbarHeight, width: frame.width, height: toolbarHeight)
            let requiredWidth = min(80, toolbar.width)
            let requiredHeight = min(20, toolbar.height)
            return visibleFrames.contains { screen in
                let visible = toolbar.intersection(screen)
                return visible.width >= requiredWidth && visible.height >= requiredHeight
            }
        }
    }

    private static func offset(_ frames: [UUID: NSRect], by delta: NSPoint) -> [UUID: NSRect] {
        frames.mapValues { $0.offsetBy(dx: delta.x, dy: delta.y) }
    }
}
