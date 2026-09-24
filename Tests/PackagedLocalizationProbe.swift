import Foundation

// A packaged app must work without access to the checkout or SwiftPM build directory.
extension Bundle {
    static var module: Bundle { fatalError("Packaged app fell back to build resources") }
}

@main
struct PackagedLocalizationProbe {
    static func main() {
        precondition(L10n.resourceBundle.bundleURL.path.hasPrefix(Bundle.main.bundleURL.path))
        precondition(L10n.text("menu.newNote") == (L10n.language == .english ? "New Note" : "新建便签"))
        precondition(!L10n.text("feedback.status.submitted").hasPrefix("feedback."))
        print("packaged localization: \(L10n.language.rawValue) pass, resources loaded inside app")
    }
}
