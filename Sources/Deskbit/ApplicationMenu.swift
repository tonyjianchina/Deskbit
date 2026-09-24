import AppKit

@MainActor
enum ApplicationMenu {
    static func make() -> NSMenu {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.text("menu.about"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        addEditSubmenu(to: mainMenu)

        return mainMenu
    }

    static func addEditSubmenu(to menu: NSMenu) {
        let editItem = NSMenuItem(title: L10n.text("menu.edit"), action: nil, keyEquivalent: "")
        editItem.submenu = makeEditMenu()
        menu.addItem(editItem)
    }

    private static func makeEditMenu() -> NSMenu {
        let editMenu = NSMenu(title: L10n.text("menu.edit"))
        editMenu.addItem(command(L10n.text("menu.undo"), action: Selector(("undo:")), key: "z"))
        editMenu.addItem(command(L10n.text("menu.redo"), action: Selector(("redo:")), key: "z", modifiers: [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(command(L10n.text("menu.cut"), action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(command(L10n.text("menu.copy"), action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(command(L10n.text("menu.paste"), action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(command(L10n.text("menu.selectAll"), action: #selector(NSText.selectAll(_:)), key: "a"))
        return editMenu
    }

    private static func command(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}
