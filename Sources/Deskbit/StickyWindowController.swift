import AppKit

@MainActor
final class StickyWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, StickyToolbarDelegate {
    private var note: StickyNote
    private let rootView: StickyRootView
    private let windowResidency: StickyWindowResidency
    private var saveStatusTimer: Timer?
    private var isApplyingMarkdown = false
    weak var appController: AppController?
    var isPinned: Bool { note.isPinned }

    init(note: StickyNote) {
        self.note = note
        rootView = StickyRootView(note: note)
        let residentWindow = StickyWindow(
            contentRect: note.frame.rect,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        windowResidency = StickyWindowResidency(residentWindow: residentWindow)
        super.init(window: residentWindow)
        configureWindow(residentWindow)
        residentWindow.contentView = rootView
        rootView.toolbar.delegate = self
        rootView.footer.delegate = self
        rootView.textView.delegate = self
        rootView.textView.onToggleBold = { [weak self] in self?.didTapBold() }
        rootView.textView.onToggleBulletList = { [weak self] in self?.didTapBulletList() }
        rootView.textView.onToggleStrikethrough = { [weak self] in self?.didTapStrikethrough() }
        rootView.textView.onListNewline = { [weak self] in
            guard let self else { return false }
            return RichTextFormatting.handleListNewline(in: self.rootView.textView)
        }
        rootView.textView.onAdjustBulletLevel = { [weak self] delta in
            guard let self else { return false }
            let changed = RichTextFormatting.adjustBulletLevel(in: self.rootView.textView, delta: delta)
            if changed { self.rootView.textView.didChangeText() }
            return changed
        }
        if RichTextFormatting.normalizeBulletMarkers(in: rootView.textView) {
            self.note.text = rootView.textView.string
            self.note.richTextData = rootView.textView.textStorage.flatMap(RichTextCodec.encode)
            NoteStore.shared.update(self.note)
        }
        applyPinState()
        updateFormattingState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func close() {
        windowResidency.closeAll()
    }

    func showAndFocus() {
        note.isHidden = false
        NoteStore.shared.update(note)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        window?.makeFirstResponder(rootView.textView)
    }

    func windowDidMove(_ notification: Notification) {
        guard let frame = window?.frame else { return }
        if appController?.shouldDeferFramePersistence(for: note.id) != true {
            saveFrame(frame)
        }
        appController?.noteWindowDidMove(id: note.id, frame: frame)
    }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    func windowDidResignKey(_ notification: Notification) {
        guard !note.isPinned else { return }
        window?.orderBack(nil)
    }

    func textDidChange(_ notification: Notification) {
        if !isApplyingMarkdown {
            isApplyingMarkdown = true
            _ = RichTextFormatting.applyMarkdownSyntax(in: rootView.textView)
            isApplyingMarkdown = false
        }
        persistText()
        updateFormattingState()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateFormattingState()
    }

    func didChooseColor(_ color: NoteColor) {
        note.color = color
        rootView.updateColor(color)
        rootView.toolbar.update(color: color, isPinned: note.isPinned)
        NoteStore.shared.update(note)
    }

    func didTapArrange() { appController?.arrangeNotes() }

    func didBeginToolbarDrag(with event: NSEvent) {
        appController?.beginDragging(noteID: note.id, event: event)
    }

    func didTapBold() {
        let textView = rootView.textView
        RichTextFormatting.toggleBold(in: textView)
        textView.didChangeText()
        window?.makeFirstResponder(textView)
    }

    func didTapBulletList() {
        let textView = rootView.textView
        RichTextFormatting.toggleBulletList(in: textView)
        textView.didChangeText()
        window?.makeFirstResponder(textView)
    }

    func didTapStrikethrough() {
        let textView = rootView.textView
        RichTextFormatting.toggleStrikethrough(in: textView)
        textView.didChangeText()
        window?.makeFirstResponder(textView)
    }

    func didTapNew() { appController?.createNote() }

    func didTapPin() {
        if let appController {
            appController.togglePin(noteID: note.id)
            return
        }
        setPinned(!note.isPinned, focus: true)
    }

    func setPinned(_ isPinned: Bool, focus: Bool) {
        guard note.isPinned != isPinned else { return }
        let wasPinned = note.isPinned
        note.isPinned = isPinned
        applyPinState(previouslyPinned: wasPinned, focusWhenPinned: focus)
        NoteStore.shared.update(note)
    }

    func didTapComplete() {
        let id = note.id
        window?.orderOut(nil)
        appController?.completeNote(id: id)
    }

    private func applyPinState(previouslyPinned: Bool? = nil, focusWhenPinned: Bool = false) {
        let isBecomingPinned = previouslyPinned == false && note.isPinned
        let isBecomingUnpinned = previouslyPinned == true && !note.isPinned

        if note.isPinned, windowResidency.pinnedWindow == nil {
            let proxyWindow = windowResidency.beginPinnedPresentation { [unowned self] in
                let window = StickyWindow(
                    contentRect: self.windowResidency.residentWindow.frame,
                    styleMask: [.borderless, .resizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                self.configureWindow(window)
                return window
            }
            self.window = proxyWindow
        } else if !note.isPinned, windowResidency.pinnedWindow != nil {
            self.window = windowResidency.endPinnedPresentation()
        }

        if let window {
            StickyWindowPresentation.apply(isPinned: note.isPinned, to: window)
        }
        rootView.toolbar.update(color: note.color, isPinned: note.isPinned)
        rootView.statusLabel.stringValue = note.isPinned ? "已置顶 · 已保存" : "已保存"
        if isBecomingPinned {
            window?.orderFrontRegardless()
            if focusWhenPinned {
                window?.makeKey()
                window?.makeFirstResponder(rootView.textView)
            }
        } else if isBecomingUnpinned {
            window?.orderBack(nil)
        }
    }

    func move(to frame: NSRect) {
        guard let window else { return }
        window.minSize = NSSize(
            width: min(window.minSize.width, frame.width),
            height: min(window.minSize.height, frame.height)
        )
        window.setFrame(frame, display: true, animate: true)
        note.frame = WindowFrame(frame)
        NoteStore.shared.update(note)
    }

    func arrangeOnDesktop(to frame: NSRect) {
        guard let window else { return }
        let wasPinned = note.isPinned
        note.isPinned = false
        if wasPinned {
            applyPinState(previouslyPinned: true)
        } else {
            StickyWindowPresentation.apply(isPinned: false, to: window)
            rootView.toolbar.update(color: note.color, isPinned: false)
            rootView.statusLabel.stringValue = "已保存"
        }
        move(to: frame)
        self.window?.orderBack(nil)
    }

    func performWindowDrag(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    func updateSelection(_ isSelected: Bool) {
        rootView.updateSelection(isSelected)
    }

    func orderBackIfUnpinned() {
        guard !note.isPinned else { return }
        window?.orderBack(nil)
    }

    func captureCurrentFrame() -> WindowFrame? {
        guard let frame = window?.frame else { return nil }
        note.frame = WindowFrame(frame)
        return note.frame
    }

    private func persistText() {
        note.text = rootView.textView.string
        if let storage = rootView.textView.textStorage {
            note.richTextData = RichTextCodec.encode(storage)
        }
        NoteStore.shared.update(note)
        rootView.statusLabel.stringValue = "正在保存…"
        saveStatusTimer?.invalidate()
        saveStatusTimer = Timer.scheduledTimer(
            timeInterval: 0.45,
            target: self,
            selector: #selector(markSaved),
            userInfo: nil,
            repeats: false
        )
    }

    private func updateFormattingState() {
        let textView = rootView.textView
        rootView.footer.updateFormatting(
            isBold: RichTextFormatting.isBold(in: textView),
            isBulletList: RichTextFormatting.isBulletList(in: textView),
            isStrikethrough: RichTextFormatting.isStrikethrough(in: textView)
        )
    }

    @objc private func markSaved() {
        rootView.statusLabel.stringValue = note.isPinned ? "已置顶 · 已保存" : "已保存"
    }

    private func saveFrame() {
        guard let frame = window?.frame else { return }
        saveFrame(frame)
    }

    private func saveFrame(_ frame: NSRect) {
        note.frame = WindowFrame(frame)
        NoteStore.shared.update(note)
    }

    private func configureWindow(_ window: StickyWindow) {
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NoteAppearance.minimumSize
        window.isMovableByWindowBackground = false
        window.animationBehavior = .utilityWindow
    }

}
