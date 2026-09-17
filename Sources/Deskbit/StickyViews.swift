import AppKit

@MainActor
protocol StickyToolbarDelegate: AnyObject {
    func didChooseColor(_ color: NoteColor)
    func didTapArrange()
    func didBeginToolbarDrag(with event: NSEvent)
    func didTapBold()
    func didTapBulletList()
    func didTapStrikethrough()
    func didTapNew()
    func didTapPin()
    func didTapComplete()
}

final class ColorDotButton: NSButton {
    let noteColor: NoteColor
    var selectedColor = false {
        didSet {
            state = selectedColor ? .on : .off
            setAccessibilityValue(selectedColor ? 1 : 0)
            needsDisplay = true
        }
    }

    init(color: NoteColor) {
        noteColor = color
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.radio)
        title = ""
        toolTip = color.title
        setAccessibilityLabel(color.title)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { NSSize(width: 18, height: 38) }
    var outlineWidth: CGFloat { selectedColor ? 0 : 0.5 }
    var dotDiameter: CGFloat { selectedColor ? 14 : 12 }
    var haloDiameter: CGFloat { selectedColor ? 18 : 0 }

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        if selectedColor {
            let halo = NSRect(
                x: center.x - haloDiameter / 2,
                y: center.y - haloDiameter / 2,
                width: haloDiameter,
                height: haloDiameter
            )
            noteColor.swatch.withAlphaComponent(0.22).setFill()
            NSBezierPath(ovalIn: halo).fill()
        }
        let circle = NSRect(
            x: center.x - dotDiameter / 2,
            y: center.y - dotDiameter / 2,
            width: dotDiameter,
            height: dotDiameter
        )
        noteColor.swatch.setFill()
        NSBezierPath(ovalIn: circle).fill()
        if outlineWidth > 0 {
            NSColor.black.withAlphaComponent(0.12).setStroke()
            let outline = NSBezierPath(ovalIn: circle.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2))
            outline.lineWidth = outlineWidth
            outline.stroke()
        }
    }
}

final class StickyToolbarView: NSView {
    weak var delegate: StickyToolbarDelegate?
    private let stack = NSStackView()
    private var colorButtons: [ColorDotButton] = []
    private var pinButton: NSButton!

    init(color: NoteColor, isPinned: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        stack.addArrangedSubview(iconButton("rectangle.3.group", tip: "自动排序便签", action: #selector(arrangeNotes)))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        for item in NoteColor.allCases {
            let button = ColorDotButton(color: item)
            button.target = self
            button.action = #selector(selectColor(_:))
            button.selectedColor = item == color
            colorButtons.append(button)
            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(iconButton("plus", tip: "新建便签", action: #selector(newNote)))
        pinButton = iconButton(isPinned ? "pin.fill" : "pin", tip: "置顶", action: #selector(togglePin))
        stack.addArrangedSubview(pinButton)
        stack.addArrangedSubview(iconButton("checkmark", tip: "完成", action: #selector(completeNoteButton)))

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        var candidate: NSView? = hit
        while let view = candidate, view !== self {
            if view is NSControl { return hit }
            candidate = view.superview
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.didBeginToolbarDrag(with: event)
    }

    private func iconButton(_ symbol: String, tip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage(size: NSSize(width: 16, height: 16))
        let button = NSButton(image: image, target: self, action: action)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor.black.withAlphaComponent(0.58)
        button.toolTip = tip
        button.setAccessibilityLabel(tip)
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

    func update(color: NoteColor, isPinned: Bool) {
        colorButtons.forEach { $0.selectedColor = $0.noteColor == color }
        pinButton.image = NSImage(systemSymbolName: isPinned ? "pin.fill" : "pin", accessibilityDescription: "置顶")
        pinButton.contentTintColor = isPinned ? NSColor.black.withAlphaComponent(0.82) : NSColor.black.withAlphaComponent(0.58)
    }

    @objc private func selectColor(_ sender: ColorDotButton) { delegate?.didChooseColor(sender.noteColor) }
    @objc private func arrangeNotes() { delegate?.didTapArrange() }
    @objc private func newNote() { delegate?.didTapNew() }
    @objc private func togglePin() { delegate?.didTapPin() }
    @objc private func completeNoteButton() { delegate?.didTapComplete() }
}

final class StickyFormattingFooterView: NSView {
    weak var delegate: StickyToolbarDelegate?
    let statusLabel = NSTextField(labelWithString: "已保存")
    private let boldButton: NSButton
    private let bulletButton: NSButton
    private let strikethroughButton: NSButton

    override init(frame frameRect: NSRect) {
        boldButton = Self.makeButton(symbol: "bold", tip: "加粗（⌘B）", action: #selector(toggleBold))
        bulletButton = Self.makeButton(symbol: "list.bullet", tip: "项目符号（⌘⇧8；Tab / Shift+Tab 调整级别）", action: #selector(toggleBullet))
        strikethroughButton = Self.makeButton(symbol: "strikethrough", tip: "删除线（⌘⇧X）", action: #selector(toggleStrikethrough))
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [boldButton, bulletButton, strikethroughButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        boldButton.target = self
        bulletButton.target = self
        strikethroughButton.target = self
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = NSColor.black.withAlphaComponent(0.42)
        statusLabel.alignment = .right
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func updateFormatting(isBold: Bool, isBulletList: Bool, isStrikethrough: Bool) {
        update(button: boldButton, active: isBold)
        update(button: bulletButton, active: isBulletList)
        update(button: strikethroughButton, active: isStrikethrough)
    }

    private static func makeButton(symbol: String, tip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage(size: NSSize(width: 15, height: 15))
        let button = NSButton(image: image, target: nil, action: action)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.setButtonType(.toggle)
        button.toolTip = tip
        button.setAccessibilityLabel(tip)
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return button
    }

    private func update(button: NSButton, active: Bool) {
        button.state = active ? .on : .off
        button.contentTintColor = NSColor.black.withAlphaComponent(active ? 0.88 : 0.50)
    }

    @objc private func toggleBold() { delegate?.didTapBold() }
    @objc private func toggleBullet() { delegate?.didTapBulletList() }
    @objc private func toggleStrikethrough() { delegate?.didTapStrikethrough() }
}

final class StickyTextView: NSTextView {
    var onToggleBold: (() -> Void)?
    var onToggleBulletList: (() -> Void)?
    var onToggleStrikethrough: (() -> Void)?
    var onListNewline: (() -> Bool)?
    var onAdjustBulletLevel: ((Int) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        let key = event.charactersIgnoringModifiers?.lowercased()
        if modifiers == [.command], key == "b" {
            onToggleBold?()
            return true
        }
        let isBulletShortcut = modifiers == [.command, .shift] && (key == "8" || key == "*")
        if isBulletShortcut {
            onToggleBulletList?()
            return true
        }
        if modifiers == [.command, .shift], key == "x" {
            onToggleStrikethrough?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        if onListNewline?() == true { return }
        super.insertNewline(sender)
    }

    override func insertTab(_ sender: Any?) {
        if onAdjustBulletLevel?(1) == true { return }
        super.insertTab(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        if onAdjustBulletLevel?(-1) == true { return }
        super.insertBacktab(sender)
    }

    override func paste(_ sender: Any?) {
        super.pasteAsPlainText(sender)
    }
}

final class StickyRootView: NSView {
    let toolbar: StickyToolbarView
    let footer = StickyFormattingFooterView()
    let textView = StickyTextView()
    var statusLabel: NSTextField { footer.statusLabel }
    private let divider = NSBox()
    private let footerDivider = NSBox()

    init(note: StickyNote) {
        toolbar = StickyToolbarView(color: note.color, isPinned: note.isPinned)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        updateColor(note.color)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NoteAppearance.bodyFont()
        textView.textColor = NSColor.black.withAlphaComponent(0.78)
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.setAccessibilityLabel("便签内容")
        if let restored = RichTextCodec.decode(note.richTextData) {
            textView.textStorage?.setAttributedString(restored)
        } else {
            textView.string = note.text
        }
        textView.typingAttributes = [
            .font: NoteAppearance.bodyFont(),
            .foregroundColor: NSColor.black.withAlphaComponent(0.78)
        ]
        scrollView.documentView = textView

        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        footerDivider.boxType = .separator
        footerDivider.translatesAutoresizingMaskIntoConstraints = false

        addSubview(toolbar)
        addSubview(divider)
        addSubview(scrollView)
        addSubview(footerDivider)
        addSubview(footer)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerDivider.topAnchor),
            footerDivider.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerDivider.trailingAnchor.constraint(equalTo: trailingAnchor),
            footerDivider.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func updateColor(_ color: NoteColor) {
        layer?.backgroundColor = color.background.cgColor
    }

    func updateSelection(_ isSelected: Bool) {
        layer?.borderWidth = isSelected ? 3 : 0
        layer?.borderColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor : nil
    }
}
