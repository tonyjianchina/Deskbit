import AppKit

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppController()
    application.delegate = delegate
    application.run()
}
