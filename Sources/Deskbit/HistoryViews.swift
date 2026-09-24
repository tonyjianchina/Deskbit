import AppKit

@MainActor
final class HistoryPopoverViewController: NSViewController {
    private let notes: [StickyNote]
    private let onRestore: (UUID) -> Void
    private let onDelete: (UUID) -> Void
    private let onClear: () -> Void

    init(
        notes: [StickyNote],
        onRestore: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.notes = notes
        self.onRestore = onRestore
        self.onDelete = onDelete
        self.onClear = onClear
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 340, height: min(420, max(180, 116 + notes.count * 72)))
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: L10n.text("history.title"))
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = NSColor.labelColor

        let count = NSTextField(labelWithString: L10n.noteCount(notes.count))
        count.font = .systemFont(ofSize: 11, weight: .medium)
        count.textColor = .secondaryLabelColor

        let header = NSStackView(views: [title, NSView(), count])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        let document = FlippedHistoryDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .width
        list.spacing = 8
        list.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(list)
        scrollView.documentView = document

        if notes.isEmpty {
            let empty = NSTextField(labelWithString: L10n.text("history.empty"))
            empty.alignment = .center
            empty.font = .systemFont(ofSize: 13)
            empty.textColor = .tertiaryLabelColor
            empty.translatesAutoresizingMaskIntoConstraints = false
            list.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 88).isActive = true
        } else {
            for note in notes {
                let row = HistoryNoteRowView(note: note, onRestore: onRestore, onDelete: onDelete)
                list.addArrangedSubview(row)
                row.heightAnchor.constraint(equalToConstant: 64).isActive = true
            }
        }
        let listContentHeight: CGFloat = notes.isEmpty
            ? 92
            : CGFloat(notes.count * 64 + max(0, notes.count - 1) * 8 + 4)

        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            document.heightAnchor.constraint(equalToConstant: max(listContentHeight, preferredContentSize.height - 84)),
            list.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 2),
            list.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -2),
            list.topAnchor.constraint(equalTo: document.topAnchor, constant: 2),
            list.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor, constant: -2)
        ])

        let clearButton = NSButton(title: L10n.text("history.clear"), target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .inline
        clearButton.font = .systemFont(ofSize: 12)
        clearButton.contentTintColor = .systemRed
        clearButton.isEnabled = !notes.isEmpty
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setAccessibilityLabel(L10n.text("history.clear.accessibility"))
        root.addSubview(clearButton)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            header.heightAnchor.constraint(equalToConstant: 24),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -8),
            clearButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            clearButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -9),
            clearButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        view = root
    }

    @objc private func clearHistory() { onClear() }
}

private final class FlippedHistoryDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class HistoryNoteRowView: NSView {
    private let noteID: UUID
    private let onRestore: (UUID) -> Void
    private let onDelete: (UUID) -> Void

    init(note: StickyNote, onRestore: @escaping (UUID) -> Void, onDelete: @escaping (UUID) -> Void) {
        noteID = note.id
        self.onRestore = onRestore
        self.onDelete = onDelete
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = note.color.background.withAlphaComponent(0.48).cgColor

        let colorDot = HistoryColorDotView(color: note.color.swatch)
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(colorDot)

        let previewText = note.text
            .split(whereSeparator: \Character.isNewline)
            .map(String.init)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? L10n.text("history.blankNote")
        let preview = NSTextField(labelWithString: String(previewText.prefix(34)))
        preview.font = .systemFont(ofSize: 13, weight: .medium)
        preview.textColor = NSColor.labelColor.withAlphaComponent(0.82)
        preview.lineBreakMode = .byTruncatingTail

        let completed = NSTextField(labelWithString: Self.formattedDate(note.completedAt))
        completed.font = .systemFont(ofSize: 10.5)
        completed.textColor = .secondaryLabelColor

        let labels = NSStackView(views: [preview, completed])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(labels)

        let restore = NSButton(title: L10n.text("history.restore"), target: self, action: #selector(restoreNote))
        restore.bezelStyle = .inline
        restore.font = .systemFont(ofSize: 12, weight: .medium)
        restore.toolTip = L10n.text("history.restore.accessibility")
        restore.setAccessibilityLabel(L10n.text("history.restore.accessibility"))
        restore.translatesAutoresizingMaskIntoConstraints = false
        addSubview(restore)

        let trashImage = NSImage(systemSymbolName: "trash", accessibilityDescription: L10n.text("history.delete.accessibility"))
        let delete = NSButton(image: trashImage ?? NSImage(), target: self, action: #selector(deleteNote))
        delete.isBordered = false
        delete.imagePosition = .imageOnly
        delete.contentTintColor = NSColor.systemRed.withAlphaComponent(0.74)
        delete.toolTip = L10n.text("history.delete")
        delete.setAccessibilityLabel(L10n.text("history.delete.accessibility"))
        delete.translatesAutoresizingMaskIntoConstraints = false
        addSubview(delete)

        NSLayoutConstraint.activate([
            colorDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            colorDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            colorDot.widthAnchor.constraint(equalToConstant: 10),
            colorDot.heightAnchor.constraint(equalToConstant: 10),
            labels.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 9),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: restore.leadingAnchor, constant: -6),
            restore.trailingAnchor.constraint(equalTo: delete.leadingAnchor, constant: -2),
            restore.centerYAnchor.constraint(equalTo: centerYAnchor),
            restore.widthAnchor.constraint(greaterThanOrEqualToConstant: 62),
            delete.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            delete.centerYAnchor.constraint(equalTo: centerYAnchor),
            delete.widthAnchor.constraint(equalToConstant: 26),
            delete.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { nil }

    @objc private func restoreNote() { onRestore(noteID) }
    @objc private func deleteNote() { onDelete(noteID) }

    private static func formattedDate(_ date: Date?) -> String {
        guard let date else { return L10n.text("history.unknownCompletionTime") }
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
        return formatter.string(from: date)
    }
}

private final class HistoryColorDotView: NSView {
    private let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).fill()
    }
}
