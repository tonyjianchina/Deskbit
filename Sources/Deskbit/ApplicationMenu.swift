import AppKit

@MainActor
enum ApplicationMenu {
    static func make() -> NSMenu {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Deskbit", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Deskbit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        addEditSubmenu(to: mainMenu)

        return mainMenu
    }

    static func addEditSubmenu(to menu: NSMenu) {
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        editItem.submenu = makeEditMenu()
        menu.addItem(editItem)
    }

    private static func makeEditMenu() -> NSMenu {
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(command("撤销", action: Selector(("undo:")), key: "z"))
        editMenu.addItem(command("重做", action: Selector(("redo:")), key: "z", modifiers: [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(command("剪切", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(command("复制", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(command("粘贴", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(command("全选", action: #selector(NSText.selectAll(_:)), key: "a"))
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
