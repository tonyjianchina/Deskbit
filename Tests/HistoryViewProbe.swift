import AppKit

@main
struct HistoryViewProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        var first = StickyNote.fresh(index: 0)
        first.text = "完成的第一条便签"
        first.completedAt = Date(timeIntervalSince1970: 100)
        var second = StickyNote.fresh(index: 1)
        second.text = "完成的第二条便签"
        second.completedAt = Date(timeIntervalSince1970: 200)

        var restoredID: UUID?
        var deletedID: UUID?
        var clearCount = 0
        let controller = HistoryPopoverViewController(
            notes: [second, first],
            onRestore: { restoredID = $0 },
            onDelete: { deletedID = $0 },
            onClear: { clearCount += 1 }
        )
        controller.loadView()
        controller.view.frame = NSRect(origin: .zero, size: controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()

        guard controller.preferredContentSize.width == 340,
              controller.preferredContentSize.height >= 180 else { exit(1) }
        let controls = descendants(of: controller.view).compactMap { $0 as? NSControl }
        let labels = controls.compactMap { $0.accessibilityLabel() }
        guard labels.filter({ $0 == "恢复便签" }).count == 2,
              labels.filter({ $0 == "永久删除便签" }).count == 2,
              labels.contains("清空历史便签") else { exit(2) }

        controls.first(where: { $0.accessibilityLabel() == "恢复便签" })?.performClick(nil)
        controls.first(where: { $0.accessibilityLabel() == "永久删除便签" })?.performClick(nil)
        controls.first(where: { $0.accessibilityLabel() == "清空历史便签" })?.performClick(nil)
        guard restoredID == second.id, deletedID == second.id, clearCount == 1 else { exit(3) }

        if CommandLine.arguments.count > 1,
           let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) {
            controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
            }
        }

        let emptyController = HistoryPopoverViewController(
            notes: [],
            onRestore: { _ in },
            onDelete: { _ in },
            onClear: {}
        )
        emptyController.loadView()
        let emptyLabels = descendants(of: emptyController.view)
            .compactMap { ($0 as? NSTextField)?.stringValue }
        guard emptyLabels.contains("暂无历史便签") else { exit(4) }

        let manyNotes = (0..<8).map { index -> StickyNote in
            var note = StickyNote.fresh(index: index)
            note.text = "历史便签 \(index + 1)"
            note.completedAt = Date(timeIntervalSince1970: TimeInterval(index))
            return note
        }
        let scrollingController = HistoryPopoverViewController(
            notes: manyNotes,
            onRestore: { _ in },
            onDelete: { _ in },
            onClear: {}
        )
        scrollingController.loadView()
        scrollingController.view.frame = NSRect(origin: .zero, size: scrollingController.preferredContentSize)
        scrollingController.view.layoutSubtreeIfNeeded()
        guard scrollingController.preferredContentSize.height == 420,
              let scrollView = descendants(of: scrollingController.view).compactMap({ $0 as? NSScrollView }).first,
              let documentView = scrollView.documentView,
              documentView.frame.height > scrollView.contentView.bounds.height else { exit(5) }

        print("history popover: pass")
    }

    @MainActor
    private static func descendants(of root: NSView) -> [NSView] {
        root.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
