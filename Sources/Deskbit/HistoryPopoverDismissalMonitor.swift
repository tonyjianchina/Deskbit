import AppKit

@MainActor
final class HistoryPopoverDismissalMonitor {
    private let popoverWindow: () -> NSWindow?
    private let onDismiss: () -> Void
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(popoverWindow: @escaping () -> NSWindow?, onDismiss: @escaping () -> Void) {
        self.popoverWindow = popoverWindow
        self.onDismiss = onDismiss
    }

    func start() {
        stop()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            self?.handleLocalMouseDown(in: event.window)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            self?.handleGlobalMouseDown()
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    func handleLocalMouseDown(in window: NSWindow?) {
        guard window !== popoverWindow() else { return }
        onDismiss()
    }

    func handleGlobalMouseDown() {
        onDismiss()
    }
}
