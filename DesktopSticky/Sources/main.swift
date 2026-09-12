import AppKit

// 入口：菜单栏应用（无 Dock 图标）
// 单实例保护：若已有同 bundle id 的实例在运行，直接退出，避免多实例写同一数据文件造成数据错乱
let bundleID = Bundle.main.bundleIdentifier ?? "com.codex.desktopsticky"
let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
let current = NSRunningApplication.current
let others = running.filter { $0.processIdentifier != current.processIdentifier }
if !others.isEmpty {
    others.first?.activate(options: [.activateIgnoringOtherApps])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
