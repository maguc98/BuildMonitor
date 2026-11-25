import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("项目", systemImage: "square.grid.2x2.fill") }
            NavigationStack { HistoryView() }
                .tabItem { Label("历史", systemImage: "clock") }
            NavigationStack { NotificationsView() }
                .tabItem { Label("通知", systemImage: "bell") }
            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Palette.blue)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 1),
                Color(red: 0.94, green: 0.95, blue: 1),
                Color(red: 0.96, green: 0.95, blue: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

extension View {
    func glassCard(_ radius: CGFloat = 22) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.06), radius: 16, x: 0, y: 7)
    }
}

struct AppMark: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.69, blue: 1), Palette.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "square.3.layers.3d.top.filled")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.blue.opacity(0.22), radius: 12, x: 0, y: 6)
    }
}

struct DemoNotice: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(Palette.blue)
            Text("演示数据 · GitHub 实时连接将在下一阶段接入")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Palette.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StatusPill: View {
    let status: BuildStatus
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.symbol).font(.system(size: 12, weight: .bold))
            Text(status.title).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(status.color.opacity(0.10), in: Capsule())
    }
}

struct DashboardView: View {
    private let projects = RepositoryProject.samples
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    DemoNotice()
                    LazyVGrid(columns: columns, spacing: 8) {
                        SummaryTile(value: "28", title: "成功", icon: "checkmark.circle.fill", tint: Palette.success)
                        SummaryTile(value: "3", title: "构建中", icon: "arrow.triangle.2.circlepath", tint: Palette.blue)
                        SummaryTile(value: "1", title: "排队中", icon: "hourglass", tint: Palette.purple)
                        SummaryTile(value: "4", title: "失败", icon: "xmark.circle.fill", tint: Palette.danger)
                    }
                    .padding(9)
                    .glassCard(25)
                    HStack {
                        Text("我的项目").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                        Text("6").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.secondary)
                        Spacer()
                        Image(systemName: "line.3.horizontal.decrease").foregroundStyle(Palette.ink)
                    }
                    VStack(spacing: 12) {
                        ForEach(projects) { project in
                            NavigationLink { RunDetailView(project: project) } label: {
                                ProjectCard(project: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 57)
            VStack(alignment: .leading, spacing: 3) {
                Text("Build Monitor").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                Text("GitHub 构建监控").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            Button {} label: {
                Image(systemName: "plus").font(.system(size: 21, weight: .medium)).foregroundStyle(Palette.ink).frame(width: 35, height: 42)
            }
            Menu {
                Button("刷新状态", systemImage: "arrow.clockwise") {}
                Button("排序项目", systemImage: "line.3.horizontal.decrease") {}
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.ink).frame(width: 30, height: 42)
            }
        }
    }
}

private struct SummaryTile: View {
    let value: String
    let title: String
    let icon: String
    let tint: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(tint).frame(height: 27)
            Text(value).font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct ProjectCard: View {
    let project: RepositoryProject

    private var tint: Color {
        switch project.initials {
        case "H": Color(red: 0.31, green: 0.52, blue: 0.98)
        case "L": Palette.purple
        case "M": Color(red: 0.27, green: 0.78, blue: 0.68)
        case "Y": Color(red: 0.96, green: 0.38, blue: 0.67)
        case "T": Color(red: 0.27, green: 0.68, blue: 0.95)
        default: Color(red: 0.45, green: 0.69, blue: 0.79)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Text(project.initials)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(LinearGradient(colors: [tint.opacity(0.72), tint], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.id.split(separator: "/").last.map(String.init) ?? project.id)
                        .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(project.id).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
                }
                Spacer(minLength: 2)
                StatusPill(status: project.status)
            }
            HStack {
                Text(project.workflow).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                Spacer()
                Text(project.updated).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            if project.status == .inProgress {
                ProgressView(value: project.progress).tint(Palette.blue)
            } else {
                HStack {
                    Text(project.detail).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.secondary)
                    Spacer()
                    if project.status == .failed {
                        Text("查看日志").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.blue)
                    }
                }
            }
        }
        .padding(14)
        .glassCard(21)
    }
}

struct HistoryView: View {
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("构建历史").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                    DemoNotice()
                    ForEach(RepositoryProject.samples) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(p.id).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(p.workflow + " · " + p.updated).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                            }
                            Spacer()
                            StatusPill(status: p.status)
                        }
                        .padding(14).glassCard(18)
                    }
                }.padding(18)
            }
        }
        .navigationTitle("历史").navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationsView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                Image(systemName: "bell.badge").font(.system(size: 42, weight: .light)).foregroundStyle(Palette.blue)
                Text("构建通知").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.ink)
                Text("接入 GitHub 后，这里会显示构建成功、失败和 IPA 产物通知。")
                    .font(.system(size: 14)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)
                DemoNotice().padding(.horizontal, 20)
            }
        }
        .navigationTitle("通知").navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    @State private var successNotice = true
    @State private var failureNotice = true
    @State private var interval = "实时"

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("设置").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 29)).frame(width: 43, height: 43).background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("GitHub 账户").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                            Text("尚未连接").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        Text("待接入").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.blue).padding(9).background(Palette.blue.opacity(0.09), in: Capsule())
                    }
                    .padding(15).glassCard(20)
                    VStack(spacing: 0) {
                        SettingRow(icon: "tray.full", title: "管理仓库", value: "6 个仓库")
                        Divider().padding(.leading, 48)
                        ToggleRow(icon: "bell.badge", title: "构建完成通知", value: $successNotice)
                        Divider().padding(.leading, 48)
                        ToggleRow(icon: "exclamationmark.bell", title: "构建失败通知", value: $failureNotice)
                        Divider().padding(.leading, 48)
                        HStack {
                            Label("刷新频率", systemImage: "arrow.clockwise").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                            Spacer()
                            Picker("刷新频率", selection: $interval) {
                                Text("实时").tag("实时")
                                Text("30 秒").tag("30 秒")
                                Text("1 分钟").tag("1 分钟")
                                Text("5 分钟").tag("5 分钟")
                            }.pickerStyle(.menu)
                        }.padding(14)
                        Divider().padding(.leading, 48)
                        SettingRow(icon: "paintbrush", title: "主题外观", value: "浅色")
                        Divider().padding(.leading, 48)
                        SettingRow(icon: "info.circle", title: "关于", value: "Build Monitor 1.0.0")
                    }.glassCard(21)
                    Text("GitHub Token 将保存在 iOS 钥匙串中，不会写入项目文件。账号授权和实时数据同步将在下一阶段实现。")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).padding(.horizontal, 4)
                }.padding(18)
            }
        }
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingRow: View {
    let icon: String
    let title: String
    let value: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Palette.blue).frame(width: 24)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            Spacer()
            Text(value).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }.padding(14)
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var value: Bool
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Palette.blue).frame(width: 24)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            Spacer()
            Toggle(title, isOn: $value).labelsHidden().tint(Palette.blue)
        }.padding(14)
    }
}
