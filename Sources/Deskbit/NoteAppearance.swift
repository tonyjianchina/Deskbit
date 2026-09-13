import AppKit

enum NoteAppearance {
    static let defaultSize = NSSize(width: 300, height: 200)
    static let minimumSize = NSSize(width: 280, height: 160)
    static let bodyFontSize: CGFloat = 13

    static func bodyFont(weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: bodyFontSize, weight: weight)
    }
}
