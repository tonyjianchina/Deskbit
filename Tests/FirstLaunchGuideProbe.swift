import AppKit

@main
struct FirstLaunchGuideProbe {
    static func main() {
        let language = CommandLine.arguments.dropFirst().first
        let guide = FirstLaunchGuide.text
        let attributedGuide = FirstLaunchGuide.attributedText

        switch language {
        case "en":
            precondition(guide == """
            Welcome to Deskbit 👋

            Shortcuts
            ⌘N New Note
            ⌘B  Bold
            Tab / Shift+Tab  Change bullet level

            Arrange Notes
            Click the top-left button to neatly arrange multiple notes.

            View Note History
            Click ✓ to complete a note, then choose Note History from the menu bar Deskbit icon. You can restore or permanently delete completed notes.

            Report a Problem
            Choose Send Feedback from the menu bar Deskbit icon, enter the details, and send.
            """)
            verifyBold(in: attributedGuide, expected: ["Shortcuts", "Arrange Notes", "View Note History", "Report a Problem"])
            verifyRegular(in: attributedGuide, expected: ["Welcome to", "Deskbit", "⌘N", "New Note", "Bold", "Change bullet level"])
        case "zh-Hans":
            precondition(guide == """
            欢迎使用 Deskbit 👋

            快捷键
            ⌘N 新建便签
            ⌘B  加粗
            Tab / Shift+Tab  调整项目符号层级

            自动排列
            点击左上角按钮，自动将多个便签排列整齐

            查看历史便签
            点击 ✓ 完成便签，再点击菜单栏 Deskbit 图标 → 历史便签；可恢复或永久删除已完成的便签。

            反馈问题
            点击菜单栏 Deskbit 图标 → 用户反馈，填写内容后发送。
            """)
            verifyBold(in: attributedGuide, expected: ["快捷键", "自动排列", "查看历史便签", "反馈问题"])
            verifyRegular(in: attributedGuide, expected: ["欢迎使用", "Deskbit", "⌘N", "新建便签", "加粗", "调整项目符号层级"])
        default:
            preconditionFailure("Expected en or zh-Hans")
        }

        precondition(!guide.contains("**"))
        precondition(attributedGuide.string == guide)
        print("first-launch guide (\(language!)): pass")
    }

    private static func verifyBold(in guide: NSAttributedString, expected strings: [String]) {
        for string in strings {
            let range = (guide.string as NSString).range(of: string)
            precondition(range.location != NSNotFound)
            let font = guide.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            precondition(font.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true, string)
        }
    }

    private static func verifyRegular(in guide: NSAttributedString, expected strings: [String]) {
        for string in strings {
            let range = (guide.string as NSString).range(of: string)
            precondition(range.location != NSNotFound)
            let font = guide.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            precondition(font.map { !NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true, string)
        }
    }
}
