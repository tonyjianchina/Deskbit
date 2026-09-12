import AppKit
import Foundation

/// 便签窗口内容控制器：负责便签的完整 UI 与交互。
/// 顶栏左侧显示保存状态/提醒时间，右侧为七枚功能按钮：
/// 移动、背景色、新增、置顶、提醒、隐藏、完成。
final class NoteViewController: NSViewController {

    // MARK: - 对外回调
    var onNewNote: (() -> Void)?
    var onDeleteNote: (() -> Void)?
    var onShowAll: (() -> Void)?

    let noteID: String
    private var note: Note
    private let store = NoteStore.shared

    // 子视图
    private let topBar = NoteDragView()
    private let statusLabel = NSTextField(labelWithString: "已保存")
    private let reminderLabel = NSTextField(labelWithString: "")
    private let textView = NoteTextView()
    private let scrollView = NSScrollView()
    private let placeholderLabel = NSTextField(labelWithString: "写下就好…")
    private let resizeGrip = NoteResizeView()

    var moveMode = false
    private var lastUpdateTick: Date = Date()

    // 提醒弹窗
    private var reminderPopover: NSPopover?
    private var reminderVC: ReminderPopoverViewController?

    var noteColor: Note.NoteColor { note.colorEnum }
    var currentNote: Note { note }

    /// 供自测/诊断读取当前编辑框文本
    var noteTextViewString: String {
        return textView.string
    }

    // MARK: - 初始化

    init(note: Note) {
        self.note = note
        self.noteID = note.id
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let root = NoteBackgroundView(frame: NSRect(x: 0, y: 0, width: 320, height: 260))
        root.wantsLayer = true
        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        refreshColor()
        applyState()
        setupMenu()
    }

    // MARK: - 构建 UI

    private func buildUI() {
        let root = view as! NoteBackgroundView

        // —— 顶栏 ——
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.controller = self
        root.addSubview(topBar)

        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .labelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        reminderLabel.font = .systemFont(ofSize: 10.5)
        reminderLabel.textColor = .secondaryLabelColor
        reminderLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusStack = NSStackView(views: [statusLabel, reminderLabel])
        statusStack.orientation = .horizontal
        statusStack.spacing = 8
        statusStack.alignment = .centerY
        statusStack.translatesAutoresizingMaskIntoConstraints = false

        // —— 顶栏右侧功能按钮 ——
        let buttons: [(String, String, String, Selector)] = [
            ("hand.draw",        "移动",  "切换拖动模式", #selector(toggleMoveMode(_:))),
            ("paintpalette",     "背景色", "切换便签颜色", #selector(cycleColor(_:))),
            ("plus",             "新增",  "新建便签",     #selector(newNote(_:))),
            ("pin",              "置顶",  "切换置顶",     #selector(togglePin(_:))),
            ("bell",             "提醒",  "设置提醒",     #selector(openReminder(_:))),
            ("eye.slash",        "隐藏",  "临时隐藏",     #selector(hideNote(_:))),
            ("checkmark.circle", "完成",  "标记完成",     #selector(toggleComplete(_:))),
        ]

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        var buttonViews: [NSView] = []
        for (symbol, tip, accessibility, action) in buttons {
            let b = NSButton()
            b.isBordered = false
            b.bezelStyle = .regularSquare
            b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibility)
            b.imagePosition = .imageOnly
            b.toolTip = tip
            b.target = self
            b.action = action
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 24).isActive = true
            b.heightAnchor.constraint(equalToConstant: 24).isActive = true
            buttonViews.append(b)
        }

        let btnStack = NSStackView(views: buttonViews)
        btnStack.orientation = .horizontal
        btnStack.spacing = 2
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        topBar.addSubview(statusStack)
        topBar.addSubview(divider)
        topBar.addSubview(btnStack)

        // —— 正文编辑区 ——
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        // 注意：作为 documentView 的 NSTextView 必须保持 frame 布局（默认），
        // 由 NSScrollView 自动管理其 frame，不能设置 translatesAutoresizingMaskIntoConstraints=false，
        // 否则文本框会塌缩为 0 尺寸导致正文不可见。
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self
        textView.string = note.content
        textView.controller = self
        scrollView.documentView = textView

        root.addSubview(scrollView)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = .systemFont(ofSize: 15)
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.isSelectable = false
        root.addSubview(placeholderLabel)
        updatePlaceholder()

        // —— 右下角缩放手柄 ——
        resizeGrip.translatesAutoresizingMaskIntoConstraints = false
        resizeGrip.controller = self
        resizeGrip.wantsLayer = true
        root.addSubview(resizeGrip)

        // —— 布局约束 ——
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: root.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 40),

            statusStack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            statusStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            divider.trailingAnchor.constraint(equalTo: btnStack.leadingAnchor, constant: -8),
            divider.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            divider.heightAnchor.constraint(equalToConstant: 22),
            divider.widthAnchor.constraint(equalToConstant: 1),

            btnStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -8),
            btnStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),

            placeholderLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 12),

            resizeGrip.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -2),
            resizeGrip.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -2),
            resizeGrip.widthAnchor.constraint(equalToConstant: 18),
            resizeGrip.heightAnchor.constraint(equalToConstant: 18),
        ])

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            sep.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
        ])
    }

    // MARK: - 状态应用

    private func refreshColor() {
        guard let root = view as? NoteBackgroundView else { return }
        root.noteColor = noteColor
        root.needsDisplay = true
        let accent = noteColor.accent
        // 更新按钮颜色
        for v in topBar.subviews {
            if let s = v as? NSStackView {
                for b in s.arrangedSubviews {
                    (b as? NSButton)?.contentTintColor = accent
                }
            } else if let b = v as? NSButton {
                b.contentTintColor = accent
            }
        }
        statusLabel.textColor = accent
        reminderLabel.textColor = accent.withAlphaComponent(0.75)
        textView.textColor = accent
        placeholderLabel.textColor = accent.withAlphaComponent(0.45)
        textView.insertionPointColor = accent
        if let window = view.window {
            (window as? NoteWindow)?.refreshShadow()
        }
    }

    private func applyState() {
        // 置顶状态图标
        setButtonIcon("pin", symbol: note.pinned ? "pin.fill" : "pin", tip: note.pinned ? "取消置顶" : "置顶")
        // 完成状态图标
        setButtonIcon("checkmark.circle", symbol: note.completed ? "checkmark.circle.fill" : "checkmark.circle", tip: note.completed ? "取消完成" : "标记完成")
        // 提醒图标
        setButtonIcon("bell", symbol: note.reminderAt != nil ? "bell.fill" : "bell", tip: "提醒")
        updateReminderLabel()
        updateCompletedStyle()
    }

    private func setButtonIcon(_ symbol: String, symbol newSymbol: String, tip: String) {
        for v in topBar.subviews {
            guard let s = v as? NSStackView else { continue }
            for b in s.arrangedSubviews {
                guard let btn = b as? NSButton else { continue }
                if btn.toolTip == tip {
                    btn.image = NSImage(systemSymbolName: newSymbol, accessibilityDescription: tip)
                    btn.contentTintColor = noteColor.accent
                }
            }
        }
    }

    private func updateCompletedStyle() {
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.strikethroughStyle, range: full)
        storage.removeAttribute(.strikethroughColor, range: full)
        if note.completed {
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: full)
            storage.addAttribute(.strikethroughColor, value: noteColor.accent.withAlphaComponent(0.5), range: full)
        }
        if let root = view as? NoteBackgroundView {
            root.completed = note.completed
            root.needsDisplay = true
        }
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !textView.string.isEmpty
    }

    private func updateReminderLabel() {
        if let ms = note.reminderAt {
            let date = Date(timeIntervalSince1970: ms / 1000)
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            if Calendar.current.isDateInToday(date) {
                f.dateFormat = "今天 HH:mm"
            } else if Calendar.current.isDateInTomorrow(date) {
                f.dateFormat = "明天 HH:mm"
            } else {
                f.dateFormat = "M月d日 HH:mm"
            }
            reminderLabel.stringValue = "⏰ \(f.string(from: date))"
        } else {
            reminderLabel.stringValue = ""
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        let delete = NSMenuItem(title: "删除此便签", action: #selector(deleteNote(_:)), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)
        menu.addItem(NSMenuItem.separator())
        let newItem = NSMenuItem(title: "新建便签", action: #selector(newNote(_:)), keyEquivalent: "")
        newItem.target = self
        menu.addItem(newItem)
        view.menu = menu
    }

    // MARK: - 便签数据更新

    /// 更新当前 note 数据并持久化（用于移动/缩放/内容编辑等）
    func syncNote(mutate: (inout Note) -> Void) {
        mutate(&note)
        store.update(note)
        lastUpdateTick = Date()
    }

    @objc func markSaved() {
        statusLabel.stringValue = "已保存"
    }

    // MARK: - 动作

    @objc private func toggleMoveMode(_ sender: Any?) {
        moveMode.toggle()
        setButtonIcon("hand.draw", symbol: moveMode ? "hand.draw.fill" : "hand.draw", tip: "移动")
        statusLabel.stringValue = moveMode ? "拖动模式：按住任意处移动" : "已保存"
    }

    @objc private func cycleColor(_ sender: Any?) {
        let all = Note.NoteColor.allCases
        let next = all[(all.firstIndex(of: noteColor)! + 1) % all.count]
        syncNote { $0.color = next.rawValue }
        refreshColor()
    }

    @objc private func newNote(_ sender: Any?) {
        onNewNote?()
    }

    @objc private func togglePin(_ sender: Any?) {
        let newPinned = !note.pinned
        syncNote { $0.pinned = newPinned }
        (view.window as? NoteWindow)?.applyPinState()
        applyState()
    }

    @objc private func openReminder(_ sender: Any?) {
        guard view.window != nil else { return }
        if reminderPopover == nil {
            let pop = NSPopover()
            pop.behavior = .transient
            pop.animates = true
            reminderPopover = pop
        }
        if reminderVC == nil {
            reminderVC = ReminderPopoverViewController(noteID: noteID)
            reminderVC!.onSetReminder = { [weak self] date in
                self?.setReminder(date)
            }
            reminderVC!.onClearReminder = { [weak self] in
                self?.clearReminder()
            }
        }
        reminderVC!.currentDate = note.reminderAt.map { Date(timeIntervalSince1970: $0 / 1000) }
        reminderVC!.refreshUI()
        reminderPopover!.contentViewController = reminderVC
        // 定位到提醒按钮
        for v in topBar.subviews {
            if let s = v as? NSStackView {
                for b in s.arrangedSubviews {
                    if let btn = b as? NSButton, btn.toolTip == "提醒" {
                        reminderPopover!.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
                        return
                    }
                }
            }
        }
    }

    private func setReminder(_ date: Date) {
        syncNote {
            $0.reminderAt = date.timeIntervalSince1970 * 1000
            $0.reminderFiredAt = nil
        }
        ReminderManager.shared.schedule(for: note)
        applyState()
    }

    private func clearReminder() {
        ReminderManager.shared.cancel(for: note)
        syncNote {
            $0.reminderAt = nil
            $0.reminderFiredAt = nil
        }
        applyState()
    }

    @objc private func hideNote(_ sender: Any?) {
        syncNote { $0.hidden = true }
        view.window?.orderOut(nil)
    }

    @objc private func toggleComplete(_ sender: Any?) {
        // 诊断：无论是否有事件都记录，并打印调用栈定位来源
        print("[DBG] toggleComplete CALLED event=\(String(describing: NSApp.currentEvent?.type))")
        print("[DBG] stack: \(Thread.callStackSymbols.prefix(8).joined(separator: " | "))")
        let willComplete = !note.completed
        syncNote { $0.completed = willComplete }
        applyState()
        // 完成即收起：标记完成后自动隐藏，保持桌面干净
        if willComplete {
            syncNote { $0.hidden = true }
            view.window?.orderOut(nil)
        } else {
            syncNote { $0.hidden = false }
        }
    }

    @objc private func deleteNote(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "删除此便签？"
        alert.informativeText = "删除后无法恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            onDeleteNote?()
        }
    }
}

// MARK: - NSTextViewDelegate

extension NoteViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updatePlaceholder()
        statusLabel.stringValue = "保存中…"
        syncNote { $0.content = textView.string }
        // 防抖：0.5 秒后标记已保存
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(markSaved), object: nil)
        perform(#selector(markSaved), with: nil, afterDelay: 0.5)
    }
}

// MARK: - 便签窗口（无边框、圆角、跟随所有桌面）

final class NoteWindow: NSWindow, NSWindowDelegate {

    private(set) var noteID: String
    private var controller: NoteViewController

    init(note: Note) {
        self.noteID = note.id
        self.controller = NoteViewController(note: note)
        super.init(
            contentRect: NSRect(x: note.x, y: note.y, width: note.width, height: note.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.contentViewController = controller
        self.delegate = self
        self.isRestorable = false
        self.animationBehavior = .none

        // 跟随当前桌面：普通 Space 之间跟随，全屏应用中也保持可见
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 初始位置（屏幕坐标转换：存储 y 为顶部坐标）
        positionFromNote()
        applyPinState()

        // 保存状态回调
        controller.onNewNote = {
            AppDelegate.shared.createNoteWindow(note: nil)
        }
        controller.onDeleteNote = { [weak self] in
            guard let self = self else { return }
            NoteStore.shared.remove(id: self.noteID)
            ReminderManager.shared.cancel(id: self.noteID)
            self.close()
            AppDelegate.shared.windowDidClose(self)
        }
    }

    var noteController: NoteViewController { controller }

    func refreshShadow() {
        self.invalidateShadow()
    }

    /// 从数据还原位置（x/y 为左上角逻辑坐标）
    private func positionFromNote() {
        guard let screen = NSScreen.main else { return }
        let note = controller.currentNote
        // 顶部坐标换算成 macOS 底部坐标
        let screenFrame = screen.visibleFrame
        let bottomY = screenFrame.maxY - note.y - note.height
        setFrame(NSRect(x: note.x, y: bottomY, width: note.width, height: note.height), display: true)
    }

    func applyPinState() {
        // 置顶：浮动在其他应用之上；取消置顶：普通层级，点击外部自动退后
        level = controller.currentNote.pinned ? .floating : .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func syncMetricsToNote() {
        guard let screen = NSScreen.main else { return }
        let frame = self.frame
        let screenFrame = screen.visibleFrame
        let topY = screenFrame.maxY - frame.maxY
        controller.syncNote {
            $0.x = Double(frame.minX)
            $0.y = Double(topY)
            $0.width = Double(frame.width)
            $0.height = Double(frame.height)
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        syncMetricsToNote()
    }

    func windowDidResize(_ notification: Notification) {
        syncMetricsToNote()
        refreshShadow()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        controller.markSaved()
    }
}

// MARK: - 便签背景视图（圆角 + 配色 + 完成态变淡）

final class NoteBackgroundView: NSView {
    var noteColor: Note.NoteColor = .yellow
    var completed: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        var bg = noteColor.background
        if completed {
            bg = bg.withAlphaComponent(0.45)
        }
        bg.setFill()
        bounds.fill()
        // 顶部淡淡的强调带
        noteColor.barTint.setFill()
        NSRect(x: 0, y: bounds.maxY - 40, width: bounds.width, height: 40).fill()
        // 边框
        noteColor.accent.withAlphaComponent(0.18).setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        path.lineWidth = 1
        path.stroke()
    }
}

// MARK: - 可拖动顶栏（或移动模式下任意处拖动）

final class NoteDragView: NSView {
    weak var controller: NoteViewController?

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        window.performDrag(with: event)
    }
}

// MARK: - 文本视图（支持移动模式下拖动窗口）

final class NoteTextView: NSTextView {
    weak var controller: NoteViewController?

    override func mouseDown(with event: NSEvent) {
        if let c = controller, c.moveMode {
            window?.performDrag(with: event)
            return
        }
        super.mouseDown(with: event)
    }
}

// MARK: - 右下角缩放手柄

final class NoteResizeView: NSView {
    weak var controller: NoteViewController?
    private var tracking: (origin: NSPoint, frame: NSRect)?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let c = controller else { return }
        let accent = c.noteColor.accent.withAlphaComponent(0.55)
        accent.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        let x = bounds.maxX - 8
        let y = bounds.minY + 5
        for i in 0..<3 {
            let start = NSPoint(x: x - CGFloat(i) * 4 - 2, y: y + CGFloat(i) * 4)
            let end = NSPoint(x: x, y: y + CGFloat(i) * 4)
            path.move(to: start)
            path.line(to: end)
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        tracking = (window.frame.origin, window.frame)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window, let start = tracking else { return }
        let loc = window.convertPoint(toScreen: event.locationInWindow)
        let deltaX = loc.x - start.origin.x
        let deltaY = loc.y - start.origin.y
        var newFrame = start.frame
        let minW: CGFloat = 200, minH: CGFloat = 150
        newFrame.size.width = max(minW, start.frame.width + deltaX)
        newFrame.size.height = max(minH, start.frame.height - deltaY)
        window.setFrame(newFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        tracking = nil
    }
}
