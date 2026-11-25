import SwiftUI

enum BuildStatus: String, Identifiable {
    case success, inProgress, queued, failed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .success: return "构建成功"
        case .inProgress: return "构建中"
        case .queued: return "排队中"
        case .failed: return "构建失败"
        }
    }
    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .queued: return "hourglass"
        case .failed: return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .success: return Palette.success
        case .inProgress: return Palette.blue
        case .queued: return Palette.purple
        case .failed: return Palette.danger
        }
    }
}

enum Palette {
    static let canvas = Color(red: 0.955, green: 0.955, blue: 0.995)
    static let blue = Color(red: 0.16, green: 0.49, blue: 0.96)
    static let purple = Color(red: 0.52, green: 0.34, blue: 0.90)
    static let success = Color(red: 0.15, green: 0.70, blue: 0.39)
    static let danger = Color(red: 0.91, green: 0.25, blue: 0.30)
    static let ink = Color(red: 0.12, green: 0.15, blue: 0.23)
    static let secondary = Color(red: 0.39, green: 0.42, blue: 0.52)
    static let line = Color(red: 0.80, green: 0.82, blue: 0.89)
}
