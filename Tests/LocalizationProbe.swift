import AppKit

@main
struct LocalizationProbe {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        // Override only this process; never change the installed app's preferences.
        func select(_ language: AppLanguage) {
            UserDefaults.standard.setVolatileDomain([L10n.preferenceKey: language.rawValue], forName: UserDefaults.argumentDomain)
        }
        defer { UserDefaults.standard.removeVolatileDomain(forName: UserDefaults.argumentDomain) }

        precondition(L10n.resolve(.system, preferredLanguages: ["fr-FR", "en-GB", "zh-CN"]) == .english)
        precondition(L10n.resolve(.system, preferredLanguages: ["de", "zh_Hans_CN", "en"]) == .simplifiedChinese)
        precondition(L10n.resolve(.system, preferredLanguages: ["ja-JP"]) == .english)
        precondition(L10n.resolve(.system, preferredLanguages: []) == .english)
        precondition(L10n.resolve(.english, preferredLanguages: ["zh-CN"]) == .english)
        precondition(L10n.resolve(.simplifiedChinese, preferredLanguages: ["en-US"]) == .simplifiedChinese)

        let languages = [AppLanguage.english, .simplifiedChinese]
        var keys: Set<String>?
        for language in languages {
            let path = L10n.resourceBundle.path(forResource: language.rawValue, ofType: "lproj")!
            let data = try Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("Localizable.strings"))
            let strings = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
            precondition(strings.count >= 60)
            precondition(strings.values.allSatisfy { !$0.isEmpty })
            if let keys { precondition(keys == Set(strings.keys)) }
            keys = Set(strings.keys)
            select(language)
            for (key, value) in strings { precondition(L10n.text(key) == value, key) }
        }
        select(.english)
        precondition(L10n.noteCount(0) == "0 notes")
        precondition(L10n.noteCount(1) == "1 note")
        precondition(L10n.noteCount(2) == "2 notes")
        precondition(FeedbackSubmission.Error.rejected(statusCode: 503).localizedDescription.contains("503"))
        precondition(ApplicationMenu.make().items[1].title == "Edit")

        let target = LocalizationMenuTarget()
        let hidden = NSMenuItem(title: L10n.text("menu.showHidden"), action: nil, keyEquivalent: "")
        let menu = DeskbitStatusMenu.make(target: target, hiddenMenu: hidden)
        precondition(menu.items.first?.title == "New Note")
        let languageMenu = menu.items.first(where: { $0.title == "Language" })!.submenu!
        precondition(languageMenu.items.map(\.title) == ["Follow System", "English", "简体中文"])
        precondition(languageMenu.items[1].state == .on)
        precondition(languageMenu.items.allSatisfy { $0.action == #selector(LocalizationMenuTarget.changeLanguage(_:)) })

        var note = StickyNote.fresh(frame: NSRect(x: 40, y: 40, width: 280, height: 180))
        note.text = "Keep this text 原始便签 ✍️"
        let controller = StickyWindowController(note: note)
        let root = controller.window!.contentView as! StickyRootView
        root.textView.setSelectedRange(NSRange(location: 5, length: 4))
        let originalContent = root.textView.attributedString()
        let originalSelection = root.textView.selectedRange()
        let originalFrame = controller.window!.frame
        precondition(root.textView.accessibilityLabel() == "Note Content")

        select(.simplifiedChinese)
        controller.refreshLocalization()
        precondition(root.textView.accessibilityLabel() == "便签内容")
        precondition(root.statusLabel.stringValue == "已保存")
        precondition(L10n.noteCount(2) == "2 条")
        precondition(ApplicationMenu.make().items[1].title == "编辑")
        precondition(root.textView.attributedString().isEqual(to: originalContent))
        precondition(root.textView.selectedRange() == originalSelection)
        precondition(controller.window!.frame == originalFrame)

        select(.english)
        controller.refreshLocalization()
        root.toolbar.update(color: .yellow, isPinned: true)
        let buttons = descendants(root.toolbar).compactMap { $0 as? NSButton }
        precondition(buttons.contains { $0.accessibilityLabel() == "Unpin" })
        root.statusLabel.stringValue = L10n.text("note.pinnedSaved")
        root.layoutSubtreeIfNeeded()
        precondition(root.statusLabel.frame.maxX <= root.bounds.maxX)
        precondition(root.textView.attributedString().isEqual(to: originalContent))
        precondition(root.textView.selectedRange() == originalSelection)
        controller.close()
        print("localization: resource parity, language resolution, menus, pluralization, note preservation and live switching pass")
    }

    @MainActor
    private static func descendants(_ root: NSView) -> [NSView] {
        root.subviews.flatMap { [$0] + descendants($0) }
    }
}

@MainActor
private final class LocalizationMenuTarget: NSObject, DeskbitStatusMenuTarget {
    @objc func newNoteFromMenu() {}
    @objc func arrangeNotes() {}
    @objc func showHistoryFromMenu() {}
    @objc func showAllNotes() {}
    @objc func showFeedbackFromMenu() {}
    @objc func changeLanguage(_ sender: NSMenuItem) {}
    @objc func quit() {}
}
