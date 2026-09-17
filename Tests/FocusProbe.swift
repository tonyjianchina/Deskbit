import AppKit

@main
struct FocusProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let window = StickyWindow(
            contentRect: NSRect(origin: .zero, size: NoteAppearance.defaultSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        StickyWindowPresentation.apply(isPinned: false, to: window)
        let unpinnedBehavior = window.level == .normal
            && !window.hidesOnDeactivate
            && !window.collectionBehavior.contains(.canJoinAllSpaces)
        StickyWindowPresentation.apply(isPinned: true, to: window)
        let pinnedBehavior = window.level == .floating
            && !window.hidesOnDeactivate
            && window.collectionBehavior.contains(.canJoinAllSpaces)
            && window.collectionBehavior.contains(.fullScreenAuxiliary)

        let peer = StickyWindow(
            contentRect: NSRect(x: 20, y: 20, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        peer.orderFrontRegardless()
        window.orderFrontRegardless()
        StickyWindowPresentation.transition(fromPinned: true, toPinned: false, window: window)
        let ordered = NSApp.orderedWindows
        let unpinMovesBack = ordered.firstIndex(of: peer).map { peerIndex in
            ordered.firstIndex(of: window).map { peerIndex < $0 } ?? false
        } ?? false

        let resident = StickyWindow(
            contentRect: NSRect(x: 40, y: 40, width: 180, height: 120),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        let originalContent = NSView(frame: resident.contentView?.bounds ?? .zero)
        resident.contentView = originalContent
        let residency = StickyWindowResidency(residentWindow: resident)
        let proxy = residency.beginPinnedPresentation {
            StickyWindow(
                contentRect: resident.frame,
                styleMask: resident.styleMask,
                backing: .buffered,
                defer: false
            )
        }
        let usesDedicatedPinnedProxy = proxy !== resident
            && residency.activeWindow === proxy
            && proxy.contentView === originalContent
            && resident.alphaValue == 0
            && resident.ignoresMouseEvents
            && resident.isVisible
        let movedProxyFrame = NSRect(x: 80, y: 90, width: 210, height: 150)
        proxy.setFrame(movedProxyFrame, display: false)
        let restored = residency.endPinnedPresentation()
        let restoresOriginalDesktopWindow = restored === resident
            && residency.activeWindow === resident
            && resident.contentView === originalContent
            && resident.alphaValue == 1
            && !resident.ignoresMouseEvents
            && resident.frame == movedProxyFrame
            && !proxy.isVisible

        let noteController = StickyWindowController(note: .fresh())
        let backgroundPeer = StickyWindow(
            contentRect: NSRect(x: 100, y: 100, width: 160, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        backgroundPeer.orderFrontRegardless()
        noteController.window?.orderFrontRegardless()
        noteController.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        let orderAfterResigningKey = NSApp.orderedWindows
        let keepsStandardOrderAfterResigningKey = noteController.window.flatMap { noteWindow in
            guard let noteIndex = orderAfterResigningKey.firstIndex(of: noteWindow),
                  let peerIndex = orderAfterResigningKey.firstIndex(of: backgroundPeer) else { return false }
            return noteIndex < peerIndex
        } ?? false

        print("canBecomeKey=\(window.canBecomeKey) canBecomeMain=\(window.canBecomeMain) unpinned=\(unpinnedBehavior) pinned=\(pinnedBehavior) unpinMovesBack=\(unpinMovesBack) dedicatedProxy=\(usesDedicatedPinnedProxy) restoresResident=\(restoresOriginalDesktopWindow) keepsOrderAfterBlur=\(keepsStandardOrderAfterResigningKey)")
        guard window.canBecomeKey,
              window.canBecomeMain,
              unpinnedBehavior,
              pinnedBehavior,
              unpinMovesBack,
              usesDedicatedPinnedProxy,
              restoresOriginalDesktopWindow,
              keepsStandardOrderAfterResigningKey else { exit(1) }
    }
}
