import AppKit

enum NoteColor: String, Codable, CaseIterable {
    case yellow, blue, mint, pink

    var background: NSColor {
        switch self {
        case .yellow: return NSColor(srgbRed: 254 / 255, green: 244 / 255, blue: 156 / 255, alpha: 1)
        case .blue: return NSColor(srgbRed: 173 / 255, green: 244 / 255, blue: 1, alpha: 1)
        case .mint: return NSColor(srgbRed: 178 / 255, green: 1, blue: 161 / 255, alpha: 1)
        case .pink: return NSColor(srgbRed: 1, green: 199 / 255, blue: 199 / 255, alpha: 1)
        }
    }

    var swatch: NSColor {
        switch self {
        case .yellow: return NSColor(srgbRed: 253 / 255, green: 234 / 255, blue: 61 / 255, alpha: 1)
        case .blue: return NSColor(srgbRed: 137 / 255, green: 241 / 255, blue: 1, alpha: 1)
        case .mint: return NSColor(srgbRed: 131 / 255, green: 254 / 255, blue: 131 / 255, alpha: 1)
        case .pink: return NSColor(srgbRed: 1, green: 179 / 255, blue: 178 / 255, alpha: 1)
        }
    }

    var title: String {
        switch self {
        case .yellow: return "黄色"
        case .blue: return "蓝色"
        case .mint: return "绿色"
        case .pink: return "粉色"
        }
    }
}

struct WindowFrame: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ frame: NSRect) {
        x = frame.origin.x
        y = frame.origin.y
        width = frame.size.width
        height = frame.size.height
    }

    var rect: NSRect { NSRect(x: x, y: y, width: width, height: height) }
}

struct StickyNote: Codable, Identifiable {
    var id: UUID
    var text: String
    var richTextData: Data?
    var color: NoteColor
    var frame: WindowFrame
    var isPinned: Bool
    var isHidden: Bool
    var reminderDate: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static func fresh(index: Int = 0, frame: NSRect? = nil) -> StickyNote {
        let size = NoteAppearance.defaultSize
        let initialFrame: NSRect
        if let frame {
            initialFrame = frame
        } else {
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let offset = CGFloat((index % 6) * 26)
            let origin = NSPoint(
                x: screen.midX - size.width / 2 + offset,
                y: screen.midY - size.height / 2 - offset
            )
            initialFrame = NSRect(origin: origin, size: size)
        }
        return StickyNote(
            id: UUID(),
            text: "",
            richTextData: nil,
            color: NoteColor.allCases[index % NoteColor.allCases.count],
            frame: WindowFrame(initialFrame),
            isPinned: false,
            isHidden: false,
            reminderDate: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
