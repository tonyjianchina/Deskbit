import AppKit

@MainActor
final class FeedbackViewController: NSViewController, NSTextViewDelegate {
    typealias SubmitHandler = (String, @escaping (Result<FeedbackSubmission.Receipt, FeedbackSubmission.Error>) -> Void) -> Void

    private enum SubmissionState {
        case idle
        case sending
        case submitted
        case activationRequired
        case failed(FeedbackSubmission.Error)
    }

    private let onSubmit: SubmitHandler
    private let editor = NSTextView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let privacyLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let cancelButton = NSButton()
    private let sendButton = NSButton()
    private let limit = 4_000
    private var submissionState: SubmissionState = .idle

    private var isSending: Bool {
        if case .sending = submissionState { return true }
        return false
    }

    init(onSubmit: @escaping SubmitHandler) {
        self.onSubmit = onSubmit
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 460, height: 410)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(origin: .zero, size: preferredContentSize))

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor

        subtitleLabel.font = .systemFont(ofSize: 12.5)
        subtitleLabel.textColor = .secondaryLabelColor

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
        scrollView.documentView = editor

        privacyLabel.font = .systemFont(ofSize: 10.5)
        privacyLabel.textColor = .tertiaryLabelColor

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3

        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        sendButton.target = self
        sendButton.action = #selector(sendFeedback)
        sendButton.bezelStyle = .rounded
        sendButton.isEnabled = false

        let actions = NSStackView(views: [NSView(), cancelButton, sendButton])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 8

        let stack = NSStackView(views: [titleLabel, subtitleLabel, scrollView, privacyLabel, statusLabel, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        for label in [titleLabel, subtitleLabel, privacyLabel, statusLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
        }
        for label in [titleLabel, subtitleLabel, privacyLabel] {
            label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        }
        actions.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            subtitleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
            privacyLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.heightAnchor.constraint(equalToConstant: 48),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor),
            cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 76),
            sendButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])

        view = root
        refreshLocalization()
    }

    func refreshLocalization() {
        guard isViewLoaded else { return }
        titleLabel.stringValue = L10n.text("feedback.title")
        subtitleLabel.stringValue = L10n.text("feedback.subtitle")
        privacyLabel.stringValue = L10n.text("feedback.privacy")
        cancelButton.title = L10n.text("feedback.cancel")
        editor.setAccessibilityLabel(L10n.text("feedback.message.accessibility"))
        statusLabel.setAccessibilityLabel(L10n.text("feedback.status.accessibility"))
        sendButton.setAccessibilityLabel(L10n.text("feedback.send.accessibility"))
        refreshSubmissionState()
    }

    private func refreshSubmissionState() {
        sendButton.title = L10n.text(isSending ? "feedback.sendingButton" : "feedback.send")
        let normalized = editor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        sendButton.isEnabled = !isSending && !normalized.isEmpty && editor.string.count <= limit
        editor.isEditable = !isSending

        switch submissionState {
        case .idle:
            statusLabel.stringValue = ""
            statusLabel.textColor = .secondaryLabelColor
        case .sending:
            statusLabel.stringValue = L10n.text("feedback.status.sending")
            statusLabel.textColor = .secondaryLabelColor
        case .submitted:
            statusLabel.stringValue = L10n.text("feedback.status.submitted")
            statusLabel.textColor = .systemGreen
        case .activationRequired:
            statusLabel.stringValue = L10n.text("feedback.status.activationRequired")
            statusLabel.textColor = .systemOrange
        case let .failed(error):
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
        statusLabel.toolTip = statusLabel.stringValue.isEmpty ? nil : statusLabel.stringValue
    }

    func focusEditor() {
        view.window?.makeFirstResponder(editor)
    }

    func textDidChange(_ notification: Notification) {
        switch submissionState {
        case .submitted, .activationRequired, .failed:
            submissionState = .idle
        case .idle, .sending:
            break
        }
        refreshSubmissionState()
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
        guard !isSending, !message.isEmpty, editor.string.count <= limit else { return }
        submissionState = .sending
        refreshSubmissionState()

        onSubmit(message) { [weak self] result in
            self?.finishSubmission(result)
        }
    }

    private func finishSubmission(_ result: Result<FeedbackSubmission.Receipt, FeedbackSubmission.Error>) {
        switch result {
        case .success(.submitted):
            editor.string = ""
            submissionState = .submitted
        case .success(.activationRequired):
            submissionState = .activationRequired
        case let .failure(error):
            submissionState = .failed(error)
        }
        refreshSubmissionState()
    }

    @objc private func cancel() {
        view.window?.close()
    }
}
