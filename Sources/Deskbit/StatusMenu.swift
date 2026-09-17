import AppKit

@MainActor
@objc protocol DeskbitStatusMenuTarget: AnyObject {
    func newNoteFromMenu()
    func arrangeNotes()
    func showHistoryFromMenu()
    func showAllNotes()
    func showFeedbackFromMenu()
    func quit()
}

@MainActor
enum DeskbitStatusMenu {
    static func make(target: DeskbitStatusMenuTarget, hiddenMenu: NSMenuItem) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("新建便签", action: #selector(DeskbitStatusMenuTarget.newNoteFromMenu), key: "n", target: target))
        menu.addItem(item(
            "自动排序便签",
            action: #selector(DeskbitStatusMenuTarget.arrangeNotes),
            symbol: "rectangle.3.group",
            target: target
        ))
        menu.addItem(item(
            "历史便签",
            action: #selector(DeskbitStatusMenuTarget.showHistoryFromMenu),
            symbol: "clock.arrow.circlepath",
            target: target
        ))
        menu.addItem(item("显示所有便签", action: #selector(DeskbitStatusMenuTarget.showAllNotes), key: "0", target: target))
        hiddenMenu.target = target
        menu.addItem(hiddenMenu)
        menu.addItem(.separator())
        menu.addItem(item(
            "用户反馈",
            action: #selector(DeskbitStatusMenuTarget.showFeedbackFromMenu),
            symbol: "bubble.left.and.bubble.right",
            target: target
        ))
        menu.addItem(.separator())
        menu.addItem(item("退出 Deskbit", action: #selector(DeskbitStatusMenuTarget.quit), key: "q", target: target))
        return menu
    }

    private static func item(
        _ title: String,
        action: Selector,
        key: String = "",
        symbol: String? = nil,
        target: DeskbitStatusMenuTarget
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        }
        return item
    }
}
