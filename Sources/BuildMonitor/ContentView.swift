import SwiftUI

struct RootTabView: View {
    @StateObject private var store = BuildMonitorStore()
    @Environment(\.scenePhase) private var scenePhase
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
        .environmentObject(store)
        .task {
            await store.restoreSession()
            if scenePhase == .active { store.startPolling() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await store.refresh()
                    store.startPolling()
                }
            } else {
                store.stopPolling()
                BackgroundRefreshScheduler.schedule()
            }
        }
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
        ).ignoresSafeArea()
    }
}

extension View {
    func motionAppear(_ delay: Double = 0) -> some View {
        self.transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .scale(scale: 0.98))))
            .animation(.spring(response: 0.48, dampingFraction: 0.78).delay(delay), value: UUID())
    }

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

struct InfoNotice: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(Palette.blue)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Palette.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: BuildMonitorStore
    @State private var showConnection = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private var recentRuns: [RepositoryRun] { store.allRecentRuns }
    private func count(_ status: BuildStatus) -> String {
        String(recentRuns.filter { $0.run.buildStatus == status }.count)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if !store.isConnected {
                        connectPrompt
                    } else {
                        if let error = store.errorMessage { InfoNotice(text: error) }
                        LazyVGrid(columns: columns, spacing: 8) {
                            SummaryTile(value: count(.success), title: "成功", icon: "checkmark.circle.fill", tint: Palette.success)
                            SummaryTile(value: count(.inProgress), title: "构建中", icon: "arrow.triangle.2.circlepath", tint: Palette.blue)
                            SummaryTile(value: count(.queued), title: "排队中", icon: "hourglass", tint: Palette.purple)
                            SummaryTile(value: count(.failed), title: "失败", icon: "xmark.circle.fill", tint: Palette.danger)
                        }
                        .padding(9).glassCard(25)
                        HStack {
                            Text("我的项目").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                            Text("\(store.repositories.count)").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.secondary)
                            Spacer()
                            if store.isLoading { ProgressView().tint(Palette.blue) }
                            else {
                                Button { Task { await store.refresh() } } label: {
                                    Image(systemName: "arrow.clockwise").foregroundStyle(Palette.ink)
                                }
                            }
                        }
                        if store.repositories.isEmpty && !store.isLoading {
                            ContentUnavailableView("没有仓库", systemImage: "tray", description: Text("检查 Token 是否具有 Metadata 读取权限。"))
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.repositories) { repository in
                                    RepositoryCard(repository: repository, run: store.latestRun(for: repository.fullName))
                                }
                            }
                        }
                        if let refreshed = store.lastRefreshed {
                            Text("最后同步：\(refreshed.formatted(date: .omitted, time: .shortened)) · 最近同步前 40 个仓库的 Actions")
                                .font(.system(size: 10)).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 28)
            }
            .refreshable { await store.refresh() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showConnection) {
            TokenConnectionView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 57)
            VStack(alignment: .leading, spacing: 3) {
                Text("Build Monitor").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                Text("GitHub 构建监控").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            Button { showConnection = true } label: {
                Image(systemName: "plus").font(.system(size: 21, weight: .medium)).foregroundStyle(Palette.ink).frame(width: 35, height: 42)
            }
            Menu {
                Button("刷新状态", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                Button("连接 GitHub", systemImage: "person.crop.circle.badge.plus") { showConnection = true }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.ink).frame(width: 30, height: 42)
            }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 42, weight: .light)).foregroundStyle(Palette.blue)
            Text("连接 GitHub 开始监控").font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
            Text("授权后自动读取你有权限访问的仓库和 Actions 构建记录。Token 只保存在这台 iPhone 的钥匙串中。")
                .font(.system(size: 13)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            Button { showConnection = true } label: {
                Label("连接 GitHub", systemImage: "link")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12).background(Palette.blue, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity).padding(22).glassCard(24)
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
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct RepositoryCard: View {
    let repository: GitHubRepository
    let run: WorkflowRun?
    private var tint: Color {
        let palette: [Color] = [Palette.blue, Palette.purple, Palette.success, .pink, .cyan, .orange]
        return palette[Int(UInt(bitPattern: repository.name.hashValue) % UInt(palette.count))]
    }

    var body: some View {
        Group {
            if let run {
                NavigationLink { RunDetailView(repository: repository, run: run) } label: { cardBody }
                    .buttonStyle(.plain)
            } else { cardBody }
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Text(String(repository.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(LinearGradient(colors: [tint.opacity(0.72), tint], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(repository.name).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink).lineLimit(1)
                    HStack(spacing: 5) {
                        Text(repository.fullName)
                        if repository.isPrivate { Image(systemName: "lock.fill") }
                    }.font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
                }
                Spacer(minLength: 2)
                if let run { StatusPill(status: run.buildStatus) }
                else {
                    Text("暂无记录").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 9).padding(.vertical, 7).background(Palette.line.opacity(0.25), in: Capsule())
                }
            }
            HStack {
                Text(run?.title ?? "尚未发现 Actions 运行记录").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                Spacer()
                if let run { Text("#\(run.runNumber)").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary) }
            }
            if let run, run.status == "in_progress" {
                ProgressView().tint(Palette.blue)
            } else {
                HStack {
                    if let run { Text("\(run.headBranch) · \(run.shortSHA)") }
                    else { Text("默认分支：\(repository.defaultBranch)") }
                    Spacer()
                    Text(run.map { RelativeDateTimeFormatter.localized($0.updatedAt) } ?? RelativeDateTimeFormatter.localized(repository.updatedAt))
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
            }
        }
        .padding(14).glassCard(21)
    }
}

extension RelativeDateTimeFormatter {
    static func localized(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        let relative = RelativeDateTimeFormatter()
        relative.locale = Locale(identifier: "zh_CN")
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: BuildMonitorStore
    @State private var showRestore = false
    @State private var deletingID: String?
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("构建历史").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                        Spacer()
                        if !store.hiddenRunIDs.isEmpty {
                            Button("恢复隐藏记录") { store.restoreHiddenHistory() }
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.blue)
                        }
                    }
                    if !store.isConnected {
                        Text("连接 GitHub 后，这里会显示各仓库最近的 Actions 运行记录。")
                            .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    } else if store.allRecentRuns.isEmpty {
                        ContentUnavailableView("暂无构建记录", systemImage: "clock", description: Text("仓库还没有可读取的 Actions 运行记录，或记录已被隐藏。"))
                    } else {
                        ForEach(store.allRecentRuns) { item in
                            NavigationLink { RunDetailView(repository: item.repository, run: item.run) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.repository.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                                        Text(item.run.title + " · #\\(item.run.runNumber)").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                        Text("\\(item.run.headBranch) · \\(item.run.shortSHA) · \\(RelativeDateTimeFormatter.localized(item.run.updatedAt))").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                    }
                                    Spacer()
                                    StatusPill(status: item.run.buildStatus)
                                }.padding(14).glassCard(18)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { store.hideHistoryRecord(item) } } label: {
                                    Label("删除此记录", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { store.hideHistoryRecord(item) } } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.96)), removal: .opacity.combined(with: .scale(scale: 0.88))))
                        }
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
                Text("开启设置中的构建通知后，状态变化会发送本地通知。App 前台每 60 秒同步；后台刷新由 iOS 按系统策略择机执行。")
                    .font(.system(size: 14)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)
            }
        }
        .navigationTitle("通知").navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: BuildMonitorStore
    @State private var showConnection = false
    @AppStorage("buildNotifications.enabled") private var notificationsEnabled = false
    @AppStorage("buildNotifications.success") private var successNotifications = true
    @AppStorage("buildNotifications.failure") private var failureNotifications = true
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
                            Text(store.username.map { "@\($0)" } ?? "尚未连接").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        Button(store.isConnected ? "断开" : "连接") {
                            if store.isConnected { store.disconnect() } else { showConnection = true }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(store.isConnected ? Palette.danger : Palette.blue)
                    }.padding(15).glassCard(20)

                    VStack(spacing: 0) {
                        SettingsRow(icon: "tray.full", title: "管理仓库", value: "\(store.repositories.count) 个仓库")
                        Divider().padding(.leading, 48)
                        SettingsRow(icon: "checkmark.shield", title: "Token 存储", value: "iOS 钥匙串")
                        Divider().padding(.leading, 48)
                        NotificationToggleRow(icon: "bell.badge", title: "构建状态通知", value: $notificationsEnabled)
                        if notificationsEnabled {
                            Divider().padding(.leading, 48)
                            NotificationToggleRow(icon: "checkmark.circle", title: "构建成功通知", value: $successNotifications)
                            Divider().padding(.leading, 48)
                            NotificationToggleRow(icon: "xmark.circle", title: "构建失败通知", value: $failureNotifications)
                        }
                        Divider().padding(.leading, 48)
                        SettingsRow(icon: "arrow.clockwise", title: "手动同步", value: store.isLoading ? "同步中…" : "立即刷新", action: { Task { await store.refresh() } })
                        Divider().padding(.leading, 48)
                        SettingsRow(icon: "paintbrush", title: "主题外观", value: "浅色")
                        Divider().padding(.leading, 48)
                        SettingsRow(icon: "info.circle", title: "关于", value: "Build Monitor 1.0.0")
                    }.glassCard(21)

                    Text("建议使用 Fine-grained personal access token，仅授予 Metadata: Read-only 和 Actions: Read-only，并只选择需要监控的仓库。Token 不会写入源码或 UserDefaults。")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).padding(.horizontal, 4)
                    if let error = store.errorMessage {
                        Text(error).font(.system(size: 12)).foregroundStyle(Palette.danger)
                    }
                }.padding(18)
            }
        }
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
        .onChange(of: notificationsEnabled) { _, enabled in
            if enabled {
                Task {
                    let granted = await BuildNotificationManager.requestAuthorization()
                    if !granted {
                        notificationsEnabled = false
                    } else {
                        BackgroundRefreshScheduler.schedule()
                    }
                }
            }
        }
        .onChange(of: successNotifications) { _, _ in
            BackgroundRefreshScheduler.schedule()
        }
        .onChange(of: failureNotifications) { _, _ in
            BackgroundRefreshScheduler.schedule()
        }
        .sheet(isPresented: $showConnection) {
            TokenConnectionView().environmentObject(store)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }
}

private struct NotificationToggleRow: View {
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

private struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    var action: (() -> Void)? = nil
    var body: some View {
        Button { action?() } label: {
            HStack {
                Image(systemName: icon).foregroundStyle(Palette.blue).frame(width: 24)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                Text(value).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                if action != nil { Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Palette.secondary) }
            }.padding(14)
        }.buttonStyle(.plain).disabled(action == nil)
    }
}

struct TokenConnectionView: View {
    @EnvironmentObject private var store: BuildMonitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("连接 GitHub").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                        Text("粘贴一个 Fine-grained personal access token。它只会保存在这台 iPhone 的钥匙串中。")
                            .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                        SecureField("github_pat_…", text: $token)
                            .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(14).background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 7) {
                            Text("所需最小权限").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
                            Text("• Repository access：选择需要监控的仓库")
                            Text("• Metadata：Read-only")
                            Text("• Actions：Read-only")
                        }
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).padding(14).glassCard(16)
                        Link(destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!) {
                            Label("创建 Fine-grained Token", systemImage: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                        }.foregroundStyle(Palette.blue)
                        if let errorMessage { Text(errorMessage).font(.system(size: 12)).foregroundStyle(Palette.danger) }
                        Button {
                            Task {
                                isConnecting = true
                                errorMessage = nil
                                do {
                                    try await store.connect(token: token)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isConnecting = false
                            }
                        } label: {
                            HStack {
                                if isConnecting { ProgressView().tint(.white) }
                                Text(isConnecting ? "正在验证…" : "验证并连接").font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(token.isEmpty || isConnecting ? Palette.blue.opacity(0.45) : Palette.blue, in: Capsule())
                        }.disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
                    }.padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
            }
        }
    }
}
