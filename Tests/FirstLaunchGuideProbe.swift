import Foundation

@main
struct FirstLaunchGuideProbe {
    static func main() {
        let language = CommandLine.arguments.dropFirst().first
        let guide = FirstLaunchGuide.text

        switch language {
        case "en":
            precondition(guide.contains("Welcome to Deskbit"))
            precondition(guide.contains("⌘N"))
            precondition(guide.contains("Note History"))
            precondition(guide.contains("Send Feedback"))
        case "zh-Hans":
            precondition(guide.contains("欢迎使用 Deskbit"))
            precondition(guide.contains("⌘N"))
            precondition(guide.contains("历史便签"))
            precondition(guide.contains("用户反馈"))
        default:
            preconditionFailure("Expected en or zh-Hans")
        }

        print("first-launch guide (\(language!)): pass")
    }
}
