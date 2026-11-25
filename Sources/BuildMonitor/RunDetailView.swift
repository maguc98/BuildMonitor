import SwiftUI

private enum DetailTab: String, CaseIterable {
    case progress = "构建进度"
    case logs = "日志"
    case artifacts = "产物"
}

struct RunDetailView: View {
    let project: RepositoryProject
    @State private var tab: DetailTab = .progress

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    HStack(spacing: 10) {
                        AppMark(size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.id.split(separator: "/").last.map(String.init) ?? project.id)
                                .font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                            Text(project.id).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("在 GitHub 打开", systemImage: "arrow.up.right") {}
                            Button("刷新状态", systemImage: "arrow.clockwise") {}
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.ink)
                        }
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 22, weight: .semibold)).frame(width: 45, height: 45)
                            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(project.workflow).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                            Text(project.status == .inProgress ? "运行中 · 第 4/6 步" : project.status.title)
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(project.status.color)
                        }
                        Spacer()
                        if project.status == .inProgress {
                            ProgressView().tint(Palette.blue)
                        } else {
                            Image(systemName: project.status.symbol).font(.system(size: 24)).foregroundStyle(project.status.color)
                        }
                    }
                    .padding(15)
                    .background(LinearGradient(colors: [.white.opacity(0.95), Palette.blue.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 21))
                    .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white, lineWidth: 1))
                    HStack(spacing: 8) {
                        MetaChip(icon: "arrow.triangle.branch", text: "main")
                        MetaChip(icon: "number", text: "a3f7e9b")
                        MetaChip(icon: "clock", text: project.updated)
                    }
                    Picker("详情", selection: $tab) {
                        ForEach(DetailTab.allCases, id: \.self) { item in Text(item.rawValue).tag(item) }
                    }.pickerStyle(.segmented)

                    switch tab {
                    case .progress: progressList
                    case .logs: logPanel
                    case .artifacts: artifactPanel
                    }
                }.padding(18).padding(.bottom, 30)
            }
        }
        .navigationTitle("构建详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressList: some View {
        VStack(spacing: 0) {
            ForEach(Array(BuildStep.sample.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(step.state.color).frame(width: 24, height: 24)
                            Image(systemName: step.state.symbol).font(.system(size: 11, weight: .bold))
                                .foregroundStyle(step.state == .waiting ? Palette.secondary : .white)
                        }
                        if index < BuildStep.sample.count - 1 {
                            Rectangle().fill(step.state == .complete ? Palette.success.opacity(0.4) : Palette.line.opacity(0.6)).frame(width: 2, height: 47)
                        }
                    }.frame(width: 24)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(step.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text(step.detail).font(.system(size: 11, weight: .medium)).foregroundStyle(step.state == .active ? Palette.blue : Palette.secondary)
                    }
                    .padding(.top, 2)
                    Spacer()
                    if step.state == .active { ProgressView().tint(Palette.blue) }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, step.state == .active ? 9 : 0)
                .background(step.state == .active ? Palette.blue.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 13))
            }
        }
        .padding(14).glassCard(22)
        .overlay(alignment: .bottom) {
            if project.status == .inProgress {
                HStack {
                    Image(systemName: "stopwatch").font(.system(size: 22)).foregroundStyle(Palette.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("预计剩余时间").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        Text("约 3–5 分钟").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Image(systemName: "waveform.path").font(.system(size: 25)).foregroundStyle(Palette.purple.opacity(0.6))
                }
                .padding(15).glassCard(20).offset(y: 80)
            }
        }
        .padding(.bottom, project.status == .inProgress ? 80 : 0)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(.red).frame(width: 8, height: 8)
                Circle().fill(.yellow).frame(width: 8, height: 8)
                Circle().fill(.green).frame(width: 8, height: 8)
                Spacer()
                Text("示例构建日志").font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
            }.padding(.bottom, 8)
            ForEach(Array([
                "[19:12:04] Run build",
                "[19:12:05] xcodebuild -workspace",
                "[19:12:07] Resolve Swift packages",
                "[19:12:11] Compile Sources",
                "[19:14:28] Linking...",
                "[19:17:03] Processing...",
                "[19:18:26] Build Succeeded ✓",
                "[19:18:27] Archiving...",
                "[19:18:31] Uploading artifact..."
            ].enumerated()), id: \.offset) { index, line in
                Text(String(format: "%02d  %@", index + 1, line))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(line.contains("Succeeded") ? Color.green : Color.white.opacity(0.85))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        .background(Color(red: 0.11, green: 0.13, blue: 0.19), in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .bottom) {
            Text("连接 GitHub 后将显示实时日志").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)).padding(.bottom, 10)
        }
    }

    private var artifactPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let file = project.artifact {
                HStack(spacing: 12) {
                    Image(systemName: "doc.zipper").font(.system(size: 25)).foregroundStyle(Palette.blue)
                        .frame(width: 48, height: 48).background(Palette.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text("示例产物 · 尚未从 GitHub 下载").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.down.circle").foregroundStyle(Palette.blue)
                }.padding(14).glassCard(18)
            } else {
                ContentUnavailableView("暂无构建产物", systemImage: "shippingbox", description: Text("构建完成并上传 Actions Artifact 后，IPA 会显示在这里。"))
            }
            DemoNotice()
        }
    }
}

private struct MetaChip: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(Palette.secondary)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.white.opacity(0.58), in: Capsule())
    }
}
