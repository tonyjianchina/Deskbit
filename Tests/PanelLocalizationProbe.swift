import AppKit

@main
struct PanelLocalizationProbe {
    @MainActor
    static func descendants(_ root: NSView) -> [NSView] {
        root.subviews.flatMap { [$0] + descendants($0) }
    }

    static func language(_ identifier: String) {
        UserDefaults.standard.setVolatileDomain([L10n.preferenceKey: identifier], forName: UserDefaults.argumentDomain)
    }

    @MainActor
    static func main() {
        _ = NSApplication.shared
        let original = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { UserDefaults.standard.setVolatileDomain(original, forName: UserDefaults.argumentDomain) }
        language("en")
        precondition(L10n.text("feedback.title") == "Share your thoughts", "Translations must be merged first")
        var completion: ((Result<FeedbackSubmission.Receipt, FeedbackSubmission.Error>) -> Void)?
        var submitted: String?
        let controller = FeedbackViewController { message, callback in
            submitted = message
            completion = callback
        }
        controller.loadView()
        controller.view.frame = NSRect(origin: .zero, size: controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        let views = descendants(controller.view)
        let editor = views.compactMap { $0 as? NSTextView }.first!
        let buttons = views.compactMap { $0 as? NSButton }
        let send = buttons.first { $0.accessibilityLabel() == "Send feedback" }!
        let status = views.compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "Feedback status" }!
        precondition(!send.isEnabled)
        editor.string = "  Keep this draft 原样保留  "
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        editor.setSelectedRange(NSRange(location: 2, length: 4))
        let originalText = editor.string
        let originalSelection = editor.selectedRange()
        language("zh-Hans")
        controller.refreshLocalization()
        precondition(editor.string == originalText && editor.selectedRange() == originalSelection)
        precondition(send.title == "发送" && send.isEnabled)
        send.performClick(nil)
        precondition(submitted == "Keep this draft 原样保留" && !send.isEnabled && !editor.isEditable)
        language("en")
        controller.refreshLocalization()
        precondition(send.title == "Sending…" && status.stringValue == "Sending your feedback…")
        precondition(!send.isEnabled && editor.string == originalText)
        completion?(.failure(.serviceRejected("Temporary backend issue")))
        precondition(send.isEnabled && editor.isEditable && editor.string == originalText)
        precondition(status.stringValue == "The service did not accept your feedback: Temporary backend issue")
        language("zh-Hans")
        controller.refreshLocalization()
        precondition(status.stringValue == "服务未接受这次反馈：Temporary backend issue")
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        precondition(status.stringValue.isEmpty)
        send.performClick(nil)
        completion?(.success(.activationRequired))
        precondition(status.stringValue.contains("尚未发送") && send.isEnabled)
        language("en")
        controller.refreshLocalization()
        precondition(status.stringValue.hasPrefix("Not sent yet.") && editor.string == originalText)
        controller.view.layoutSubtreeIfNeeded()

        send.performClick(nil)
        language("zh-Hans")
        controller.refreshLocalization()
        completion?(.success(.submitted))
        precondition(status.stringValue == "发送成功，谢谢你的反馈。" && editor.string.isEmpty && !send.isEnabled)
        language("en")
        controller.refreshLocalization()
        precondition(status.stringValue == "Sent. Thank you for your feedback!")
        precondition(FeedbackSubmission.Error.rejected(statusCode: 503).localizedDescription == "Could not send (503). Please try again later.")
        let request = try! FeedbackSubmission.makeRequest(message: "Test only, never sent")
        let payload = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
        precondition(payload["_subject"] == "Deskbit user feedback")

        var note = StickyNote.fresh(index: 0)
        note.text = ""
        note.completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let history = HistoryPopoverViewController(notes: [note], onRestore: { _ in }, onDelete: { _ in }, onClear: {})
        history.loadView()
        history.view.frame = NSRect(origin: .zero, size: history.preferredContentSize)
        history.view.layoutSubtreeIfNeeded()
        let historyViews = descendants(history.view)
        let labels = historyViews.compactMap { ($0 as? NSTextField)?.stringValue }
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
        precondition(labels.contains("1 note") && labels.contains("Blank note") && labels.contains(formatter.string(from: note.completedAt!)))
        let restore = historyViews.compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "Restore note" }!
        precondition(restore.frame.width >= 62)

        print("panel localization: pass (draft/selection, sending switch, errors, activation, success, date, count, button width; no network requests)")
    }
}
