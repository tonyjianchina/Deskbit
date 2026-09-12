import Foundation
import AppKit

/// 便签数据模型。字段与原始 Desktop Sticky 的 notes.json 完全一致，
/// 方便直接沿用/迁移已有数据文件。
struct Note: Codable, Identifiable {
    var id: String
    var content: String
    var color: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var pinned: Bool
    var hidden: Bool
    var completed: Bool
    /// 提醒时间（毫秒时间戳），nil 表示未设置提醒
    var reminderAt: Double?
    /// 提醒触发时间（毫秒时间戳），触发后记录
    var reminderFiredAt: Double?
    var createdAt: Double
    var updatedAt: Double

    /// 四种柔和配色（与原始应用一致）
    enum NoteColor: String, CaseIterable {
        case yellow
        case mint
        case blue
        case pink

        var displayName: String {
            switch self {
            case .yellow: return "黄色"
            case .mint:   return "薄荷绿"
            case .blue:   return "蓝色"
            case .pink:   return "粉色"
            }
        }

        /// 便签主体底色
        var background: NSColor {
            switch self {
            case .yellow: return NSColor(calibratedRed: 1.00, green: 0.955, blue: 0.60, alpha: 1.0)  // #FFF09A
            case .mint:   return NSColor(calibratedRed: 0.76, green: 0.95, blue: 0.82, alpha: 1.0)  // #C2F3D1
            case .blue:   return NSColor(calibratedRed: 0.78, green: 0.90, blue: 1.00, alpha: 1.0)  // #C7E6FF
            case .pink:   return NSColor(calibratedRed: 1.00, green: 0.83, blue: 0.87, alpha: 1.0)  // #FFD4DE
            }
        }

        /// 深色调的强调色（文字、图标）
        var accent: NSColor {
            switch self {
            case .yellow: return NSColor(calibratedRed: 0.45, green: 0.38, blue: 0.08, alpha: 1.0)
            case .mint:   return NSColor(calibratedRed: 0.10, green: 0.40, blue: 0.26, alpha: 1.0)
            case .blue:   return NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.50, alpha: 1.0)
            case .pink:   return NSColor(calibratedRed: 0.48, green: 0.18, blue: 0.28, alpha: 1.0)
            }
        }

        /// 顶栏半透明覆盖色
        var barTint: NSColor {
            return NSColor(calibratedWhite: 0.0, alpha: 0.06)
        }
    }

    var colorEnum: NoteColor {
        return NoteColor(rawValue: color) ?? .yellow
    }

    static func make(color: Note.NoteColor = .yellow) -> Note {
        let now = Date().timeIntervalSince1970 * 1000
        return Note(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            content: "",
            color: color.rawValue,
            x: 0, y: 0,
            width: 320, height: 260,
            pinned: false,
            hidden: false,
            completed: false,
            reminderAt: nil,
            reminderFiredAt: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

/// 存储文件整体结构
struct NotesFile: Codable {
    var notes: [Note]
}
