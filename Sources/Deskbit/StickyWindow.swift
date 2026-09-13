import AppKit

final class StickyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Keeps a normal window resident on its original Space while a separate
/// all-Spaces proxy presents the note in pinned mode.
@MainActor
final class StickyWindowResidency {
    let residentWindow: StickyWindow
    private(set) var pinnedWindow: StickyWindow?

    var activeWindow: StickyWindow { pinnedWindow ?? residentWindow }

    init(residentWindow: StickyWindow) {
        self.residentWindow = residentWindow
    }

    func beginPinnedPresentation(makeProxy: () -> StickyWindow) -> StickyWindow {
        if let pinnedWindow { return pinnedWindow }

        let content = residentWindow.contentView
        residentWindow.contentView = nil
        residentWindow.alphaValue = 0
        residentWindow.ignoresMouseEvents = true
        residentWindow.hasShadow = false
        StickyWindowPresentation.apply(isPinned: false, to: residentWindow)
        residentWindow.orderBack(nil)

        let proxy = makeProxy()
        proxy.contentView = content
        pinnedWindow = proxy
        return proxy
    }

    func endPinnedPresentation() -> StickyWindow {
        guard let proxy = pinnedWindow else { return residentWindow }

        let content = proxy.contentView
        proxy.contentView = nil
        residentWindow.setFrame(proxy.frame, display: false)
        residentWindow.contentView = content
        residentWindow.alphaValue = 1
        residentWindow.ignoresMouseEvents = false
        residentWindow.hasShadow = true
        StickyWindowPresentation.apply(isPinned: false, to: residentWindow)

        proxy.orderOut(nil)
        proxy.close()
        pinnedWindow = nil
        residentWindow.orderBack(nil)
        return residentWindow
    }

    func closeAll() {
        pinnedWindow?.close()
        pinnedWindow = nil
        residentWindow.close()
    }
}

@MainActor
enum StickyWindowPresentation {
    static func apply(isPinned: Bool, to window: NSWindow) {
        window.level = isPinned ? .floating : .normal
        window.hidesOnDeactivate = false
        window.collectionBehavior = isPinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }

    static func transition(fromPinned: Bool, toPinned: Bool, window: NSWindow) {
        apply(isPinned: toPinned, to: window)
        if fromPinned && !toPinned {
            window.orderBack(nil)
        }
    }
}
