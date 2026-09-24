import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var title: String {
        switch self {
        case .system: return L10n.text("language.system")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

/// Keeps interface language separate from note content and persisted note data.
enum L10n {
    static let preferenceKey = "DeskbitLanguage"

    static var preference: AppLanguage {
        get { AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey) }
    }

    static func resolve(_ preference: AppLanguage, preferredLanguages: [String]) -> AppLanguage {
        guard preference == .system else { return preference }
        for identifier in preferredLanguages {
            let language = identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first
            if language == "en" { return .english }
            if language == "zh" { return .simplifiedChinese }
        }
        return .english
    }

    static var language: AppLanguage { resolve(preference, preferredLanguages: Locale.preferredLanguages) }
    static var locale: Locale { Locale(identifier: language.rawValue) }

    static let resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
        // The packaged app carries the SwiftPM bundle beside its other resources.
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Deskbit_Deskbit.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
        #else
        // Standalone swiftc probes load the same resources as the application.
        return Bundle(path: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Resources").path)!
        #endif
    }()

    private static let bundles: [AppLanguage: Bundle] = {
        var result: [AppLanguage: Bundle] = [:]
        for language in [AppLanguage.english, .simplifiedChinese] {
            // SwiftPM lowercases lproj directory names when copying resources.
            let path = resourceBundle.path(forResource: language.rawValue, ofType: "lproj")
                ?? resourceBundle.path(forResource: language.rawValue.lowercased(), ofType: "lproj")
            if let path,
               let bundle = Bundle(path: path) { result[language] = bundle }
        }
        return result
    }()

    static func text(_ key: String) -> String {
        let fallback = bundles[.english]?.localizedString(forKey: key, value: key, table: nil) ?? key
        return bundles[language]?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    static func noteCount(_ count: Int) -> String {
        format(count == 1 ? "history.count.one" : "history.count.other", count)
    }
}
