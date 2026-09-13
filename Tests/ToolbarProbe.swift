import AppKit

@main
struct ToolbarProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let toolbar = StickyToolbarView(color: .yellow, isPinned: false)
        let delegate = ToolbarDelegateProbe()
        toolbar.delegate = delegate
        guard toolbar.acceptsFirstMouse(for: nil) else { exit(11) }

        guard let stack = toolbar.subviews.compactMap({ $0 as? NSStackView }).first else { exit(1) }
        let labels = stack.arrangedSubviews.compactMap { ($0 as? NSButton)?.accessibilityLabel() }
        let expected = ["自动排序便签", "黄色", "蓝色", "绿色", "粉色", "新建便签", "置顶", "完成"]
        guard labels == expected else { exit(2) }

        let colorButtons = stack.arrangedSubviews.compactMap { $0 as? ColorDotButton }
        guard colorButtons.count == 4,
              colorButtons.allSatisfy({ $0.intrinsicContentSize.width == 18 }) else { exit(3) }
        guard let selectedColor = colorButtons.first(where: { $0.selectedColor }),
              selectedColor.outlineWidth == 0,
              selectedColor.dotDiameter == 14,
              selectedColor.haloDiameter == 18,
              colorButtons.filter({ !$0.selectedColor }).allSatisfy({
                  $0.outlineWidth == 0.5 && $0.dotDiameter == 12 && $0.haloDiameter == 0
              }) else { exit(4) }

        guard let arrange = stack.arrangedSubviews
            .compactMap({ $0 as? NSButton })
            .first(where: { $0.accessibilityLabel() == "自动排序便签" }) else { exit(5) }
        arrange.performClick(nil)
        guard delegate.arrangeCount == 1 else { exit(6) }

        toolbar.frame = NSRect(x: 0, y: 0, width: 300, height: 40)
        toolbar.layoutSubtreeIfNeeded()
        guard let spacer = stack.arrangedSubviews.first(where: { !($0 is NSControl) }) else { exit(7) }
        let spacerCenter = toolbar.convert(NSPoint(x: spacer.bounds.midX, y: spacer.bounds.midY), from: spacer)
        guard toolbar.hitTest(spacerCenter) === toolbar else { exit(8) }

        let root = StickyRootView(note: .fresh())
        guard root.textView.font?.pointSize == NoteAppearance.bodyFontSize else { exit(9) }

        print("toolbar layout: pass")
    }
}

@MainActor
private final class ToolbarDelegateProbe: StickyToolbarDelegate {
    var arrangeCount = 0

    func didChooseColor(_ color: NoteColor) {}
    func didTapArrange() { arrangeCount += 1 }
    func didBeginToolbarDrag(with event: NSEvent) {}
    func didTapBold() {}
    func didTapBulletList() {}
    func didTapStrikethrough() {}
    func didTapNew() {}
    func didTapPin() {}
    func didTapComplete() {}
}
