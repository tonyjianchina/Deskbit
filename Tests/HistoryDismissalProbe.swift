import AppKit

@main
struct HistoryDismissalProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let popoverWindow = NSWindow()
        let otherWindow = NSWindow()
        var dismissCount = 0
        let monitor = HistoryPopoverDismissalMonitor(
            popoverWindow: { popoverWindow },
            onDismiss: { dismissCount += 1 }
        )

        monitor.handleLocalMouseDown(in: popoverWindow)
        guard dismissCount == 0 else { exit(1) }
        monitor.handleLocalMouseDown(in: otherWindow)
        guard dismissCount == 1 else { exit(2) }
        monitor.handleGlobalMouseDown()
        guard dismissCount == 2 else { exit(3) }

        print("history dismissal: pass")
    }
}
