import AppKit
import CoreText

@main
struct RichTextProbe {
    @MainActor
    static func main() {
        func markerDiameter(_ symbol: String) -> CGFloat {
            let baseFont = NoteAppearance.bodyFont() as CTFont
            let value = symbol as CFString
            let font = CTFontCreateForString(
                baseFont,
                value,
                CFRange(location: 0, length: CFStringGetLength(value))
            )
            var characters = Array(symbol.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
            var glyph = glyphs[0]
            return CTFontGetBoundingRectsForGlyphs(font, .default, &glyph, nil, 1).height
        }

        let filledDiameter = markerDiameter("•")
        let ringDiameter = markerDiameter("∘")
        let squareDiameter = markerDiameter("▪")
        let markerProportionsAreBalanced = (1.45...1.75).contains(ringDiameter / filledDiameter)
            && (1.0...1.5).contains(squareDiameter / filledDiameter)

        let value = NSMutableAttributedString(string: "重点\n第二段")
        let bold = NSFontManager.shared.convert(NoteAppearance.bodyFont(), toHaveTrait: .boldFontMask)
        value.addAttribute(.font, value: bold, range: NSRange(location: 0, length: 2))
        value.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 3, length: 3))
        value.replaceCharacters(in: NSRange(location: 3, length: 0), with: "• ")

        guard let data = RichTextCodec.encode(value), let restored = RichTextCodec.decode(data) else { exit(1) }
        let restoredFont = restored.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let boldSurvived = restoredFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false
        let bulletSurvived = restored.string.contains("• 第二段")
        let strikeSurvived = (restored.attribute(.strikethroughStyle, at: 5, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue

        let editor = NSTextView()
        editor.isRichText = true
        editor.string = "普通文本"
        editor.typingAttributes = [.font: NoteAppearance.bodyFont()]
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        RichTextFormatting.toggleBold(in: editor)
        let futureBoldOn = RichTextFormatting.isBold(in: editor)
        RichTextFormatting.toggleBold(in: editor)
        let futureBoldOff = !RichTextFormatting.isBold(in: editor)

        let strikeEditor = NSTextView()
        strikeEditor.isRichText = true
        strikeEditor.string = "删除线"
        strikeEditor.setSelectedRange(NSRange(location: 0, length: strikeEditor.string.utf16.count))
        RichTextFormatting.toggleStrikethrough(in: strikeEditor)
        let strikeOn = RichTextFormatting.isStrikethrough(in: strikeEditor)
        RichTextFormatting.toggleStrikethrough(in: strikeEditor)
        let strikeOff = !RichTextFormatting.isStrikethrough(in: strikeEditor)

        let bulletEditor = NSTextView()
        bulletEditor.isRichText = true
        bulletEditor.string = "第一项\n第二项"
        bulletEditor.setSelectedRange(NSRange(location: 0, length: bulletEditor.string.utf16.count))
        RichTextFormatting.toggleBulletList(in: bulletEditor)
        let bulletsOn = bulletEditor.string == "• 第一项\n• 第二项"
        RichTextFormatting.toggleBulletList(in: bulletEditor)
        let bulletsOff = bulletEditor.string == "第一项\n第二项"
        let bulletSelectionPreserved = bulletEditor.selectedRange() == NSRange(location: 0, length: bulletEditor.string.utf16.count)

        let markdownEditor = NSTextView()
        markdownEditor.isRichText = true
        markdownEditor.font = NoteAppearance.bodyFont()
        markdownEditor.string = "**重点**和~~删除~~\n- 第一项\n* 第二项"
        markdownEditor.setSelectedRange(NSRange(location: markdownEditor.string.utf16.count, length: 0))
        let markdownChanged = RichTextFormatting.applyMarkdownSyntax(in: markdownEditor)
        let markdownFont = markdownEditor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let markdownBold = markdownFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false
        let markdownStrike = (markdownEditor.textStorage?.attribute(.strikethroughStyle, at: 3, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue
        let markdownBullets = markdownEditor.string == "重点和删除\n• 第一项\n• 第二项"

        let boldMarkdownEditor = NSTextView()
        boldMarkdownEditor.isRichText = true
        boldMarkdownEditor.font = NoteAppearance.bodyFont()
        boldMarkdownEditor.typingAttributes = [.font: NoteAppearance.bodyFont()]
        boldMarkdownEditor.string = "**重点**"
        boldMarkdownEditor.setSelectedRange(NSRange(location: boldMarkdownEditor.string.utf16.count, length: 0))
        _ = RichTextFormatting.applyMarkdownSyntax(in: boldMarkdownEditor)
        boldMarkdownEditor.insertText(" 后续", replacementRange: boldMarkdownEditor.selectedRange())
        let trailingFont = boldMarkdownEditor.textStorage?.attribute(.font, at: boldMarkdownEditor.string.utf16.count - 1, effectiveRange: nil) as? NSFont
        let trailingIsRegular = trailingFont.map { !NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false

        let emptyBulletEditor = NSTextView()
        emptyBulletEditor.isRichText = true
        emptyBulletEditor.string = "• "
        let listStyle = NSMutableParagraphStyle()
        listStyle.headIndent = 18
        emptyBulletEditor.textStorage?.addAttribute(.paragraphStyle, value: listStyle, range: NSRange(location: 0, length: 2))
        emptyBulletEditor.typingAttributes = [.font: NoteAppearance.bodyFont(), .paragraphStyle: listStyle]
        emptyBulletEditor.setSelectedRange(NSRange(location: 2, length: 0))
        let exitedEmptyBullet = RichTextFormatting.handleListNewline(in: emptyBulletEditor)
        let exitStyle = emptyBulletEditor.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        let listExitClean = exitedEmptyBullet && emptyBulletEditor.string.isEmpty && (exitStyle?.headIndent ?? 0) == 0

        let nestedBulletEditor = NSTextView()
        nestedBulletEditor.isRichText = true
        nestedBulletEditor.string = "• 父级\n• 子项一\n• 子项二"
        nestedBulletEditor.setSelectedRange(NSRange(location: 5, length: 11))
        let indented = RichTextFormatting.adjustBulletLevel(in: nestedBulletEditor, delta: 1)
        let firstNestedStyle = nestedBulletEditor.textStorage?.attribute(.paragraphStyle, at: 5, effectiveRange: nil) as? NSParagraphStyle
        let secondNestedStyle = nestedBulletEditor.textStorage?.attribute(.paragraphStyle, at: 11, effectiveRange: nil) as? NSParagraphStyle
        let multiLevelOn = indented
            && nestedBulletEditor.string == "• 父级\n∘ 子项一\n∘ 子项二"
            && firstNestedStyle?.firstLineHeadIndent == 18
            && firstNestedStyle?.headIndent == 36
            && secondNestedStyle?.firstLineHeadIndent == 18
            && secondNestedStyle?.headIndent == 36
        let nestedRoundTrip = RichTextCodec.encode(nestedBulletEditor.attributedString())
            .flatMap(RichTextCodec.decode)
        let restoredNestedStyle = nestedRoundTrip?.attribute(.paragraphStyle, at: 5, effectiveRange: nil) as? NSParagraphStyle
        let multiLevelSurvived = restoredNestedStyle?.firstLineHeadIndent == 18
            && restoredNestedStyle?.headIndent == 36
        let outdented = RichTextFormatting.adjustBulletLevel(in: nestedBulletEditor, delta: -1)
        let rootStyle = nestedBulletEditor.textStorage?.attribute(.paragraphStyle, at: 5, effectiveRange: nil) as? NSParagraphStyle
        let multiLevelOff = outdented && rootStyle?.firstLineHeadIndent == 0 && rootStyle?.headIndent == 18
            && nestedBulletEditor.string == "• 父级\n• 子项一\n• 子项二"

        let deepBulletEditor = NSTextView()
        deepBulletEditor.isRichText = true
        deepBulletEditor.string = "• 根\n• 一级\n• 二级\n• 三级"
        deepBulletEditor.setSelectedRange(NSRange(location: 6, length: 0))
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        deepBulletEditor.setSelectedRange(NSRange(location: 11, length: 0))
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        deepBulletEditor.setSelectedRange(NSRange(location: 16, length: 0))
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        let tieredMarkers = deepBulletEditor.string == "• 根\n∘ 一级\n▪ 二级\n▪ 三级"

        let inheritedMarkerEditor = NSTextView()
        inheritedMarkerEditor.isRichText = true
        inheritedMarkerEditor.string = "• 父级\n∘ 子项"
        let inheritedStyle = NSMutableParagraphStyle()
        inheritedStyle.firstLineHeadIndent = 18
        inheritedStyle.headIndent = 36
        inheritedMarkerEditor.textStorage?.addAttribute(.paragraphStyle, value: inheritedStyle, range: NSRange(location: 5, length: 4))
        inheritedMarkerEditor.typingAttributes = [.font: NoteAppearance.bodyFont(), .paragraphStyle: inheritedStyle]
        inheritedMarkerEditor.setSelectedRange(NSRange(location: inheritedMarkerEditor.string.utf16.count, length: 0))
        let insertedNestedLine = RichTextFormatting.handleListNewline(in: inheritedMarkerEditor)
        let inheritedMarker = insertedNestedLine && inheritedMarkerEditor.string.hasSuffix("\n∘ ")

        let legacyMarkerEditor = NSTextView()
        legacyMarkerEditor.isRichText = true
        legacyMarkerEditor.string = "• 父级\n◦ 小圆旧版\n○ 大圆旧版"
        legacyMarkerEditor.textStorage?.addAttribute(
            .paragraphStyle,
            value: inheritedStyle,
            range: NSRange(location: 5, length: legacyMarkerEditor.string.utf16.count - 5)
        )
        let normalizedLegacyMarker = RichTextFormatting.normalizeBulletMarkers(in: legacyMarkerEditor)
            && legacyMarkerEditor.string == "• 父级\n∘ 小圆旧版\n∘ 大圆旧版"

        let orphanBulletEditor = NSTextView()
        orphanBulletEditor.isRichText = true
        orphanBulletEditor.string = "• 首项"
        orphanBulletEditor.setSelectedRange(NSRange(location: 2, length: 0))
        let orphanPrevented = !RichTextFormatting.adjustBulletLevel(in: orphanBulletEditor, delta: 1)

        print("bold=\(boldSurvived) strike=\(strikeOn && strikeOff && strikeSurvived) bullet=\(bulletSurvived) futureBold=\(futureBoldOn && futureBoldOff) bulletToggle=\(bulletsOn && bulletsOff && bulletSelectionPreserved) markdown=\(markdownChanged && markdownBold && markdownStrike && markdownBullets && trailingIsRegular) listExit=\(listExitClean) nesting=\(multiLevelOn && multiLevelOff && multiLevelSurvived && orphanPrevented && tieredMarkers && inheritedMarker && normalizedLegacyMarker) markerProportions=\(markerProportionsAreBalanced) bytes=\(data.count)")
        guard boldSurvived, bulletSurvived, strikeSurvived, futureBoldOn, futureBoldOff, strikeOn, strikeOff, bulletsOn, bulletsOff, bulletSelectionPreserved, markdownChanged, markdownBold, markdownStrike, markdownBullets, trailingIsRegular, listExitClean, multiLevelOn, multiLevelOff, multiLevelSurvived, orphanPrevented, tieredMarkers, inheritedMarker, normalizedLegacyMarker, markerProportionsAreBalanced else { exit(1) }
    }
}
