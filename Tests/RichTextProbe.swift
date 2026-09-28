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

        let todoEditor = NSTextView()
        todoEditor.isRichText = true
        todoEditor.string = "第一项\n第二项"
        todoEditor.setSelectedRange(NSRange(location: 0, length: todoEditor.string.utf16.count))
        RichTextFormatting.toggleTodo(in: todoEditor)
        let todoPending = todoEditor.string == "☐ 第一项\n☐ 第二项"
            && RichTextFormatting.todoState(in: todoEditor) == .pending
        RichTextFormatting.toggleTodo(in: todoEditor)
        let firstTaskTextRange = NSRange(location: 2, length: 3)
        let firstTaskStrike = (todoEditor.textStorage?.attribute(.strikethroughStyle, at: firstTaskTextRange.location, effectiveRange: nil) as? NSNumber)?.intValue
        let todoCompleted = todoEditor.string == "☑ 第一项\n☑ 第二项"
            && RichTextFormatting.todoState(in: todoEditor) == .completed
            && firstTaskStrike == NSUnderlineStyle.single.rawValue
            && todoEditor.textStorage?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil
        let completedRoundTrip = todoEditor.textStorage
            .flatMap(RichTextCodec.encode)
            .flatMap(RichTextCodec.decode)
        let todoSurvived = completedRoundTrip?.string == todoEditor.string
            && (completedRoundTrip?.attribute(.strikethroughStyle, at: firstTaskTextRange.location, effectiveRange: nil) as? NSNumber)?.intValue == NSUnderlineStyle.single.rawValue
        RichTextFormatting.toggleTodo(in: todoEditor)
        let todoRemoved = todoEditor.string == "第一项\n第二项"
            && RichTextFormatting.todoState(in: todoEditor) == .plain
            && todoEditor.textStorage?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil
        let todoSelectionPreserved = todoEditor.selectedRange() == NSRange(location: 0, length: todoEditor.string.utf16.count)

        let completedTodoNewlineEditor = NSTextView()
        completedTodoNewlineEditor.isRichText = true
        completedTodoNewlineEditor.string = "☑ 已完成"
        completedTodoNewlineEditor.textStorage?.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 2, length: 3)
        )
        completedTodoNewlineEditor.typingAttributes = [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        completedTodoNewlineEditor.setSelectedRange(NSRange(location: completedTodoNewlineEditor.string.utf16.count, length: 0))
        let continuedTodo = RichTextFormatting.handleStructuredNewline(in: completedTodoNewlineEditor)
        let completedTodoNewline = continuedTodo
            && completedTodoNewlineEditor.string == "☑ 已完成\n☐ "
            && completedTodoNewlineEditor.typingAttributes[.strikethroughStyle] == nil
            && completedTodoNewlineEditor.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) != nil
            && completedTodoNewlineEditor.textStorage?.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) == nil

        let splitCompletedTodoEditor = NSTextView()
        splitCompletedTodoEditor.isRichText = true
        splitCompletedTodoEditor.string = "☑ 前后"
        splitCompletedTodoEditor.textStorage?.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 2, length: 2)
        )
        splitCompletedTodoEditor.typingAttributes = [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        splitCompletedTodoEditor.setSelectedRange(NSRange(location: 3, length: 0))
        let splitTodo = RichTextFormatting.handleStructuredNewline(in: splitCompletedTodoEditor)
        let splitCompletedTodo = splitTodo
            && splitCompletedTodoEditor.string == "☑ 前\n☐ 后"
            && splitCompletedTodoEditor.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) != nil
            && splitCompletedTodoEditor.textStorage?.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) == nil

        let bulletEditor = NSTextView()
        bulletEditor.isRichText = true
        bulletEditor.string = "第一项\n第二项"
        bulletEditor.setSelectedRange(NSRange(location: 0, length: bulletEditor.string.utf16.count))
        RichTextFormatting.toggleBulletList(in: bulletEditor)
        let bulletsOn = bulletEditor.string == "• 第一项\n• 第二项"
        RichTextFormatting.toggleBulletList(in: bulletEditor)
        let bulletsOff = bulletEditor.string == "第一项\n第二项"
        let bulletSelectionPreserved = bulletEditor.selectedRange() == NSRange(location: 0, length: bulletEditor.string.utf16.count)

        let listModeEditor = NSTextView()
        listModeEditor.isRichText = true
        listModeEditor.string = "• 项目"
        listModeEditor.setSelectedRange(NSRange(location: listModeEditor.string.utf16.count, length: 0))
        RichTextFormatting.toggleTodo(in: listModeEditor)
        let bulletBecameTodo = listModeEditor.string == "☐ 项目"
            && RichTextFormatting.todoState(in: listModeEditor) == .pending
            && !RichTextFormatting.isBulletList(in: listModeEditor)
        RichTextFormatting.toggleBulletList(in: listModeEditor)
        let todoBecameBullet = listModeEditor.string == "• 项目"
            && RichTextFormatting.todoState(in: listModeEditor) == .plain
            && RichTextFormatting.isBulletList(in: listModeEditor)

        let markdownEditor = NSTextView()
        markdownEditor.isRichText = true
        markdownEditor.font = NoteAppearance.bodyFont()
        markdownEditor.string = "**重点**\n- 第一项\n* 第二项"
        markdownEditor.setSelectedRange(NSRange(location: markdownEditor.string.utf16.count, length: 0))
        let markdownChanged = RichTextFormatting.applyMarkdownSyntax(in: markdownEditor)
        let markdownFont = markdownEditor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let markdownBold = markdownFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false
        let markdownBullets = markdownEditor.string == "重点\n• 第一项\n• 第二项"

        let removedStrikeMarkdownEditor = NSTextView()
        removedStrikeMarkdownEditor.isRichText = true
        removedStrikeMarkdownEditor.string = "~~不再转换~~"
        removedStrikeMarkdownEditor.setSelectedRange(NSRange(location: removedStrikeMarkdownEditor.string.utf16.count, length: 0))
        let strikeMarkdownRemoved = !RichTextFormatting.applyMarkdownSyntax(in: removedStrikeMarkdownEditor)
            && removedStrikeMarkdownEditor.string == "~~不再转换~~"
            && removedStrikeMarkdownEditor.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) == nil

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
        let exitedEmptyBullet = RichTextFormatting.handleStructuredNewline(in: emptyBulletEditor)
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
        let insertedNestedLine = RichTextFormatting.handleStructuredNewline(in: inheritedMarkerEditor)
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

        print("bold=\(boldSurvived) legacyStrike=\(strikeSurvived) todo=\(todoPending && todoCompleted && todoRemoved && todoSurvived && todoSelectionPreserved && completedTodoNewline && splitCompletedTodo) bullet=\(bulletSurvived) futureBold=\(futureBoldOn && futureBoldOff) bulletToggle=\(bulletsOn && bulletsOff && bulletSelectionPreserved && bulletBecameTodo && todoBecameBullet) markdown=\(markdownChanged && markdownBold && markdownBullets && strikeMarkdownRemoved && trailingIsRegular) listExit=\(listExitClean) nesting=\(multiLevelOn && multiLevelOff && multiLevelSurvived && orphanPrevented && tieredMarkers && inheritedMarker && normalizedLegacyMarker) markerProportions=\(markerProportionsAreBalanced) bytes=\(data.count)")
        guard boldSurvived, bulletSurvived, strikeSurvived, futureBoldOn, futureBoldOff, todoPending, todoCompleted, todoRemoved, todoSurvived, todoSelectionPreserved, completedTodoNewline, splitCompletedTodo, bulletsOn, bulletsOff, bulletSelectionPreserved, bulletBecameTodo, todoBecameBullet, markdownChanged, markdownBold, markdownBullets, strikeMarkdownRemoved, trailingIsRegular, listExitClean, multiLevelOn, multiLevelOff, multiLevelSurvived, orphanPrevented, tieredMarkers, inheritedMarker, normalizedLegacyMarker, markerProportionsAreBalanced else { exit(1) }
    }
}
