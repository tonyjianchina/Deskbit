import AppKit

final class SelectionOverlayView: NSView {
    private var selectionRect = NSRect.zero

    func update(start: NSPoint, end: NSPoint) {
        selectionRect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !selectionRect.isEmpty else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.10).setFill()
        NSBezierPath(rect: selectionRect).fill()
        NSColor.controlAccentColor.withAlphaComponent(0.8).setStroke()
        let outline = NSBezierPath(rect: selectionRect.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = 1
        outline.stroke()
    }
}

@MainActor
final class SelectionOverlayWindowController: NSWindowController {
    private let desktopFrame: NSRect
    private let overlayView: SelectionOverlayView

    init(desktopFrame: NSRect) {
        self.desktopFrame = desktopFrame
        let window = NSWindow(
            contentRect: desktopFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        overlayView = SelectionOverlayView(frame: NSRect(origin: .zero, size: desktopFrame.size))
        overlayView.autoresizingMask = [.width, .height]
        window.contentView = overlayView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func begin(at screenPoint: NSPoint) {
        update(to: screenPoint, from: screenPoint)
        window?.orderFrontRegardless()
    }

    func update(to screenPoint: NSPoint, from startPoint: NSPoint) {
        overlayView.update(start: localPoint(startPoint), end: localPoint(screenPoint))
    }

    private func localPoint(_ screenPoint: NSPoint) -> NSPoint {
        NSPoint(x: screenPoint.x - desktopFrame.minX, y: screenPoint.y - desktopFrame.minY)
    }
}
