import AppKit

@main
struct FeedbackViewProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        var submittedMessage: String?
        let controller = FeedbackViewController { message, completion in
            submittedMessage = message
            completion(.success(.submitted))
        }
        controller.loadView()
        controller.view.frame = NSRect(x: 0, y: 0, width: 420, height: 330)
        controller.view.layoutSubtreeIfNeeded()

        let views = descendants(of: controller.view)
        let labels = views.compactMap { ($0 as? NSTextField)?.stringValue }
        guard labels.contains(where: { $0.contains("FormSubmit") && $0.contains("敏感信息") }) else { exit(1) }

        guard let editor = views.compactMap({ $0 as? NSTextView }).first,
              let sendButton = views.compactMap({ $0 as? NSButton }).first(where: {
                  $0.accessibilityLabel() == "发送反馈"
              }),
              !sendButton.isEnabled else { exit(2) }

        editor.string = "  希望增加搜索功能  "
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        guard sendButton.isEnabled else { exit(3) }
        sendButton.performClick(nil)

        let updatedLabels = descendants(of: controller.view).compactMap { ($0 as? NSTextField)?.stringValue }
        guard submittedMessage == "希望增加搜索功能",
              updatedLabels.contains("发送成功，谢谢你的反馈。"),
              editor.string.isEmpty,
              !sendButton.isEnabled else { exit(4) }

        let activationController = FeedbackViewController { _, completion in
            completion(.success(.activationRequired))
        }
        activationController.loadView()
        let activationViews = descendants(of: activationController.view)
        guard let activationEditor = activationViews.compactMap({ $0 as? NSTextView }).first,
              let activationButton = activationViews.compactMap({ $0 as? NSButton }).first(where: {
                  $0.accessibilityLabel() == "发送反馈"
              }) else { exit(5) }
        activationEditor.string = "首次反馈"
        activationController.textDidChange(Notification(name: NSText.didChangeNotification, object: activationEditor))
        activationButton.performClick(nil)
        let activationLabels = descendants(of: activationController.view).compactMap { ($0 as? NSTextField)?.stringValue }
        guard activationLabels.contains(where: { $0.contains("尚未发送") && $0.contains("激活后重试") }),
              activationEditor.string == "首次反馈",
              activationButton.isEnabled else { exit(6) }

        print("feedback view: pass")
    }

    @MainActor
    private static func descendants(of root: NSView) -> [NSView] {
        root.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
