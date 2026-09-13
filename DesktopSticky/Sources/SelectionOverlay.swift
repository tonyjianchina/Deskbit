import AppKit
import CoreGraphics
import Foundation

/// 桌面框选层。
///
/// 便签是各自独立的无边框窗口，桌面上没有公共画布，因此这里铺一层覆盖整块屏幕的
/// 透明窗口来接收鼠标拖拽：
///   - 层级略高于桌面图标、低于所有普通窗口，所以只有“空白桌面”上的拖拽会落到它身上；
///     点击便签/其他应用窗口时事件仍归它们自己处理。
///   - 拖拽时画一个选框，并把与选框相交的便签标记为选中。
///
/// 代价：该层会挡住桌面图标的点击，可在菜单栏「启用桌面框选」里随时关闭。
final class SelectionOverlayController {
    static let shared = SelectionOverlayController()

    private var windows: [SelectionOverlayWindow] = []
    private(set) var isActive = false

    private init() {}

    /// 在所有屏幕上铺开框选层
    func start() {
        guard !isActive else { return }
        isActive = true
        for screen in NSScreen.screens {
            let win = SelectionOverlayWindow(screen: screen)
            windows.append(win)
            win.orderFrontRegardless()
        }
    }

    /// 移除框选层，并清空选中
    func stop() {
        guard isActive else { return }
        isActive = false
        for win in windows { win.orderOut(nil) }
        windows.removeAll()
        AppDelegate.shared.clearSelection()
    }
}

// MARK: - 覆盖屏幕的透明窗口

final class SelectionOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        // 略高于桌面图标层，低于普通窗口层（normal = 0），因此不遮挡任何应用窗口。
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
    }

    // 只负责鼠标拖拽，不需要抢键盘焦点。
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - 绘制选框并结算命中的便签

final class SelectionOverlayView: NSView {
    private var startPoint: NSPoint?
    private var selectionRect: NSRect = .zero

    // 应用未激活时，第一次点击也要能落到这层上。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        // 在空白处重新按下 = 开始一次全新的框选，先清空旧选中
        AppDelegate.shared.clearSelection()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(
            x: min(start.x, p.x),
            y: min(start.y, p.y),
            width: abs(p.x - start.x),
            height: abs(p.y - start.y)
        )
        needsDisplay = true
        commitSelection()
    }

    override func mouseUp(with event: NSEvent) {
        commitSelection()
        startPoint = nil
        selectionRect = .zero
        needsDisplay = true
    }

    /// 把当前选框换算成屏幕坐标，计算命中的便签
    private func commitSelection() {
        guard let window = window else { return }
        let screenRect = window.convertToScreen(convert(selectionRect, to: nil))
        let ids = AppDelegate.shared.noteIDs(intersecting: screenRect)
        AppDelegate.shared.setSelection(ids)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard selectionRect.width > 0 || selectionRect.height > 0 else { return }
        let accent = NSColor.controlAccentColor
        accent.withAlphaComponent(0.14).setFill()
        selectionRect.fill()

        accent.withAlphaComponent(0.85).setStroke()
        let path = NSBezierPath(rect: selectionRect.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1
        path.stroke()
    }
}
