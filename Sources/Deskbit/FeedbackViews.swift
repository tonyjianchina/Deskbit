import AppKit

@MainActor
final class FeedbackViewController: NSViewController, NSTextViewDelegate {
    typealias SubmitHandler = (String, @escaping (Result<FeedbackSubmission.Receipt, FeedbackSubmission.Error>) -> Void) -> Void

    private let onSubmit: SubmitHandler
    private let editor = NSTextView(frame: .zero)
    private let statusLabel = NSTextField(labelWithString: "")
    private let sendButton = NSButton()
    private let limit = 4_000

    init(onSubmit: @escaping SubmitHandler) {
        self.onSubmit = onSubmit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 330))

        let title = NSTextField(labelWithString: "把你的想法告诉我们")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .labelColor

        let subtitle = NSTextField(wrappingLabelWithString: "你的建议会帮助 Deskbit 变得更好。")
        subtitle.font = .systemFont(ofSize: 12.5)
        subtitle.textColor = .secondaryLabelColor

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        editor.delegate = self
        editor.font = .systemFont(ofSize: 14)
        editor.textColor = .textColor
        editor.backgroundColor = .textBackgroundColor
        editor.textContainerInset = NSSize(width: 9, height: 8)
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.minSize = NSSize(width: 0, height: 142)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.setAccessibilityLabel("反馈内容")
        scrollView.documentView = editor

        let privacy = NSTextField(wrappingLabelWithString: "反馈将通过 FormSubmit 第三方服务发送，请勿填写密码、身份信息等敏感信息。")
        privacy.font = .systemFont(ofSize: 10.5)
        privacy.textColor = .tertiaryLabelColor

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setAccessibilityLabel("反馈发送状态")

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        sendButton.title = "发送"
        sendButton.target = self
        sendButton.action = #selector(sendFeedback)
        sendButton.bezelStyle = .rounded
        sendButton.isEnabled = false
        sendButton.setAccessibilityLabel("发送反馈")

        let actions = NSStackView(views: [statusLabel, NSView(), cancelButton, sendButton])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 8

        let stack = NSStackView(views: [title, subtitle, scrollView, privacy, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        privacy.translatesAutoresizingMaskIntoConstraints = false
        actions.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            title.widthAnchor.constraint(equalTo: stack.widthAnchor),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 150),
            privacy.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 215)
        ])

        view = root
    }

    func focusEditor() {
        view.window?.makeFirstResponder(editor)
    }

    func textDidChange(_ notification: Notification) {
        let normalized = editor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        sendButton.isEnabled = !normalized.isEmpty && editor.string.count <= limit
        if statusLabel.stringValue.hasPrefix("发送成功") || statusLabel.stringValue.hasPrefix("发送失败") {
            statusLabel.stringValue = ""
        }
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let replacementString,
              let range = Range(affectedCharRange, in: textView.string) else { return true }
        return textView.string.replacingCharacters(in: range, with: replacementString).count <= limit
    }

    @objc private func sendFeedback() {
        let message = editor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        sendButton.isEnabled = false
        sendButton.title = "发送中…"
        statusLabel.stringValue = "正在安全发送…"
        statusLabel.textColor = .secondaryLabelColor

        onSubmit(message) { [weak self] result in
            self?.finishSubmission(result)
        }
    }

    private func finishSubmission(_ result: Result<FeedbackSubmission.Receipt, FeedbackSubmission.Error>) {
        sendButton.title = "发送"
        switch result {
        case let .success(receipt):
            editor.string = ""
            sendButton.isEnabled = false
            statusLabel.stringValue = receipt == .activationRequired
                ? "已提交；首次使用请在收件邮箱完成 FormSubmit 激活。"
                : "发送成功，谢谢你的反馈。"
            statusLabel.textColor = .systemGreen
        case let .failure(error):
            sendButton.isEnabled = true
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
    }

    @objc private func cancel() {
        view.window?.close()
    }
}
