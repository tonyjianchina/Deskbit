import AppKit

@MainActor
@objc protocol DeskbitStatusMenuTarget: AnyObject {
    func newNoteFromMenu()
    func arrangeNotes()
    func showHistoryFromMenu()
    func showAllNotes()
    func showFeedbackFromMenu()
    func changeLanguage(_ sender: NSMenuItem)
    func quit()
}

@MainActor
enum DeskbitStatusMenu {
    static func make(target: DeskbitStatusMenuTarget, hiddenMenu: NSMenuItem) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(L10n.text("menu.newNote"), action: #selector(DeskbitStatusMenuTarget.newNoteFromMenu), key: "n", target: target))
        menu.addItem(item(
            L10n.text("menu.arrange"),
            action: #selector(DeskbitStatusMenuTarget.arrangeNotes),
            symbol: "rectangle.3.group",
            target: target
        ))
        menu.addItem(item(
            L10n.text("menu.history"),
            action: #selector(DeskbitStatusMenuTarget.showHistoryFromMenu),
            symbol: "clock.arrow.circlepath",
            target: target
        ))
        menu.addItem(item(L10n.text("menu.showAll"), action: #selector(DeskbitStatusMenuTarget.showAllNotes), key: "0", target: target))
        hiddenMenu.target = target
        menu.addItem(hiddenMenu)
        menu.addItem(.separator())
        menu.addItem(item(
            L10n.text("menu.feedback"),
            action: #selector(DeskbitStatusMenuTarget.showFeedbackFromMenu),
            symbol: "bubble.left.and.bubble.right",
            target: target
        ))
        menu.addItem(.separator())
        let languageItem = NSMenuItem(title: L10n.text("language.title"), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in AppLanguage.allCases {
            let option = item(language.title, action: #selector(DeskbitStatusMenuTarget.changeLanguage(_:)), target: target)
            option.representedObject = language.rawValue
            option.state = L10n.preference == language ? .on : .off
            languageMenu.addItem(option)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        menu.addItem(item(L10n.text("menu.quit"), action: #selector(DeskbitStatusMenuTarget.quit), key: "q", target: target))
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
