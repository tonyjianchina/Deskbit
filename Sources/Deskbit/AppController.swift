import AppKit
import UserNotifications

@MainActor
final class AppController: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSPopoverDelegate, DeskbitStatusMenuTarget {
    private var controllers: [UUID: StickyWindowController] = [:]
    private var statusItem: NSStatusItem!
    private let hiddenMenu = NSMenuItem(title: "显示隐藏的便签", action: nil, keyEquivalent: "")
    private var selectedNoteIDs: Set<UUID> = []
    private var selectionOverlay: SelectionOverlayWindowController?
    private var historyPopover: NSPopover?
    private var historyDismissalMonitor: HistoryPopoverDismissalMonitor?
    private var feedbackWindowController: NSWindowController?
    private var desktopMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var desktopSelectionStart: NSPoint?
    private var isDesktopSelectionActive = false
    private var groupDragAnchorID: UUID?
    private var groupDragAnchorOrigin: NSPoint?
    private var groupDragInitialFrames: [UUID: NSRect] = [:]
    private var groupDragLastValidOffset = NSPoint.zero
    private var isApplyingGroupDrag = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        configureMainMenu()
        configureStatusItem()
        installDesktopSelectionMonitor()

        let notes = NoteStore.shared.activeNotes
        if notes.isEmpty {
            createNote()
        } else {
            notes.forEach { open($0) }
            if !notes.contains(where: { !$0.isHidden }) { showAllNotes() }
        }
        refreshMenu()
    }

    func applicationDidResignActive(_ notification: Notification) {
        controllers.values.forEach { $0.orderBackIfUnpinned() }
    }

    func createNote(near sourceFrame: NSRect? = nil, in visibleFrame: NSRect? = nil) {
        setSelection([])
        let frame = sourceFrame.flatMap { source in
            visibleFrame.map {
                NoteCreationLayout.frame(near: source, size: NoteAppearance.defaultSize, in: $0)
            }
        }
        open(NoteStore.shared.add(frame: frame), focus: true)
        refreshMenu()
    }

    func completeNote(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        controllers[id]?.close()
        controllers.removeValue(forKey: id)
        selectedNoteIDs.remove(id)
        NoteStore.shared.complete(id: id)
        dismissHistoryPopover()
        refreshMenu()
    }

    func refreshMenu() {
        let hidden = NoteStore.shared.activeNotes.filter(\.isHidden)
        hiddenMenu.submenu = nil
        hiddenMenu.isEnabled = !hidden.isEmpty
        guard !hidden.isEmpty else { return }

        let submenu = NSMenu()
        for note in hidden {
            let title = note.text.split(separator: "\n").first.map(String.init)?.prefix(28) ?? "空白便签"
            let item = NSMenuItem(title: String(title), action: #selector(showHiddenNote(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = note.id.uuidString
            submenu.addItem(item)
        }
        hiddenMenu.submenu = submenu
    }

    func show(noteID: UUID) {
        guard let note = NoteStore.shared.note(id: noteID), note.completedAt == nil else { return }
        if controllers[noteID] == nil { open(note) }
        controllers[noteID]?.showAndFocus()
        refreshMenu()
    }

    private func open(_ note: StickyNote, focus: Bool = false) {
        let controller = StickyWindowController(note: note)
        controller.appController = self
        controllers[note.id] = controller
        if !note.isHidden {
            if focus { controller.showAndFocus() } else { controller.showWindow(nil) }
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        statusItem.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Deskbit")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = "便签"
        statusItem.button?.toolTip = "Deskbit"
        statusItem.menu = DeskbitStatusMenu.make(target: self, hiddenMenu: hiddenMenu)
    }

    private func configureMainMenu() {
        NSApp.mainMenu = ApplicationMenu.make()
    }

    @objc func newNoteFromMenu() { createNote() }

    @objc func arrangeNotes() {
        let visibleNotes = NoteStore.shared.activeNotes.filter { !$0.isHidden }
        let notes = (selectedNoteIDs.isEmpty ? visibleNotes : visibleNotes.filter { selectedNoteIDs.contains($0.id) })
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.createdAt < $1.createdAt
            }
        guard !notes.isEmpty,
              let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first else { return }

        let sizes = notes.map { note in
            controllers[note.id]?.window?.frame.size ?? note.frame.rect.size
        }
        let frames = NoteWindowLayout.alignedFrames(sizes: sizes, in: screen.visibleFrame)
        for (note, frame) in zip(notes, frames) {
            controllers[note.id]?.arrangeOnDesktop(to: frame)
        }
    }

    func showHistory(relativeTo sourceView: NSView) {
        if historyPopover?.isShown == true {
            dismissHistoryPopover()
            return
        }
        presentHistory(relativeTo: sourceView)
    }

    private func presentHistory(relativeTo sourceView: NSView) {
        dismissHistoryPopover()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = HistoryPopoverViewController(
            notes: NoteStore.shared.completedNotes,
            onRestore: { [weak self] id in
                guard let self else { return }
                self.dismissHistoryPopover()
                guard let note = NoteStore.shared.restore(id: id) else { return }
                self.open(note, focus: true)
                self.refreshMenu()
            },
            onDelete: { [weak self] id in
                self?.confirmDeleteHistoryNote(id: id)
            },
            onClear: { [weak self] in
                self?.confirmClearHistory()
            }
        )
        historyPopover = popover
        popover.show(relativeTo: sourceView.bounds, of: sourceView, preferredEdge: .minY)
        let dismissalMonitor = HistoryPopoverDismissalMonitor(
            popoverWindow: { [weak popover] in popover?.contentViewController?.view.window },
            onDismiss: { [weak self] in self?.dismissHistoryPopover() }
        )
        historyDismissalMonitor = dismissalMonitor
        dismissalMonitor.start()
    }

    private func dismissHistoryPopover() {
        historyDismissalMonitor?.stop()
        historyDismissalMonitor = nil
        historyPopover?.close()
        historyPopover = nil
    }

    func popoverDidClose(_ notification: Notification) {
        guard notification.object as? NSPopover === historyPopover else { return }
        historyDismissalMonitor?.stop()
        historyDismissalMonitor = nil
        historyPopover = nil
    }

    @objc func showHistoryFromMenu() {
        guard let sourceView = statusItem.button else { return }
        DispatchQueue.main.async { [weak self, weak sourceView] in
            guard let sourceView else { return }
            self?.showHistory(relativeTo: sourceView)
        }
    }

    @objc func showFeedbackFromMenu() {
        let windowController: NSWindowController
        let feedbackViewController: FeedbackViewController
        if let existing = feedbackWindowController,
           let existingViewController = existing.contentViewController as? FeedbackViewController {
            windowController = existing
            feedbackViewController = existingViewController
        } else {
            feedbackViewController = FeedbackViewController { message, completion in
                FeedbackSubmission.submit(message: message, completion: completion)
            }
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 330),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            panel.title = "用户反馈"
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = false
            panel.level = .normal
            panel.contentViewController = feedbackViewController
            panel.center()
            windowController = NSWindowController(window: panel)
            feedbackWindowController = windowController
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { feedbackViewController.focusEditor() }
    }

    private func confirmDeleteHistoryNote(id: UUID) {
        dismissHistoryPopover()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "永久删除这条历史便签？"
        alert.informativeText = "这项操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = NoteStore.shared.permanentlyDelete(id: id)
    }

    private func confirmClearHistory() {
        dismissHistoryPopover()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "清空所有历史便签？"
        alert.informativeText = "这项操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        NoteStore.shared.clearCompleted()
    }

    func beginDragging(noteID: UUID, event: NSEvent) {
        guard let controller = controllers[noteID] else { return }
        let activeSelection = selectedNoteIDs.filter { controllers[$0]?.window?.isVisible == true }
        guard activeSelection.contains(noteID), activeSelection.count > 1 else {
            if !activeSelection.contains(noteID) { setSelection([]) }
            controller.performWindowDrag(with: event)
            return
        }

        let framePairs: [(UUID, NSRect)] = activeSelection.compactMap { id -> (UUID, NSRect)? in
            guard let frame = controllers[id]?.window?.frame else { return nil }
            return (id, frame)
        }
        let frames = Dictionary(uniqueKeysWithValues: framePairs)
        guard let anchorFrame = frames[noteID] else { return }
        groupDragAnchorID = noteID
        groupDragAnchorOrigin = anchorFrame.origin
        groupDragInitialFrames = frames
        groupDragLastValidOffset = .zero
        controller.performWindowDrag(with: event)
        var persistedFrames: [UUID: WindowFrame] = [:]
        for memberID in groupDragInitialFrames.keys {
            if let frame = controllers[memberID]?.captureCurrentFrame() {
                persistedFrames[memberID] = frame
            }
        }
        NoteStore.shared.updateFrames(persistedFrames)
        groupDragAnchorID = nil
        groupDragAnchorOrigin = nil
        groupDragInitialFrames = [:]
        groupDragLastValidOffset = .zero
    }

    func togglePin(noteID: UUID) {
        guard let triggeringController = controllers[noteID] else { return }
        let operation = NoteSelection.pinOperation(
            triggering: noteID,
            triggeringIsPinned: triggeringController.isPinned,
            selectedIDs: selectedNoteIDs
        )

        for id in operation.ids where id != noteID {
            controllers[id]?.setPinned(operation.isPinned, focus: false)
        }
        triggeringController.setPinned(operation.isPinned, focus: operation.isPinned)
    }

    func shouldDeferFramePersistence(for id: UUID) -> Bool {
        groupDragAnchorID != nil && groupDragInitialFrames[id] != nil
    }

    func noteWindowDidMove(id: UUID, frame: NSRect) {
        guard !isApplyingGroupDrag,
              groupDragAnchorID == id,
              let anchorOrigin = groupDragAnchorOrigin else { return }
        let translation = NoteSelection.constrainedTranslation(
            groupDragInitialFrames,
            from: anchorOrigin,
            to: frame.origin,
            fallbackOffset: groupDragLastValidOffset,
            visibleFrames: NSScreen.screens.map(\.visibleFrame)
        )
        if translation.acceptedRequestedOffset { groupDragLastValidOffset = translation.offset }
        isApplyingGroupDrag = true
        for (memberID, memberFrame) in translation.frames {
            controllers[memberID]?.window?.setFrameOrigin(memberFrame.origin)
        }
        isApplyingGroupDrag = false
    }

    private func completeSelection(in rect: NSRect) {
        let framePairs: [(UUID, NSRect)] = controllers.compactMap { id, controller -> (UUID, NSRect)? in
            guard controller.window?.isVisible == true, let frame = controller.window?.frame else { return nil }
            return (id, frame)
        }
        let frames = Dictionary(uniqueKeysWithValues: framePairs)
        setSelection(rect.isEmpty ? [] : NoteSelection.ids(intersecting: rect, noteFrames: frames))
        closeSelectionOverlay()
    }

    private func installDesktopSelectionMonitor() {
        desktopMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            let type = event.type
            let point = NSEvent.mouseLocation
            DispatchQueue.main.async { [weak self] in
                self?.handleDesktopMouse(type: type, point: point)
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            if self?.desktopSelectionStart != nil {
                self?.handleDesktopMouse(type: event.type, point: NSEvent.mouseLocation)
            }
            return event
        }
    }

    private func handleDesktopMouse(type: NSEvent.EventType, point: NSPoint) {
        switch type {
        case .leftMouseDown:
            desktopSelectionStart = isDesktopBackground(at: point) ? point : nil
            isDesktopSelectionActive = false
        case .leftMouseDragged:
            guard let start = desktopSelectionStart else { return }
            if !isDesktopSelectionActive {
                guard hypot(point.x - start.x, point.y - start.y) >= 4 else { return }
                beginDesktopSelection(at: start)
                isDesktopSelectionActive = true
            }
            selectionOverlay?.update(to: point, from: start)
        case .leftMouseUp:
            guard let start = desktopSelectionStart else { return }
            if isDesktopSelectionActive {
                completeSelection(in: NSRect(
                    x: min(start.x, point.x),
                    y: min(start.y, point.y),
                    width: abs(point.x - start.x),
                    height: abs(point.y - start.y)
                ))
            } else {
                setSelection([])
            }
            desktopSelectionStart = nil
            isDesktopSelectionActive = false
            closeSelectionOverlay()
        default:
            break
        }
    }

    private func beginDesktopSelection(at start: NSPoint) {
        closeSelectionOverlay()
        guard let desktopFrame = NSScreen.screens.map(\.frame).reduce(Optional<NSRect>.none, { partial, frame in
            partial.map { $0.union(frame) } ?? frame
        }) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let overlay = SelectionOverlayWindowController(desktopFrame: desktopFrame)
        selectionOverlay = overlay
        overlay.begin(at: start)
    }

    private func isDesktopBackground(at point: NSPoint) -> Bool {
        guard NSScreen.screens.contains(where: { $0.visibleFrame.contains(point) }) else { return false }
        let mainDisplayHeight = CGDisplayBounds(CGMainDisplayID()).height
        let quartzPoint = CGPoint(x: point.x, y: mainDisplayHeight - point.y)
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        for info in windows {
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { continue }
            if frame.contains(quartzPoint) { return false }
        }
        return true
    }

    private func setSelection(_ ids: Set<UUID>) {
        selectedNoteIDs = ids
        for (id, controller) in controllers {
            controller.updateSelection(ids.contains(id))
        }
    }

    private func closeSelectionOverlay() {
        selectionOverlay?.close()
        selectionOverlay = nil
    }

    @objc func showAllNotes() {
        for note in NoteStore.shared.activeNotes {
            show(noteID: note.id)
        }
    }

    @objc private func showHiddenNote(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let id = UUID(uuidString: value) else { return }
        show(noteID: id)
    }

    @objc func quit() { NSApp.terminate(nil) }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let value = response.notification.request.content.userInfo["noteID"] as? String
        if let value, let id = UUID(uuidString: value) {
            Task { @MainActor [weak self] in self?.show(noteID: id) }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
