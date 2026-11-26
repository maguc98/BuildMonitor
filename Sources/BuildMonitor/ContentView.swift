import SwiftUI

struct RootTabView: View {
    @StateObject private var store = BuildMonitorStore()
    @State private var selectedTab = 0
    @Namespace private var tabSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let tabTitles = ["项目", "历史", "通知", "设置"]
    private let tabIcons = ["square.grid.2x2.fill", "clock", "bell", "gearshape"]

    var body: some View {
        ZStack {
            ZStack {
                NavigationStack { DashboardView() }
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .offset(x: pageOffset(for: 0))
                    .zIndex(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)
                    .accessibilityHidden(selectedTab != 0)

                NavigationStack { HistoryView() }
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .offset(x: pageOffset(for: 1))
                    .zIndex(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
                    .accessibilityHidden(selectedTab != 1)

                NavigationStack { NotificationsView() }
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .offset(x: pageOffset(for: 2))
                    .zIndex(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)
                    .accessibilityHidden(selectedTab != 2)

                NavigationStack { SettingsView() }
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .offset(x: pageOffset(for: 3))
                    .zIndex(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)
                    .accessibilityHidden(selectedTab != 3)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: selectedTab)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .buttonStyle(AppPressableButtonStyle())
        .sensoryFeedback(.selection, trigger: selectedTab)
        .tint(Palette.blue)
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

    private func pageOffset(for index: Int) -> CGFloat {
        guard selectedTab != index else { return 0 }
        return index > selectedTab ? 18 : -18
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabTitles.count, id: \.self) { index in
                Button {
                    guard selectedTab != index else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcons[index])
                            .font(.system(size: 19, weight: selectedTab == index ? .semibold : .regular))
                            .symbolEffect(.bounce, value: selectedTab == index)
                        Text(tabTitles[index])
                            .font(.system(size: 10, weight: selectedTab == index ? .semibold : .medium))
                    }
                    .foregroundStyle(selectedTab == index ? Palette.blue : Palette.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if selectedTab == index {
                            Capsule()
                                .fill(Palette.blue.opacity(0.095))
                                .matchedGeometryEffect(id: "tab-selection", in: tabSelection)
                        }
                    }
                    .padding(.horizontal, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line.opacity(0.3)).frame(height: 0.5)
        }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.985, green: 0.985, blue: 1), Color(red: 0.94, green: 0.96, blue: 1), Color(red: 0.965, green: 0.95, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(RadialGradient(colors: [Palette.blue.opacity(0.085), .clear], center: .center, startRadius: 0, endRadius: 132))
                .frame(width: 264, height: 264)
                .offset(x: 150, y: -260)
            Circle()
                .fill(RadialGradient(colors: [Palette.purple.opacity(0.075), .clear], center: .center, startRadius: 0, endRadius: 122))
                .frame(width: 244, height: 244)
                .offset(x: -150, y: 180)
        }.ignoresSafeArea()
    }
}

private struct MotionAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: isVisible || reduceMotion ? 0 : 7)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.992)
            .onAppear {
                guard !isVisible else { return }
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84).delay(min(max(0, delay), 0.06))) {
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.978 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78),
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
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.82), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Palette.ink.opacity(0.045), radius: 11, x: 0, y: 5)
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
        .accessibilityHidden(true)
    }
}

struct BuildElapsedTimer: View {
    let createdAt: String
    let updatedAt: String
    let runStartedAt: String?
    let status: String
    let label: String
    private var startDate: Date { WorkflowRun.parseDate(createdAt) ?? Date() }
    private var finishDate: Date { WorkflowRun.parseDate(updatedAt) ?? Date() }
    private var queueDuration: TimeInterval { max(0, (WorkflowRun.parseDate(runStartedAt ?? "") ?? finishDate).timeIntervalSince(startDate)) }
    private var active: Bool { ["queued", "waiting", "requested", "pending", "in_progress"].contains(status) }
    var body: some View {
        if active { TimelineView(.periodic(from: .now, by: 1)) { ctx in timerRows(now: ctx.date) } }
        else { timerRows(now: finishDate) }
    }
    private func timerRows(now: Date) -> some View {
        let total = max(0, now.timeIntervalSince(startDate))
        let queue = status == "queued" || status == "waiting" || status == "requested" || status == "pending" ? total : queueDuration
        return VStack(alignment: .leading, spacing: 3) {
            timerRow("排队", queue, tint: Palette.purple, icon: "hourglass")
            timerRow(status == "in_progress" ? "总构建耗时" : "总耗时", total, tint: Palette.blue, icon: "timer")
        }
    }
    private func timerRow(_ title: String, _ t: TimeInterval, tint: Color, icon: String) -> some View {
        let n = max(0, Int(t)); let h = n / 3600; let m = (n % 3600) / 60; let s = n % 60
        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
            Text(h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)).monospacedDigit().fontWeight(.semibold)
        }.font(.system(size: 10, weight: .medium)).foregroundStyle(tint)
    }
}


struct StatusGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let status: BuildStatus
    var size: CGFloat = 14

    var body: some View {
        Group {
            if reduceMotion {
                glyph
            } else {
                glyph.symbolEffect(.bounce, value: status)
            }
        }
        .foregroundStyle(status.color)
        .frame(width: size + 9, height: size + 9)
        .accessibilityLabel(status.title)
    }

    private var glyph: some View {
        Image(systemName: status.symbol)
            .font(.system(size: size, weight: .bold))
            .contentTransition(.symbolEffect(.replace))
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
    @State private var repositorySearchText = ""
    @State private var selectedBuildFilter: BuildStatus?
    @State private var prioritizeFailures = true
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let buildFilters: [(title: String, status: BuildStatus?)] = [
        ("全部", nil), ("失败", .failed), ("运行中", .inProgress), ("排队", .queued), ("成功", .success)
    ]
    private var recentRuns: [RepositoryRun] { store.allRecentRuns }

    private var filteredRepositories: [GitHubRepository] {
        let query = repositorySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = store.visibleRepositories.filter { repository in
            let run = store.latestRun(for: repository.fullName)
            let matchesQuery = query.isEmpty
                || store.displayName(for: repository).localizedStandardContains(query)
                || repository.fullName.localizedStandardContains(query)
                || store.note(for: repository).localizedStandardContains(query)
                || (run?.title.localizedStandardContains(query) ?? false)
                || (run?.headBranch.localizedStandardContains(query) ?? false)
                || (run?.shortSHA.localizedStandardContains(query) ?? false)
            let matchesStatus = selectedBuildFilter == nil || run?.buildStatus == selectedBuildFilter
            return matchesQuery && matchesStatus
        }
        return matching.sorted { lhs, rhs in
            @MainActor func priority(_ repository: GitHubRepository) -> Int {
                switch store.latestRun(for: repository.fullName)?.buildStatus {
                case .failed: return 0
                case .inProgress: return 1
                case .queued: return 2
                case .success: return 3
                case nil: return 4
                }
            }
            if prioritizeFailures {
                let leftPriority = priority(lhs)
                let rightPriority = priority(rhs)
                if leftPriority != rightPriority { return leftPriority < rightPriority }
            }
            return (store.latestRun(for: lhs.fullName)?.updatedAt ?? "")
                > (store.latestRun(for: rhs.fullName)?.updatedAt ?? "")
        }
    }
    private func count(_ status: BuildStatus) -> String {
        String(recentRuns.filter { $0.run.buildStatus == status }.count)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
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
                        .padding(8).glassCard(23).motionAppear(0.08)
                        HStack {
                            Text("我的项目").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
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
                        if !store.visibleRepositories.isEmpty {
                            repositoryTools
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
                        } else if filteredRepositories.isEmpty {
                            ContentUnavailableView(
                                "没有匹配的项目",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("试试其他关键词，或切换构建状态筛选。")
                            )
                            .padding(.top, 18)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filteredRepositories) { repository in
                                    RepositoryCard(
                                        repository: repository,
                                        run: store.latestRun(for: repository.fullName),
                                        activeRuns: store.activeRuns(for: repository.fullName),
                                        displayName: store.displayName(for: repository),
                                        note: store.note(for: repository)
                                    )
                                    .id(repository.id)
                                    .motionAppear(0)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.975)),
                                        removal: .move(edge: .top).combined(with: .scale(scale: 0.985))
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
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: store.visibleRepositories.count)
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: recentRuns.map(\.id))
            }

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

    private var repositoryTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                TextField("搜索项目、工作流、分支或 SHA", text: $repositorySearchText)
                    .font(.system(size: 12))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !repositorySearchText.isEmpty {
                    Button { repositorySearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondary)
                    }
                }
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        prioritizeFailures.toggle()
                    }
                } label: {
                    Image(systemName: prioritizeFailures ? "exclamationmark.arrow.circlepath" : "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(prioritizeFailures ? Palette.danger : Palette.secondary)
                        .frame(width: 31, height: 31)
                        .background((prioritizeFailures ? Palette.danger : Palette.secondary).opacity(0.09), in: Circle())
                }
                .accessibilityLabel(prioritizeFailures ? "当前异常优先排序" : "当前最近更新排序")
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(buildFilters.indices), id: \.self) { index in
                        let option = buildFilters[index]
                        let selected = selectedBuildFilter?.rawValue == option.status?.rawValue
                        let tint = option.status?.color ?? Palette.blue
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                selectedBuildFilter = option.status
                            }
                        } label: {
                            Text(option.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected ? .white : tint)
                                .padding(.horizontal, 13).padding(.vertical, 8)
                                .background(selected ? tint : tint.opacity(0.09), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Text("显示 \(filteredRepositories.count) / \(store.visibleRepositories.count) 个项目")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
                Spacer()
                Text(prioritizeFailures ? "异常优先" : "最近更新")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(prioritizeFailures ? Palette.danger : Palette.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: repositorySearchText)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 49)
            VStack(alignment: .leading, spacing: 4) {
                Text("Build Monitor").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                HStack(spacing: 5) {
                    Circle().fill(store.isConnected ? Palette.success : Palette.secondary).frame(width: 6, height: 6)
                    Text(store.isConnected ? "实时监控已连接" : "GitHub 构建监控").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.secondary)
                }
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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 27, height: 27)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                Spacer(minLength: 0)
                StatusGlyph(status: status, size: 10)
            }
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 11)
        .background(tint.opacity(0.065), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.10), lineWidth: 0.8))
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
    @State private var rerunningRunID: Int?
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
                if let run, run.buildStatus == .failed {
                    Button {
                        Task { await retryFailedJobs(run) }
                    } label: {
                        Group {
                            if rerunningRunID == run.id {
                                ProgressView().tint(Palette.blue)
                            } else {
                                Label("重跑失败任务", systemImage: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Palette.success.opacity(0.10), in: Capsule())
                        .foregroundStyle(Palette.success)
                    }
                    .disabled(rerunningRunID != nil)
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

    private func retryFailedJobs(_ failedRun: WorkflowRun) async {
        rerunningRunID = failedRun.id
        do {
            try await store.rerunFailedJobs(repository: repository.fullName, runID: failedRun.id)
            actionMessage = "已向 GitHub 提交失败任务重跑请求。"
        } catch {
            actionMessage = error.localizedDescription
        }
        rerunningRunID = nil
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
        VStack(alignment: .leading, spacing: 6) {
            if let run {
                HStack {
                    Text("\(run.headBranch) · \(run.shortSHA)")
                    Spacer()
                    Text(RelativeDateTimeFormatter.localized(run.updatedAt))
                }.font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
                BuildElapsedTimer(createdAt: run.createdAt, updatedAt: run.updatedAt, runStartedAt: run.runStartedAt, status: run.status, label: run.status == "queued" || run.status == "waiting" || run.status == "requested" || run.status == "pending" ? "排队时间" : (run.status == "in_progress" ? "总构建耗时" : "最终耗时"))
            } else {
                Text("默认分支：\(repository.defaultBranch)").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary)
            }
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
    @State private var searchText = ""

    private var displayedRepositories: [GitHubRepository] {
        let base = showingHidden ? store.hiddenRepositories : store.visibleRepositories
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        return base.filter { repo in
            store.displayName(for: repo).localizedCaseInsensitiveContains(searchText)
                || repo.fullName.localizedCaseInsensitiveContains(searchText)
                || store.note(for: repo).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hero
                        searchField
                        statePicker
                        repositoryList
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("仓库管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(LinearGradient(colors: [Palette.blue.opacity(0.18), Palette.purple.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Palette.blue)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("管理你的项目")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("自定义名称、备注和可见状态")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 9) {
                managementStat(title: "全部仓库", count: store.repositories.count, icon: "square.grid.2x2.fill", tint: Palette.blue)
                managementStat(title: "显示中", count: store.visibleRepositories.count, icon: "eye.fill", tint: Palette.success)
                managementStat(title: "已隐藏", count: store.hiddenRepositories.count, icon: "eye.slash.fill", tint: Palette.purple)
            }
        }
        .padding(15)
        .glassCard(22)
        .motionAppear(0.03)
    }

    private func managementStat(title: String, count: Int, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(tint)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
            }
            Text("\(count)")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
            TextField("搜索仓库名称、备注或用户名", text: $searchText)
                .font(.system(size: 13))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondary)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))
        .shadow(color: Palette.ink.opacity(0.025), radius: 5, y: 2)
    }

    private var statePicker: some View {
        Picker("仓库状态", selection: $showingHidden.animation(.easeInOut(duration: 0.22))) {
            Text("显示中 · \(store.visibleRepositories.count)").tag(false)
            Text("已隐藏 · \(store.hiddenRepositories.count)").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(4)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))
    }

    @ViewBuilder
    private var repositoryList: some View {
        if displayedRepositories.isEmpty {
            ContentUnavailableView(
                searchText.isEmpty ? (showingHidden ? "没有隐藏的仓库" : "暂无显示中的仓库") : "没有匹配的仓库",
                systemImage: searchText.isEmpty ? (showingHidden ? "eye" : "tray") : "magnifyingglass",
                description: Text(searchText.isEmpty ? (showingHidden ? "隐藏的仓库会显示在这里。" : "你可以切换到“已隐藏”恢复仓库。") : "尝试搜索仓库名、完整路径或备注。")
            )
            .padding(.top, 24)
            .motionAppear(0.04)
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(showingHidden ? "隐藏列表" : "仓库列表")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text("\(displayedRepositories.count) 项")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                }
                ForEach(displayedRepositories) { repository in
                    repositoryRow(repository)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.84), value: showingHidden)
            .animation(.easeInOut(duration: 0.2), value: searchText)
        }
    }

    private func repositoryRow(_ repository: GitHubRepository) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.blue.opacity(0.16), Palette.purple.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(String(store.displayName(for: repository).prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.blue)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.displayName(for: repository))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(repository.fullName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                if !store.note(for: repository).isEmpty {
                    Text(store.note(for: repository))
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 3)
            Button { editingRepository = repository } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.blue)
                    .frame(width: 34, height: 34)
                    .background(Palette.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            }
            .accessibilityLabel("编辑仓库名称和备注")
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    store.setRepositoryHidden(repository, hidden: !showingHidden)
                }
            } label: {
                Image(systemName: showingHidden ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(showingHidden ? Palette.success : Palette.secondary)
                    .frame(width: 34, height: 34)
                    .background((showingHidden ? Palette.success : Palette.secondary).opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            }
            .accessibilityLabel(showingHidden ? "显示仓库" : "隐藏仓库")
        }
        .padding(12)
        .glassCard(18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button {
                editingRepository = repository
            } label: {
                Label("编辑名称和备注", systemImage: "pencil")
            }
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    store.setRepositoryHidden(repository, hidden: !showingHidden)
                }
            } label: {
                Label(showingHidden ? "恢复显示仓库" : "隐藏仓库", systemImage: showingHidden ? "eye" : "eye.slash")
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
    @State private var historySearchText = ""
    @State private var selectedHistoryFilter: BuildStatus?
    private let historyFilters: [(title: String, status: BuildStatus?)] = [
        ("全部", nil), ("失败", .failed), ("运行中", .inProgress), ("排队", .queued), ("成功", .success)
    ]

    private var filteredHistoryRuns: [RepositoryRun] {
        let query = historySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.allRecentRuns.filter { item in
            let matchesStatus = selectedHistoryFilter == nil || item.run.buildStatus == selectedHistoryFilter
            let matchesQuery = query.isEmpty
                || store.displayName(for: item.repository).localizedStandardContains(query)
                || item.repository.fullName.localizedStandardContains(query)
                || item.run.title.localizedStandardContains(query)
                || item.run.headBranch.localizedStandardContains(query)
                || item.run.shortSHA.localizedStandardContains(query)
            return matchesStatus && matchesQuery
        }
    }

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
                        historyTools
                        if filteredHistoryRuns.isEmpty {
                            ContentUnavailableView("没有匹配的记录", systemImage: "magnifyingglass", description: Text("更换搜索关键词或构建状态筛选试试。"))
                                .padding(.top, 20)
                        }
                        ForEach(filteredHistoryRuns) { item in
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

    private var historyTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                TextField("搜索项目、工作流、分支或 SHA", text: $historySearchText)
                    .font(.system(size: 12))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !historySearchText.isEmpty {
                    Button { historySearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(historyFilters.indices), id: \.self) { index in
                        let option = historyFilters[index]
                        let selected = selectedHistoryFilter?.rawValue == option.status?.rawValue
                        let tint = option.status?.color ?? Palette.blue
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                selectedHistoryFilter = option.status
                            }
                        } label: {
                            Text(option.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected ? .white : tint)
                                .padding(.horizontal, 13).padding(.vertical, 8)
                                .background(selected ? tint : tint.opacity(0.09), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("找到 \(filteredHistoryRuns.count) 条记录")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
        }
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

                    Text("建议使用 Fine-grained personal access token，并只选择需要监控的仓库。仅监控需要 Metadata: Read-only 与 Actions: Read-only；要从 App 启动、取消或重跑构建，需要将 Actions 提升为 Read and write。Token 不会写入源码或 UserDefaults。")
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
                            Text("• Actions：Read-only（仅监控）")
                        Text("• Actions：Read and write（启动、取消或重跑构建时需要）")
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