import SwiftUI

enum BuildStatus: String, Identifiable {
    case success, inProgress, queued, failed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .success: "构建成功"
        case .inProgress: "构建中"
        case .queued: "排队中"
        case .failed: "构建失败"
        }
    }
    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .queued: "hourglass"
        case .failed: "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .success: Palette.success
        case .inProgress: Palette.blue
        case .queued: Palette.purple
        case .failed: Palette.danger
        }
    }
}

struct RepositoryProject: Identifiable {
    let id: String
    let initials: String
    let status: BuildStatus
    let workflow: String
    let updated: String
    let detail: String
    let progress: Double
    let artifact: String?

    static let samples: [RepositoryProject] = [
        .init(id: "maguc98/hex", initials: "H", status: .inProgress, workflow: "Build iOS (unsigned)", updated: "12 分钟前", detail: "正在编译 iOS 应用", progress: 0.62, artifact: nil),
        .init(id: "maguc98/LiveContainer-2.0", initials: "L", status: .success, workflow: "Build iOS", updated: "8 分钟前", detail: "IPA 已生成 · 32.4 MB", progress: 1, artifact: "LiveContainer-unsigned.ipa"),
        .init(id: "maguc98/MiniWatts", initials: "M", status: .failed, workflow: "Build App", updated: "21 分钟前", detail: "编译错误 · 查看日志", progress: 0.48, artifact: nil),
        .init(id: "maguc98/Yiu.fm-Aether", initials: "Y", status: .queued, workflow: "iOS Build", updated: "刚刚", detail: "等待 Runner 分配", progress: 0, artifact: nil),
        .init(id: "maguc98/text-display-ios", initials: "T", status: .success, workflow: "Build iOS", updated: "34 分钟前", detail: "IPA 已生成 · 18.7 MB", progress: 1, artifact: "TextDisplay-unsigned.ipa"),
        .init(id: "maguc98/Folia-Plain", initials: "F", status: .success, workflow: "Verify", updated: "1 小时前", detail: "检查通过", progress: 1, artifact: nil)
    ]
}

enum StepState: Equatable {
    case complete, active, waiting, failed
    var color: Color {
        switch self {
        case .complete: Palette.success
        case .active: Palette.blue
        case .waiting: Palette.line
        case .failed: Palette.danger
        }
    }
    var symbol: String {
        switch self {
        case .complete: "checkmark"
        case .active: "arrow.triangle.2.circlepath"
        case .waiting: "circle"
        case .failed: "xmark"
        }
    }
}

struct BuildStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: StepState
    static let sample: [BuildStep] = [
        .init(title: "Checkout repository", detail: "完成 · 8 秒", state: .complete),
        .init(title: "Set up Xcode", detail: "完成 · 46 秒", state: .complete),
        .init(title: "Install dependencies", detail: "完成 · 1 分 12 秒", state: .complete),
        .init(title: "Build App", detail: "运行中 · 6 分 24 秒", state: .active),
        .init(title: "Archive IPA", detail: "等待中", state: .waiting),
        .init(title: "Upload artifact", detail: "等待中", state: .waiting)
    ]
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
