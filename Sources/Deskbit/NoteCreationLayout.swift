import AppKit

enum NoteCreationLayout {
    static func frame(
        near source: NSRect,
        size requestedSize: NSSize,
        in visibleFrame: NSRect,
        margin: CGFloat = 16,
        gap: CGFloat = 12
    ) -> NSRect {
        let bounds = visibleFrame.insetBy(dx: margin, dy: margin)
        let size = NSSize(
            width: min(requestedSize.width, bounds.width),
            height: min(requestedSize.height, bounds.height)
        )
        let topAlignedY = source.maxY - size.height
        let candidates = [
            NSPoint(x: source.maxX + gap, y: topAlignedY),
            NSPoint(x: source.minX, y: source.minY - gap - size.height),
            NSPoint(x: source.minX - gap - size.width, y: topAlignedY),
            NSPoint(x: source.minX, y: source.maxY + gap)
        ]

        for origin in candidates {
            let candidate = NSRect(origin: origin, size: size)
            if bounds.contains(candidate) { return candidate }
        }

        let cascaded = NSPoint(x: source.minX + 26, y: source.minY - 26)
        return NSRect(
            x: min(max(cascaded.x, bounds.minX), bounds.maxX - size.width),
            y: min(max(cascaded.y, bounds.minY), bounds.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }
}
