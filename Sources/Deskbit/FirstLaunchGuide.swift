import AppKit

enum FirstLaunchGuide {
    static var text: String { attributedText.string }

    static var attributedText: NSAttributedString {
        let regularFont = NoteAppearance.bodyFont()
        let boldFont = NoteAppearance.bodyFont(weight: .bold)
        let result = NSMutableAttributedString(
            string: L10n.text("onboarding.note"),
            attributes: [
                .font: regularFont,
                .foregroundColor: NSColor.black.withAlphaComponent(0.78)
            ]
        )
        let fullRange = NSRange(location: 0, length: result.length)
        guard let expression = try? NSRegularExpression(pattern: #"\*\*([^*\n]+)\*\*"#) else {
            return result
        }

        for match in expression.matches(in: result.string, range: fullRange).reversed() {
            let innerRange = NSRange(location: match.range.location + 2, length: match.range.length - 4)
            let replacement = NSMutableAttributedString(attributedString: result.attributedSubstring(from: innerRange))
            replacement.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: replacement.length))
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result
    }
}
