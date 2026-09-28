import AppKit

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class Updater {
    static let shared = Updater()

    #if canImport(Sparkle)
    private let controller: SPUStandardUpdaterController?

    private init() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        guard feedURL?.isEmpty == false, publicKey?.isEmpty == false else {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        guard let controller else {
            showUnavailableAlert()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
    #else
    private init() {}

    var isAvailable: Bool { false }

    func checkForUpdates() {
        showUnavailableAlert()
    }
    #endif

    private func showUnavailableAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.text("updates.unavailableTitle")
        alert.informativeText = L10n.text("updates.unavailableBody")
        alert.runModal()
    }
}
