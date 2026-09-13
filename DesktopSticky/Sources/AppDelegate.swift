import AppKit
import Foundation
import UserNotifications

/// 应用代理：负责菜单栏图标、便签窗口管理、启动恢复。
final class AppDelegate: NSObject, NSApplicationDelegate {

    static let shared = AppDelegate()

    private var noteWindows: [String: NoteWindow] = [:]
    private var statusItem: NSStatusItem?

    // MARK: - 框选状态

    /// 当前被框选中的便签 id
    private(set) var selectedIDs: Set<String> = []
    /// 正在进行的组拖动（起点 + 各选中窗口的初始 frame）
    private var groupDrag: (start: NSPoint, frames: [String: NSRect])?

    var isGroupDragging: Bool { groupDrag != nil }

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        // 桌面框选层（默认开启，可在菜单栏关闭）——需在 setupMenu 之前启用，菜单勾选状态才正确
        SelectionOverlayController.shared.start()
        setupMenu()

        ReminderManager.shared.requestAuthorizationIfNeeded()

        // 恢复既有便签
        let notes = NoteStore.shared.notes
        if notes.isEmpty {
            // 首次运行：创建一张默认便签
            let note = Note.make(color: .yellow)
            NoteStore.shared.add(note)
            createWindow(for: note)
        } else {
            for note in notes where !note.hidden {
                createWindow(for: note)
            }
        }

        // 重建所有待触发提醒
        ReminderManager.shared.rescheduleAll()

        // 自测模式：把便签窗口渲染成 PNG 后退出（用于无屏幕录制权限的环境验证 UI）
        if CommandLine.arguments.contains("--snapshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.snapshotNotes()
            }
        }
        // 调试模式：列出已排程的系统提醒
        if CommandLine.arguments.contains("--list-reminders") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                    NSLog("=== 已排程提醒 %d 条 ===", reqs.count)
                    for r in reqs {
                        NSLog("  id=%@ trigger=%@ body=%@", r.identifier,
                              String(describing: r.trigger),
                              r.content.body)
                    }
                    NSApp.terminate(nil)
                }
            }
        }

        NSLog("Deskbit 启动完成，窗口数: %d", noteWindows.count)
    }

    /// 渲染所有便签窗口到 /tmp/desktopsticky_snapshot_<i>.png
    private func snapshotNotes() {
        var i = 0
        for win in noteWindows.values {
            guard let view = win.contentView else { continue }
            let vc = win.noteController
            NSLog("诊断: note.content=%@, textView.string=%@ (len %d), color=%@",
                  vc.currentNote.content.replacingOccurrences(of: "\n", with: "\\n"),
                  vc.noteTextViewString,
                  vc.noteTextViewString.count,
                  vc.currentNote.color)
            view.layoutSubtreeIfNeeded()
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                let path = "/tmp/desktopsticky_snapshot_\(i).png"
                try? png.write(to: URL(fileURLWithPath: path))
                NSLog("Snapshot 已保存: %@", path)
            }
            i += 1
        }
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NoteStore.shared.saveNow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 菜单栏应用，关闭便签窗口不退出
        return false
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarIcon()
        item.button?.toolTip = "Deskbit"
        item.button?.imagePosition = .imageOnly
        statusItem = item
    }

    /// 菜单栏模板图标：画一张便签
    static func menuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.black.setFill()
        let rect = NSRect(x: 2, y: 2, width: 13, height: 14)
        let path = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        path.fill()
        // 折叠角
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: rect.maxX - 5, y: rect.maxY))
        fold.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 5))
        fold.line(to: NSPoint(x: rect.maxX - 5, y: rect.maxY - 5))
        fold.close()
        NSColor.clear.setFill()
        fold.fill()
        // 文字横线
        NSColor.clear.setStroke()
        let line = NSBezierPath()
        line.lineWidth = 1.6
        for i in 0..<3 {
            line.move(to: NSPoint(x: rect.minX + 3.5, y: rect.maxY - 3 - CGFloat(i) * 3))
            line.line(to: NSPoint(x: rect.maxX - 3, y: rect.maxY - 3 - CGFloat(i) * 3))
        }
        line.stroke()
        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    private func setupMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()

        let newItem = NSMenuItem(title: "新建便签", action: #selector(menuNewNote(_:)), keyEquivalent: "n")
        newItem.target = self
        menu.addItem(newItem)

        let showItem = NSMenuItem(title: "显示全部便签", action: #selector(menuShowAll(_:)), keyEquivalent: "s")
        showItem.target = self
        menu.addItem(showItem)

        let hideItem = NSMenuItem(title: "隐藏全部便签", action: #selector(menuHideAll(_:)), keyEquivalent: "h")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        let selectItem = NSMenuItem(title: "启用桌面框选", action: #selector(menuToggleSelection(_:)), keyEquivalent: "")
        selectItem.target = self
        selectItem.state = SelectionOverlayController.shared.isActive ? .on : .off
        menu.addItem(selectItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "关于 Deskbit", action: #selector(menuAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出 Deskbit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        item.menu = menu
    }

    @objc private func menuNewNote(_ sender: Any?) {
        createNoteWindow(note: nil)
    }

    @objc private func menuShowAll(_ sender: Any?) {
        for idx in NoteStore.shared.notes.indices {
            var note = NoteStore.shared.notes[idx]
            note.hidden = false
            NoteStore.shared.update(note)
        }
        for note in NoteStore.shared.notes {
            if let win = noteWindows[note.id] {
                // 已在内存中但被隐藏的窗口，直接重新显示
                win.orderFrontRegardless()
                win.makeKey()
            } else {
                createWindow(for: note)
            }
        }
    }

    @objc private func menuHideAll(_ sender: Any?) {
        for idx in NoteStore.shared.notes.indices {
            var note = NoteStore.shared.notes[idx]
            note.hidden = true
            NoteStore.shared.update(note)
        }
        for window in noteWindows.values {
            window.orderOut(nil)
        }
        noteWindows.removeAll()
        endGroupDrag()
        clearSelection()
    }

    @objc private func menuToggleSelection(_ sender: NSMenuItem) {
        if SelectionOverlayController.shared.isActive {
            SelectionOverlayController.shared.stop()
            sender.state = .off
        } else {
            SelectionOverlayController.shared.start()
            sender.state = .on
        }
    }

    // MARK: - 框选 / 组拖动

    /// 计算与给定屏幕矩形相交的便签
    func noteIDs(intersecting rect: NSRect) -> Set<String> {
        var result: Set<String> = []
        for (id, win) in noteWindows where win.isVisible {
            if win.frame.intersects(rect) { result.insert(id) }
        }
        return result
    }

    /// 更新选中集合，并同步每张便签的高亮
    func setSelection(_ ids: Set<String>) {
        guard ids != selectedIDs else { return }
        selectedIDs = ids
        for (id, win) in noteWindows {
            win.setSelected(ids.contains(id))
        }
    }

    func clearSelection() {
        setSelection([])
    }

    /// 把某张便签移出选中集合（例如被隐藏/完成后）
    func removeFromSelection(_ id: String) {
        guard selectedIDs.contains(id) else { return }
        var remaining = selectedIDs
        remaining.remove(id)
        setSelection(remaining)
    }

    /// 开始组拖动：记录鼠标起点与所有选中窗口的初始位置
    func beginGroupDrag() {
        let start = NSEvent.mouseLocation
        var frames: [String: NSRect] = [:]
        for id in selectedIDs {
            if let win = noteWindows[id] { frames[id] = win.frame }
        }
        groupDrag = (start, frames)
    }

    /// 拖动中：按鼠标位移整体移动所有选中窗口
    func continueGroupDrag() {
        guard let group = groupDrag else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - group.start.x
        let dy = current.y - group.start.y
        for (id, frame) in group.frames {
            guard let win = noteWindows[id] else { continue }
            win.setFrameOrigin(NSPoint(x: frame.origin.x + dx, y: frame.origin.y + dy))
        }
    }

    func endGroupDrag() {
        groupDrag = nil
    }

    @objc private func menuAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Deskbit"
        alert.informativeText = "桌面便签 · 复刻版\n跟随当前桌面，置顶可控，到点提醒。\n数据保存在本机，无需账号。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    // MARK: - 窗口管理

    /// 新建便签（note 为 nil 时创建默认便签）
    func createNoteWindow(note: Note?) {
        var note = note ?? Note.make(color: .yellow)
        if noteWindows[note.id] == nil {
            // 首次：位置编排
            if note.x == 0 && note.y == 0 {
                let cascade = cascadeOrigin()
                note.x = Double(cascade.x)
                note.y = Double(cascade.y)
                note.width = 320
                note.height = 260
            }
            if NoteStore.shared.note(id: note.id) == nil {
                NoteStore.shared.add(note)
            } else {
                NoteStore.shared.update(note)
            }
        }
        createWindow(for: note)
    }

    private func cascadeOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 120, y: 120) }
        let f = screen.visibleFrame
        let baseX = f.minX + 80
        let baseTop = f.maxY - 80
        let offset = CGFloat(noteWindows.count % 6) * 28
        return NSPoint(x: baseX + offset, y: baseTop - 260 - offset)
    }

    private func createWindow(for note: Note) {
        if let existing = noteWindows[note.id] {
            existing.orderFrontRegardless()
            existing.makeKey()
            return
        }
        let win = NoteWindow(note: note)
        noteWindows[note.id] = win
        win.setSelected(selectedIDs.contains(note.id))
        win.orderFrontRegardless()
        win.makeKey()
    }

    func windowDidClose(_ window: NoteWindow) {
        noteWindows.removeValue(forKey: window.noteID)
        if selectedIDs.contains(window.noteID) {
            var remaining = selectedIDs
            remaining.remove(window.noteID)
            setSelection(remaining)
        }
    }

    /// 通过提醒通知点击定位到某张便签
    func showNote(id: String) {
        if let win = noteWindows[id] {
            win.orderFrontRegardless()
            win.makeKey()
        } else if let note = NoteStore.shared.note(id: id) {
            createWindow(for: note)
        }
    }
}
