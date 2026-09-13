import AppKit

@MainActor
enum RichTextFormatting {
    private static let listIndentStep: CGFloat = 18
    private static let maximumListLevel = 8
    private static let bulletMarkers = ["•", "∘", "▪"]
    private static let legacyBulletMarkers = ["◦", "○"]

    static func toggleBold(in textView: NSTextView) {
        let storage = textView.textStorage ?? NSTextStorage()
        let selected = textView.selectedRange()
        let currentFont = font(in: textView)
        let shouldBold = !NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)

        if selected.length > 0 {
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selected) { value, range, _ in
                let source = (value as? NSFont) ?? NoteAppearance.bodyFont()
                let converted = shouldBold
                    ? NSFontManager.shared.convert(source, toHaveTrait: .boldFontMask)
                    : NSFontManager.shared.convert(source, toNotHaveTrait: .boldFontMask)
                storage.addAttribute(.font, value: converted, range: range)
            }
            storage.endEditing()
        } else {
            var typing = textView.typingAttributes
            typing[.font] = shouldBold
                ? NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
            textView.typingAttributes = typing
        }
    }

    static func toggleStrikethrough(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let selected = textView.selectedRange()
        let shouldStrike = !isStrikethrough(in: textView)

        if selected.length > 0 {
            if shouldStrike {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: selected)
            } else {
                storage.removeAttribute(.strikethroughStyle, range: selected)
            }
        } else {
            var typing = textView.typingAttributes
            if shouldStrike {
                typing[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            } else {
                typing.removeValue(forKey: .strikethroughStyle)
            }
            textView.typingAttributes = typing
        }
    }

    static func toggleBulletList(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let selected = textView.selectedRange()
        let starts = paragraphStarts(in: storage.string, selection: selected)
        let allBulleted = !starts.isEmpty && starts.allSatisfy { hasBullet(in: storage.string, at: $0) }
        var newLocation = selected.location
        var newLength = selected.length

        storage.beginEditing()
        for start in starts.reversed() {
            if allBulleted, hasBullet(in: storage.string, at: start) {
                storage.replaceCharacters(in: NSRange(location: start, length: 2), with: "")
                adjustSelection(location: &newLocation, length: &newLength, changeAt: start, delta: -2)
                applyListIndent(false, storage: storage, location: min(start, storage.length))
            } else if !allBulleted, !hasBullet(in: storage.string, at: start) {
                storage.replaceCharacters(in: NSRange(location: start, length: 0), with: "• ")
                adjustSelection(location: &newLocation, length: &newLength, changeAt: start, delta: 2)
                applyListIndent(true, storage: storage, location: start)
            }
        }
        storage.endEditing()
        setTypingListIndent(!allBulleted, textView: textView)
        textView.setSelectedRange(NSRange(location: min(newLocation, storage.length), length: min(newLength, max(0, storage.length - newLocation))))
    }

    @discardableResult
    static func adjustBulletLevel(in textView: NSTextView, delta: Int) -> Bool {
        guard delta == -1 || delta == 1, let storage = textView.textStorage else { return false }
        let originalSelection = textView.selectedRange()
        let starts = paragraphStarts(in: storage.string, selection: originalSelection)
            .filter { hasBullet(in: storage.string, at: $0) }
        guard !starts.isEmpty else { return false }

        var changed = false
        storage.beginEditing()
        for start in starts {
            guard start < storage.length else { continue }
            let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: start, length: 0))
            let existing = storage.attribute(.paragraphStyle, at: start, effectiveRange: nil) as? NSParagraphStyle
            let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            let currentLevel = max(0, Int(round(style.firstLineHeadIndent / listIndentStep)))
            let requestedLevel = min(maximumListLevel, max(0, currentLevel + delta))
            let newLevel: Int
            if delta > 0 {
                let parentLimit = previousBulletLevel(before: start, storage: storage).map { $0 + 1 } ?? 0
                newLevel = min(requestedLevel, parentLimit)
            } else {
                newLevel = requestedLevel
            }
            guard newLevel != currentLevel else { continue }
            storage.replaceCharacters(
                in: NSRange(location: start, length: 1),
                with: bulletMarker(for: newLevel)
            )
            style.firstLineHeadIndent = CGFloat(newLevel) * listIndentStep
            style.headIndent = CGFloat(newLevel + 1) * listIndentStep
            storage.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
            changed = true
        }
        storage.endEditing()

        if changed {
            let selection = NSRange(
                location: min(originalSelection.location, storage.length),
                length: min(originalSelection.length, max(0, storage.length - originalSelection.location))
            )
            textView.setSelectedRange(selection)
            let location = storage.length == 0 ? 0 : min(selection.location, storage.length - 1)
            let style = storage.length == 0 ? nil : storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            setTypingListLevel(max(0, Int(round((style?.firstLineHeadIndent ?? 0) / listIndentStep))), textView: textView)
        }
        return changed
    }

    @discardableResult
    static func normalizeBulletMarkers(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage, storage.length > 0 else { return false }
        let starts = paragraphStarts(
            in: storage.string,
            selection: NSRange(location: 0, length: storage.length)
        ).filter { hasBullet(in: storage.string, at: $0) }
        var changed = false
        storage.beginEditing()
        for start in starts {
            let style = storage.attribute(.paragraphStyle, at: start, effectiveRange: nil) as? NSParagraphStyle
            let level = max(0, Int(round((style?.firstLineHeadIndent ?? 0) / listIndentStep)))
            let expected = bulletMarker(for: level)
            guard bulletMarker(in: storage.string, at: start) != expected else { continue }
            storage.replaceCharacters(in: NSRange(location: start, length: 1), with: expected)
            changed = true
        }
        storage.endEditing()
        return changed
    }

    private static func previousBulletLevel(before start: Int, storage: NSTextStorage) -> Int? {
        guard start > 0, storage.length > 0 else { return nil }
        let previousRange = (storage.string as NSString).paragraphRange(for: NSRange(location: start - 1, length: 0))
        guard hasBullet(in: storage.string, at: previousRange.location) else { return nil }
        let style = storage.attribute(.paragraphStyle, at: previousRange.location, effectiveRange: nil) as? NSParagraphStyle
        return max(0, Int(round((style?.firstLineHeadIndent ?? 0) / listIndentStep)))
    }

    static func isBold(in textView: NSTextView) -> Bool {
        NSFontManager.shared.traits(of: font(in: textView)).contains(.boldFontMask)
    }

    static func isStrikethrough(in textView: NSTextView) -> Bool {
        let selected = textView.selectedRange()
        let value: Any?
        if selected.length == 0 {
            value = textView.typingAttributes[.strikethroughStyle]
        } else if let storage = textView.textStorage, storage.length > 0 {
            value = storage.attribute(
                .strikethroughStyle,
                at: min(selected.location, storage.length - 1),
                effectiveRange: nil
            )
        } else {
            value = nil
        }
        return (value as? NSNumber)?.intValue == NSUnderlineStyle.single.rawValue
            || (value as? Int) == NSUnderlineStyle.single.rawValue
    }

    static func isBulletList(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        return paragraphStarts(in: storage.string, selection: textView.selectedRange()).first.map {
            hasBullet(in: storage.string, at: $0)
        } ?? false
    }

    @discardableResult
    static func applyMarkdownSyntax(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        var selection = textView.selectedRange()
        let originalTypingAttributes = textView.typingAttributes
        var changed = false

        if let expression = try? NSRegularExpression(pattern: #"\*\*([^*\n]+)\*\*"#) {
            let matches = expression.matches(in: storage.string, range: NSRange(location: 0, length: storage.length))
            for match in matches.reversed() {
                let innerRange = NSRange(location: match.range.location + 2, length: match.range.length - 4)
                let replacement = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: innerRange))
                replacement.enumerateAttribute(.font, in: NSRange(location: 0, length: replacement.length)) { value, range, _ in
                    let font = (value as? NSFont) ?? NoteAppearance.bodyFont()
                    replacement.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask), range: range)
                }
                storage.replaceCharacters(in: match.range, with: replacement)
                selection = adjustedSelection(selection, replacing: match.range, markerWidth: 2)
                changed = true
            }
        }

        if let expression = try? NSRegularExpression(pattern: #"~~([^~\n]+)~~"#) {
            let matches = expression.matches(in: storage.string, range: NSRange(location: 0, length: storage.length))
            for match in matches.reversed() {
                let innerRange = NSRange(location: match.range.location + 2, length: match.range.length - 4)
                let replacement = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: innerRange))
                replacement.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: NSRange(location: 0, length: replacement.length)
                )
                storage.replaceCharacters(in: match.range, with: replacement)
                selection = adjustedSelection(selection, replacing: match.range, markerWidth: 2)
                changed = true
            }
        }

        if let expression = try? NSRegularExpression(pattern: #"(?m)^[*-] "#) {
            let matches = expression.matches(in: storage.string, range: NSRange(location: 0, length: storage.length))
            for match in matches.reversed() {
                storage.replaceCharacters(in: match.range, with: "• ")
                applyListIndent(true, storage: storage, location: match.range.location)
                changed = true
            }
        }

        if changed {
            textView.setSelectedRange(NSRange(location: min(selection.location, storage.length), length: min(selection.length, max(0, storage.length - selection.location))))
            textView.typingAttributes = originalTypingAttributes
            setTypingListIndent(isBulletList(in: textView), textView: textView)
        }
        return changed
    }

    static func handleListNewline(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        guard selection.length == 0, selection.location <= storage.length else { return false }
        let nsString = storage.string as NSString
        let lookup = storage.length == 0 ? 0 : min(selection.location, storage.length - 1)
        let paragraph = storage.length == 0
            ? NSRange(location: 0, length: 0)
            : nsString.paragraphRange(for: NSRange(location: lookup, length: 0))
        guard let marker = bulletMarker(in: storage.string, at: paragraph.location) else { return false }

        let content = nsString.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
        if content == marker {
            storage.replaceCharacters(in: NSRange(location: paragraph.location, length: 2), with: "")
            setTypingListIndent(false, textView: textView)
            textView.setSelectedRange(NSRange(location: paragraph.location, length: 0))
            textView.didChangeText()
        } else {
            textView.insertText("\n\(marker) ", replacementRange: selection)
        }
        return true
    }

    private static func font(in textView: NSTextView) -> NSFont {
        let selected = textView.selectedRange()
        if selected.length == 0 {
            return (textView.typingAttributes[.font] as? NSFont) ?? NoteAppearance.bodyFont()
        }
        if let storage = textView.textStorage, storage.length > 0 {
            let location = min(selected.location, storage.length - 1)
            return (storage.attribute(.font, at: location, effectiveRange: nil) as? NSFont) ?? NoteAppearance.bodyFont()
        }
        return NoteAppearance.bodyFont()
    }

    private static func paragraphStarts(in string: String, selection: NSRange) -> [Int] {
        let nsString = string as NSString
        if nsString.length == 0 { return [0] }
        if selection.length == 0, selection.location == nsString.length, string.hasSuffix("\n") { return [nsString.length] }

        let safeLocation = min(selection.location, nsString.length - 1)
        let safeLength = min(selection.length, nsString.length - safeLocation)
        let encompassing = nsString.paragraphRange(for: NSRange(location: safeLocation, length: safeLength))
        var starts: [Int] = []
        var cursor = encompassing.location
        while cursor < NSMaxRange(encompassing), cursor < nsString.length {
            starts.append(cursor)
            let paragraph = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
            let next = NSMaxRange(paragraph)
            if next <= cursor { break }
            cursor = next
        }
        return starts
    }

    private static func hasBullet(in string: String, at location: Int) -> Bool {
        bulletMarker(in: string, at: location) != nil
    }

    private static func bulletMarker(in string: String, at location: Int) -> String? {
        let nsString = string as NSString
        guard location + 2 <= nsString.length,
              nsString.substring(with: NSRange(location: location + 1, length: 1)) == " " else { return nil }
        let marker = nsString.substring(with: NSRange(location: location, length: 1))
        return (bulletMarkers + legacyBulletMarkers).contains(marker) ? marker : nil
    }

    private static func bulletMarker(for level: Int) -> String {
        bulletMarkers[min(max(0, level), bulletMarkers.count - 1)]
    }

    private static func applyListIndent(_ enabled: Bool, storage: NSTextStorage, location: Int) {
        guard storage.length > 0 else { return }
        let safeLocation = min(location, storage.length - 1)
        let range = (storage.string as NSString).paragraphRange(for: NSRange(location: safeLocation, length: 0))
        let existing = storage.attribute(.paragraphStyle, at: safeLocation, effectiveRange: nil) as? NSParagraphStyle
        let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0
        style.headIndent = enabled ? listIndentStep : 0
        storage.addAttribute(.paragraphStyle, value: style, range: range)
    }

    private static func setTypingListIndent(_ enabled: Bool, textView: NSTextView) {
        setTypingListLevel(enabled ? 0 : nil, textView: textView)
    }

    private static func setTypingListLevel(_ level: Int?, textView: NSTextView) {
        var typing = textView.typingAttributes
        let existing = typing[.paragraphStyle] as? NSParagraphStyle
        let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.firstLineHeadIndent = CGFloat(level ?? 0) * listIndentStep
        style.headIndent = level.map { CGFloat($0 + 1) * listIndentStep } ?? 0
        typing[.paragraphStyle] = style
        textView.typingAttributes = typing
    }

    private static func adjustSelection(location: inout Int, length: inout Int, changeAt: Int, delta: Int) {
        let originalLocation = location
        let originalEnd = location + length
        if length == 0 {
            if changeAt <= originalLocation { location = max(0, originalLocation + delta) }
        } else if changeAt < originalLocation {
            location = max(0, originalLocation + delta)
        } else if changeAt <= originalEnd {
            length = max(0, length + delta)
        }
    }

    private static func adjustedSelection(_ selection: NSRange, replacing range: NSRange, markerWidth: Int) -> NSRange {
        func adjust(_ offset: Int) -> Int {
            if offset <= range.location { return offset }
            if offset >= NSMaxRange(range) { return offset - markerWidth * 2 }
            return max(range.location, offset - markerWidth)
        }
        let start = adjust(selection.location)
        let end = adjust(NSMaxRange(selection))
        return NSRange(location: start, length: max(0, end - start))
    }
}
