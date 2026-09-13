import AppKit
import Foundation

/// 颜色选择弹窗：四个色块，选中项只用一条极细的边框标记（不加厚重的灰色外框）。
final class ColorPaletteViewController: NSViewController {

    /// 用户点了某个颜色
    var onPick: ((Note.NoteColor) -> Void)?
    /// 当前便签的颜色
    var selectedColor: Note.NoteColor = .yellow

    private var swatches: [ColorSwatchView] = []
    private let padding: CGFloat = 12
    private let swatchSize: CGFloat = 30
    private let spacing: CGFloat = 8

    override func loadView() {
        let width = padding * 2 + swatchSize * CGFloat(Note.NoteColor.allCases.count)
            + spacing * CGFloat(Note.NoteColor.allCases.count - 1)
        let height = padding * 2 + swatchSize
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        self.view = container
        self.preferredContentSize = NSSize(width: width, height: height)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = spacing
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        for color in Note.NoteColor.allCases {
            let swatch = ColorSwatchView(color: color)
            swatch.translatesAutoresizingMaskIntoConstraints = false
            swatch.widthAnchor.constraint(equalToConstant: swatchSize).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: swatchSize).isActive = true
            swatch.onClick = { [weak self] picked in
                guard let self = self else { return }
                self.selectedColor = picked
                self.refreshSelection()
                self.onPick?(picked)
            }
            stack.addArrangedSubview(swatch)
            swatches.append(swatch)
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        refreshSelection()
    }

    func refreshSelection() {
        for swatch in swatches {
            swatch.isSelected = (swatch.color == selectedColor)
        }
    }
}

// MARK: - 单个色块

final class ColorSwatchView: NSView {

    let color: Note.NoteColor
    var onClick: ((Note.NoteColor) -> Void)?
    var isSelected: Bool = false {
        didSet { needsDisplay = true }
    }

    init(color: Note.NoteColor) {
        self.color = color
        super.init(frame: .zero)
        toolTip = color.displayName
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(color)
    }

    override func draw(_ dirtyRect: NSRect) {
        // 色块本体（四周留 2pt 余量，让选中框始终落在里面）
        let body = bounds.insetBy(dx: 2, dy: 2)
        let bodyPath = NSBezierPath(roundedRect: body, xRadius: 7, yRadius: 7)
        color.background.setFill()
        bodyPath.fill()

        if isSelected {
            // 极细的选中描边：贴着色块边缘画 1pt，颜色取自该配色的深色强调色
            let border = NSBezierPath(
                roundedRect: body.insetBy(dx: 0.5, dy: 0.5),
                xRadius: 7,
                yRadius: 7
            )
            color.accent.withAlphaComponent(0.9).setStroke()
            border.lineWidth = 1
            border.stroke()
        }
    }
}
