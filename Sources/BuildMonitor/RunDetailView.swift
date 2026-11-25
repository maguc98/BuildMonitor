import SwiftUI

private enum DetailTab: String, CaseIterable {
    case progress = "构建进度"
    case logs = "日志"
    case artifacts = "产物"
}

struct RunDetailView: View {
    @EnvironmentObject private var store: BuildMonitorStore
    let repository: GitHubRepository
    let run: WorkflowRun
    @State private var selectedTab: DetailTab = .progress
    @State private var jobs: [WorkflowJob] = []
    @State private var artifacts: [WorkflowArtifact] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadingArtifactID: Int?
    @State private var shareURL: URL?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    repositoryHeader
                    runStatusCard
                    metadata
                    Picker("详情", selection: $selectedTab) {
                        ForEach(DetailTab.allCases, id: \.self) { item in Text(item.rawValue).tag(item) }
                    }.pickerStyle(.segmented)

                    if isLoading { ProgressView("正在读取 GitHub 构建详情…").frame(maxWidth: .infinity).padding(.vertical, 24) }
                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12)).foregroundStyle(Palette.danger).padding(12).glassCard(16)
                    }
                    switch selectedTab {
                    case .progress: progressList
                    case .logs: logsPanel
                    case .artifacts: artifactsPanel
                    }
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label("分享已下载的 Artifact ZIP", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.blue)
                        }.padding(.top, 4)
                    }
                }.padding(18).padding(.bottom, 30)
            }
        }
        .navigationTitle("构建详情").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let url = URL(string: run.htmlURL) { Link("在 GitHub 打开", destination: url) }
                    Button("刷新详情", systemImage: "arrow.clockwise") { Task { await loadDetails() } }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Palette.ink)
                }
            }
        }
        .task { await loadDetails() }
    }

    private var repositoryHeader: some View {
        HStack(spacing: 10) {
            AppMark(size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(repository.name).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                Text(repository.fullName).font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            Spacer()
        }
    }

    private var runStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 22, weight: .semibold)).frame(width: 45, height: 45)
                .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(run.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                Text(run.buildStatus.title + " · #\(run.runNumber)").font(.system(size: 12, weight: .semibold)).foregroundStyle(run.buildStatus.color)
            }
            Spacer()
            if run.status == "in_progress" { ProgressView().tint(Palette.blue) }
            else { Image(systemName: run.buildStatus.symbol).font(.system(size: 24)).foregroundStyle(run.buildStatus.color) }
        }
        .padding(15)
        .background(LinearGradient(colors: [.white.opacity(0.95), Palette.blue.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white, lineWidth: 1))
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            MetaChip(icon: "arrow.triangle.branch", text: run.headBranch)
            MetaChip(icon: "number", text: run.shortSHA)
            MetaChip(icon: "clock", text: RelativeDateTimeFormatter.localized(run.updatedAt))
        }
    }

    private var progressList: some View {
        VStack(alignment: .leading, spacing: 13) {
            if jobs.isEmpty && !isLoading {
                ContentUnavailableView("暂无 Job 信息", systemImage: "list.bullet.rectangle", description: Text("GitHub 没有返回此运行的 Job。"))
            }
            ForEach(jobs) { job in
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text(job.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(job.conclusion ?? job.status)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(jobStatusColor(job.status, conclusion: job.conclusion))
                    }
                    ForEach(job.steps ?? []) { step in
                        HStack(spacing: 10) {
                            Image(systemName: stepSymbol(step)).font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(stepColor(step)).frame(width: 23)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(step.conclusion ?? step.status).font(.system(size: 10, weight: .medium)).foregroundStyle(stepColor(step))
                            }
                            Spacer()
                            if step.status == "in_progress" { ProgressView().tint(Palette.blue) }
                        }.padding(.vertical, 3)
                    }
                    if let url = URL(string: job.htmlURL) {
                        Link(destination: url) {
                            Label("查看此 Job", systemImage: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                        }.foregroundStyle(Palette.blue).padding(.top, 2)
                    }
                }.padding(14).glassCard(18)
            }
        }
    }

    private var logsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Job 与步骤状态").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
            Text("这里展示 GitHub 返回的真实 Job / Step 执行摘要。完整逐行控制台输出目前通过 GitHub Actions 页面打开。")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            ForEach(jobs) { job in
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                    ForEach(job.steps ?? []) { step in
                        HStack {
                            Text(step.name).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
                            Spacer()
                            Text(step.conclusion ?? step.status).font(.system(size: 10, weight: .semibold)).foregroundStyle(stepColor(step))
                        }
                    }
                    if let url = URL(string: job.htmlURL) {
                        Link("在 GitHub 查看完整日志", destination: url).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.blue).padding(.top, 4)
                    }
                }.padding(14).glassCard(17)
            }
            if jobs.isEmpty && !isLoading {
                ContentUnavailableView("没有可显示的日志摘要", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    private var artifactsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if artifacts.isEmpty && !isLoading {
                ContentUnavailableView("暂无构建产物", systemImage: "shippingbox", description: Text("此运行没有上传 Artifact，或 Token 缺少 Actions 读取权限。"))
            }
            ForEach(artifacts) { artifact in
                HStack(spacing: 12) {
                    Image(systemName: "doc.zipper").font(.system(size: 25)).foregroundStyle(Palette.blue)
                        .frame(width: 48, height: 48).background(Palette.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artifact.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                        Text("\(artifact.formattedSize) · \(artifact.expired ? "已过期" : "可下载")")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(artifact.expired ? Palette.danger : Palette.secondary)
                    }
                    Spacer()
                    if artifact.expired {
                        Image(systemName: "xmark.circle").foregroundStyle(Palette.danger)
                    } else if downloadingArtifactID == artifact.id {
                        ProgressView().tint(Palette.blue)
                    } else {
                        Button { Task { await download(artifact) } } label: {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.blue)
                        }
                    }
                }.padding(14).glassCard(18)
            }
            if !artifacts.isEmpty {
                Text("下载内容为 GitHub Artifact ZIP 压缩包，IPA 文件包含在其中。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await store.loadRunDetails(repository: repository.fullName, runID: run.id)
            jobs = result.jobs
            artifacts = result.artifacts
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func download(_ artifact: WorkflowArtifact) async {
        downloadingArtifactID = artifact.id
        errorMessage = nil
        do {
            shareURL = try await store.downloadArtifact(repository: repository.fullName, artifact: artifact)
        } catch {
            errorMessage = error.localizedDescription
        }
        downloadingArtifactID = nil
    }

    private func stepColor(_ step: WorkflowJobStep) -> Color {
        if step.status == "in_progress" { return Palette.blue }
        if step.conclusion == "success" { return Palette.success }
        if step.conclusion == "failure" { return Palette.danger }
        return Palette.secondary
    }

    private func stepSymbol(_ step: WorkflowJobStep) -> String {
        if step.status == "in_progress" { return "arrow.triangle.2.circlepath" }
        if step.conclusion == "success" { return "checkmark.circle.fill" }
        if step.conclusion == "failure" { return "xmark.circle.fill" }
        if step.conclusion == "skipped" { return "forward.end.fill" }
        return "circle"
    }

    private func jobStatusColor(_ status: String, conclusion: String?) -> Color {
        if status == "in_progress" { return Palette.blue }
        if conclusion == "success" { return Palette.success }
        if conclusion == "failure" { return Palette.danger }
        return Palette.secondary
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
        .foregroundStyle(Palette.secondary).padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.white.opacity(0.58), in: Capsule())
    }
}
