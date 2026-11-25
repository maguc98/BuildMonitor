import SwiftUI

struct RootTabView: View {
    @StateObject private var store = BuildMonitorStore()
    @State private var selectedTab = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("项目", systemImage: "square.grid.2x2.fill").symbolEffect(.bounce, value: selectedTab == 0 && !reduceMotion) }
                .tag(0)
            NavigationStack { HistoryView() }
                .tabItem { Label("历史", systemImage: "clock").symbolEffect(.bounce, value: selectedTab == 1 && !reduceMotion) }
                .tag(1)
            NavigationStack { NotificationsView() }
                .tabItem { Label("通知", systemImage: "bell").symbolEffect(.bounce, value: selectedTab == 2 && !reduceMotion) }
                .tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape").symbolEffect(.bounce, value: selectedTab == 3 && !reduceMotion) }
                .tag(3)
        }
        .buttonStyle(AppPressableButtonStyle())
        .sensoryFeedback(.selection, trigger: selectedTab)
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

private struct MotionAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || reduceMotion ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 6)
            .onAppear {
                guard !isVisible else { return }
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(.easeOut(duration: 0.22).delay(min(max(0, delay), 0.08))) {
                        isVisible = true
                    }
                }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced { isVisible = true }
            }
    }
}

struct AppPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.62),
                value: configuration.isPressed
            )
    }
}

extension View {
    func motionAppear(_ delay: Double = 0) -> some View {
        modifier(MotionAppearModifier(delay: delay))
    }

    func glassCard(_ radius: CGFloat = 22) -> some View {
        self
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.72), lineWidth: 0.8))
            .shadow(color: Palette.ink.opacity(0.035), radius: 7, x: 0, y: 3)
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

struct StatusGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationActive = false
    let status: BuildStatus
    var size: CGFloat = 14

    private var repeatingAnimation: Animation? {
        switch status {
        case .inProgress:
            return .linear(duration: 1.1).repeatForever(autoreverses: false)
        case .queued:
            return .easeInOut(duration: 0.72).repeatForever(autoreverses: true)
        case .failed:
            return .easeInOut(duration: 0.85).repeatForever(autoreverses: true)
        case .success:
            return nil
        }
    }

    var body: some View {
        glyph
            .foregroundStyle(status.color)
            .frame(width: size + 9, height: size + 9)
            .onAppear(perform: startAnimation)
            .onChange(of: status) { _, _ in startAnimation() }
            .onChange(of: reduceMotion) { _, _ in startAnimation() }
            .animation(repeatingAnimation, value: animationActive)
    }

    @ViewBuilder
    private var glyph: some View {
        switch status {
        case .inProgress:
            runningGlyph
        case .queued:
            queuedGlyph
        case .success:
            successGlyph
        case .failed:
            failedGlyph
        }
    }

    private var runningGlyph: some View {
        ZStack {
            Circle().stroke(status.color.opacity(0.18), lineWidth: 2)
            Circle()
                .trim(from: 0, to: 0.30)
                .stroke(status.color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(animationActive ? 360 : 0))
        }
        .frame(width: size + 7, height: size + 7)
    }

    private var queuedGlyph: some View {
        Image(systemName: status.symbol)
            .font(.system(size: size, weight: .bold))
            .rotationEffect(.degrees(animationActive ? 180 : 0))
            .frame(width: size + 7, height: size + 7)
    }

    private var successGlyph: some View {
        Image(systemName: status.symbol)
            .font(.system(size: size, weight: .bold))
            .symbolEffect(.bounce, value: status)
            .frame(width: size + 7, height: size + 7)
    }

    private var failedGlyph: some View {
        ZStack {
            Circle()
                .stroke(status.color.opacity(animationActive ? 0.34 : 0.12), lineWidth: 1.8)
                .scaleEffect(animationActive ? 1.12 : 0.84)
            Image(systemName: status.symbol)
                .font(.system(size: size, weight: .bold))
                .scaleEffect(animationActive ? 1.06 : 0.94)
        }
        .frame(width: size + 7, height: size + 7)
    }

    private func startAnimation() {
        let shouldAnimate = !reduceMotion && (status == .inProgress || status == .queued || status == .failed)
        animationActive = shouldAnimate
    }
}

struct StatusPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let status: BuildStatus
    var body: some View {
        HStack(spacing: 5) {
            StatusGlyph(status: status, size: 12)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showConnection = false
    @State private var showRepositoryManagement = false
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
                            SummaryTile(value: count(.success), title: "成功", icon: "checkmark.circle.fill", tint: Palette.success, status: .success)
                            SummaryTile(value: count(.inProgress), title: "构建中", icon: "arrow.triangle.2.circlepath", tint: Palette.blue, status: .inProgress)
                            SummaryTile(value: count(.queued), title: "排队中", icon: "hourglass", tint: Palette.purple, status: .queued)
                            SummaryTile(value: count(.failed), title: "失败", icon: "xmark.circle.fill", tint: Palette.danger, status: .failed)
                        }
                        .padding(9).glassCard(25).motionAppear(0.08)
                        HStack {
                            Text("我的项目").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                            Text("\(store.visibleRepositories.count)/\(store.repositories.count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
                            Spacer()
                            Button {
                                showRepositoryManagement = true
                            } label: {
                                Label("管理", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Palette.blue)
                            }
                            .sheet(isPresented: $showRepositoryManagement) {
                                RepositoryManagementView()
                                    .environmentObject(store)
                                    .presentationDetents([.medium, .large])
                                    .presentationDragIndicator(.visible)
                            }
                            if store.isLoading { ProgressView().tint(Palette.blue) }
                            else {
                                Button { Task { await store.refresh() } } label: {
                                    Image(systemName: "arrow.clockwise").foregroundStyle(Palette.ink)
                                }
                            }
                        }
                        if store.repositories.isEmpty && !store.isLoading {
                            ContentUnavailableView("没有仓库", systemImage: "tray", description: Text("检查 Token 是否具有 Metadata 读取权限。"))
                        } else if store.visibleRepositories.isEmpty {
                            VStack(spacing: 10) {
                                ContentUnavailableView("没有显示中的仓库", systemImage: "eye.slash", description: Text("当前仓库都已隐藏。你可以在仓库管理中重新显示。"))
                                Button("管理隐藏仓库") { showRepositoryManagement = true }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.blue)
                            }
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.visibleRepositories) { repository in
                                    RepositoryCard(
                                        repository: repository,
                                        run: store.latestRun(for: repository.fullName),
                                        activeRuns: store.activeRuns(for: repository.fullName),
                                        displayName: store.displayName(for: repository),
                                        note: store.note(for: repository)
                                    )
                                    .motionAppear(0)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.975)),
                                        removal: .opacity.combined(with: .scale(scale: 0.94))
                                    ))
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
                .motionAppear(0.02)
            }

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
        .frame(maxWidth: .infinity).padding(22).glassCard(24).motionAppear(0.08)
    }
}

private struct SummaryTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: String
    let title: String
    let icon: String
    let tint: Color
    let status: BuildStatus
    var body: some View {
        VStack(spacing: 8) {
            StatusGlyph(status: status, size: 21).frame(height: 27)
            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct RepositoryCard: View {
    let repository: GitHubRepository
    let run: WorkflowRun?
    let activeRuns: [WorkflowRun]
    let displayName: String
    let note: String
    private var tint: Color {
        let palette: [Color] = [Palette.blue, Palette.purple, Palette.success, .pink, .cyan, .orange]
        return palette[Int(UInt(bitPattern: repository.name.hashValue) % UInt(palette.count))]
    }

    @EnvironmentObject private var store: BuildMonitorStore
    @State private var showWorkflowPicker = false
    @State private var cancelingRunID: Int?
    @State private var actionMessage: String?

    var body: some View {
        VStack(spacing: 9) {
            Group {
                if let run {
                    NavigationLink { RunDetailView(repository: repository, run: run) } label: { cardBody }
                        .buttonStyle(AppPressableButtonStyle())
                } else { cardBody }
            }

            HStack(spacing: 9) {
                Button {
                    showWorkflowPicker = true
                } label: {
                    Label("启动构建", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Palette.blue.opacity(0.10), in: Capsule())
                        .foregroundStyle(Palette.blue)
                }
                if !activeRuns.isEmpty {
                    Menu {
                        ForEach(activeRuns) { activeRun in
                            Button(role: .destructive) {
                                Task { await cancel(activeRun) }
                            } label: {
                                Label("取消 #\(activeRun.runNumber) · \(activeRun.title)", systemImage: "stop.circle")
                            }
                            .disabled(cancelingRunID != nil)
                        }
                    } label: {
                        Label(cancelingRunID == nil ? "取消构建" : "正在取消", systemImage: "stop.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Palette.danger.opacity(0.09), in: Capsule())
                            .foregroundStyle(Palette.danger)
                    }
                    .disabled(cancelingRunID != nil)
                }
            }
            .padding(.horizontal, 5)
        }
        .sheet(isPresented: $showWorkflowPicker) {
            WorkflowLaunchSheet(repository: repository)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("构建操作", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("好", role: .cancel) { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
    }

    private func cancel(_ activeRun: WorkflowRun) async {
        cancelingRunID = activeRun.id
        do {
            try await store.cancelWorkflowRun(repository: repository.fullName, runID: activeRun.id)
            actionMessage = "已向 GitHub 发送取消请求。"
        } catch {
            actionMessage = error.localizedDescription
        }
        cancelingRunID = nil
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            repositoryHeader
            latestRunHeader
            runMetadata
            if activeRuns.count > 1 {
                activeRunsSection
            }
        }
        .padding(14)
        .glassCard(21)
    }

    private var repositoryHeader: some View {
        HStack(spacing: 11) {
            Text(String(displayName.prefix(1)).uppercased())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    LinearGradient(colors: [tint.opacity(0.72), tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 13)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(repository.fullName)
                    if repository.isPrivate { Image(systemName: "lock.fill") }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .lineLimit(1)
                if !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 2)
            if let run {
                StatusPill(status: run.buildStatus)
            } else {
                Text("暂无记录")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Palette.line.opacity(0.25), in: Capsule())
            }
        }
    }

    private var latestRunHeader: some View {
        HStack {
            Text(run?.title ?? "尚未发现 Actions 运行记录")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer()
            if let run {
                Text("#\(run.runNumber)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.secondary)
            }
        }
    }

    @ViewBuilder
    private var runMetadata: some View {
        if let run, run.status == "in_progress" {
            ProgressView().tint(Palette.blue)
        } else {
            HStack {
                if let run {
                    Text("\(run.headBranch) · \(run.shortSHA)")
                } else {
                    Text("默认分支：\(repository.defaultBranch)")
                }
                Spacer()
                Text(run.map { RelativeDateTimeFormatter.localized($0.updatedAt) } ?? RelativeDateTimeFormatter.localized(repository.updatedAt))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.secondary)
        }
    }

    private var activeGroupStatus: BuildStatus {
        activeRuns.contains { $0.status == "in_progress" } ? .inProgress : .queued
    }

    private var activeRunsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                StatusGlyph(status: activeGroupStatus, size: 11)
                Text("\(activeRuns.count) 个活动构建")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.blue)
            }
            ForEach(activeRuns) { activeRun in
                activeRunRow(activeRun)
            }
        }
    }

    private func activeRunRow(_ activeRun: WorkflowRun) -> some View {
        HStack(spacing: 8) {
            StatusGlyph(status: activeRun.buildStatus, size: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(activeRun.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("#\(activeRun.runNumber) · \(activeRun.headBranch) · \(activeRun.shortSHA)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            Text(activeRun.status == "in_progress" ? "运行中" : "排队中")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(activeRun.status == "in_progress" ? Palette.blue : Palette.purple)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

}


private struct WorkflowLaunchSheet: View {
    @EnvironmentObject private var store: BuildMonitorStore
    @Environment(\.dismiss) private var dismiss
    let repository: GitHubRepository
    @State private var workflows: [WorkflowDefinition] = []
    @State private var branch: String
    @State private var isLoading = true
    @State private var launchingWorkflowID: Int?
    @State private var errorMessage: String?

    init(repository: GitHubRepository) {
        self.repository = repository
        _branch = State(initialValue: repository.defaultBranch)
    }

    private var activeWorkflows: [WorkflowDefinition] {
        workflows.filter { $0.state == "active" }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView { sheetContent }
            }
            .navigationTitle("启动构建")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await loadWorkflows() }
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            repositoryIntro
            branchInput
            if let errorMessage { InfoNotice(text: errorMessage) }
            workflowChoices
            InfoNotice(text: "启动要求该工作流支持 workflow_dispatch，且 GitHub Token 具有 Actions 写入权限。")
        }
        .padding(18)
    }

    private var repositoryIntro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(repository.fullName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("选择要手动启动的 GitHub Actions 工作流。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.secondary)
        }
    }

    private var branchInput: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("目标分支")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ink)
            TextField("例如 main", text: $branch)
                .font(.system(size: 13, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    @ViewBuilder
    private var workflowChoices: some View {
        if isLoading {
            HStack(spacing: 9) {
                ProgressView().tint(Palette.blue)
                Text("正在读取工作流…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else if activeWorkflows.isEmpty {
            ContentUnavailableView(
                "没有可用的工作流",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text("请确认仓库中存在已启用的 GitHub Actions 工作流。")
            )
        } else {
            ForEach(activeWorkflows) { workflow in
                workflowRow(workflow)
            }
        }
    }

    private func workflowRow(_ workflow: WorkflowDefinition) -> some View {
        Button {
            Task { await launch(workflow) }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: launchingWorkflowID == workflow.id ? "hourglass" : "play.circle.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Palette.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(workflow.path)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if launchingWorkflowID == workflow.id {
                    ProgressView().tint(Palette.blue)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.secondary)
                }
            }
            .padding(13)
            .glassCard(16)
        }
        .disabled(launchingWorkflowID != nil || branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .buttonStyle(AppPressableButtonStyle())
    }

    private func loadWorkflows() async {
        isLoading = true
        do {
            workflows = try await store.availableWorkflows(repository: repository.fullName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func launch(_ workflow: WorkflowDefinition) async {
        let selectedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedBranch.isEmpty else { return }
        launchingWorkflowID = workflow.id
        errorMessage = nil
        do {
            try await store.startWorkflow(repository: repository.fullName, workflowID: workflow.id, ref: selectedBranch)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        launchingWorkflowID = nil
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


struct RepositoryManagementView: View {
    @EnvironmentObject private var store: BuildMonitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingHidden = false
    @State private var editingRepository: GitHubRepository?

    private var displayedRepositories: [GitHubRepository] {
        showingHidden ? store.hiddenRepositories : store.visibleRepositories
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("仓库管理")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Text("隐藏仓库只会从项目列表中移除，不会删除仓库，也不会停止同步。备注和自定义名称仅保存在这台 iPhone。")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.secondary)
                        Picker("仓库状态", selection: $showingHidden) {
                            Text("显示中 \(store.visibleRepositories.count)").tag(false)
                            Text("已隐藏 \(store.hiddenRepositories.count)").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if displayedRepositories.isEmpty {
                            ContentUnavailableView(
                                showingHidden ? "没有隐藏的仓库" : "暂无显示中的仓库",
                                systemImage: showingHidden ? "eye" : "tray",
                                description: Text(showingHidden ? "隐藏的仓库会显示在这里。" : "你可以在“已隐藏”中恢复仓库。")
                            )
                            .padding(.top, 24)
                        } else {
                            ForEach(displayedRepositories) { repository in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.displayName(for: repository))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Palette.ink)
                                            .lineLimit(1)
                                        Text(repository.fullName)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Palette.secondary)
                                            .lineLimit(1)
                                        if !store.note(for: repository).isEmpty {
                                            Text(store.note(for: repository))
                                                .font(.system(size: 11))
                                                .foregroundStyle(Palette.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 4)
                                    Button {
                                        editingRepository = repository
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Palette.blue)
                                            .frame(width: 34, height: 36)
                                    }
                                    .accessibilityLabel("编辑仓库名称和备注")
                                    Button {
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            store.setRepositoryHidden(repository, hidden: !showingHidden)
                                        }
                                    } label: {
                                        Image(systemName: showingHidden ? "eye" : "eye.slash")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(showingHidden ? Palette.success : Palette.secondary)
                                            .frame(width: 34, height: 36)
                                    }
                                    .accessibilityLabel(showingHidden ? "显示仓库" : "隐藏仓库")
                                }
                                .padding(13)
                                .glassCard(18)
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("仓库管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $editingRepository) { repository in
                RepositoryMetadataEditor(
                    repository: repository,
                    currentDisplayName: store.displayName(for: repository),
                    currentNote: store.note(for: repository)
                )
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct RepositoryMetadataEditor: View {
    let repository: GitHubRepository
    @EnvironmentObject private var store: BuildMonitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var note: String

    init(repository: GitHubRepository, currentDisplayName: String, currentNote: String) {
        self.repository = repository
        _displayName = State(initialValue: currentDisplayName)
        _note = State(initialValue: currentNote)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("显示名称")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            TextField("给这个仓库起个容易识别的名字", text: $displayName)
                                .font(.system(size: 14))
                                .padding(13)
                                .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 13))
                            Text("留空或填写原名，将恢复 GitHub 仓库名称。")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.secondary)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("仓库备注")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            TextEditor(text: $note)
                                .font(.system(size: 13))
                                .frame(minHeight: 112)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 13))
                            Text("例如：主项目、测试分支、个人工具或 IPA 自动构建。")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.secondary)
                        }
                        Text("GitHub 原始仓库：\(repository.fullName)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("编辑仓库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.updateRepositoryMetadata(repository, displayName: displayName, note: note)
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: BuildMonitorStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                                        Text(store.displayName(for: item.repository)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                                        Text(item.run.title + " · #\(item.run.runNumber)").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                        Text("\(item.run.headBranch) · \(item.run.shortSHA) · \(RelativeDateTimeFormatter.localized(item.run.updatedAt))").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                    }
                                    Spacer()
                                    StatusPill(status: item.run.buildStatus)
                                }.padding(14).glassCard(18)
                            }
                            .buttonStyle(AppPressableButtonStyle())
                            .motionAppear(0.025)
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
                }.padding(18).motionAppear()
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
            .motionAppear(0.04)
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
                    }.padding(15).glassCard(20).motionAppear(0.06)

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
                    }.glassCard(21).motionAppear(0.12)

                    Text("建议使用 Fine-grained personal access token，仅授予 Metadata: Read-only 和 Actions: Read-only，并只选择需要监控的仓库。Token 不会写入源码或 UserDefaults。")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).padding(.horizontal, 4)
                    if let error = store.errorMessage {
                        Text(error).font(.system(size: 12)).foregroundStyle(Palette.danger)
                    }
                }.padding(18).motionAppear()
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
        }.buttonStyle(AppPressableButtonStyle()).disabled(action == nil)
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
                    }.padding(20).motionAppear(0.04)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
            }
        }
    }
}
