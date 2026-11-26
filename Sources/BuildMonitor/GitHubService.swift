import BackgroundTasks
import Foundation
import Security
import SwiftUI
import UserNotifications

struct GitHubUser: Decodable {
    let login: String
    let avatarURL: String?
    enum CodingKeys: String, CodingKey { case login; case avatarURL = "avatar_url" }
}

struct GitHubRepository: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let htmlURL: String
    let defaultBranch: String
    let updatedAt: String
    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlURL = "html_url"
        case defaultBranch = "default_branch"
        case updatedAt = "updated_at"
    }
}

struct WorkflowRunsResponse: Decodable {
    let workflowRuns: [WorkflowRun]
    enum CodingKeys: String, CodingKey { case workflowRuns = "workflow_runs" }
}

struct WorkflowsResponse: Decodable {
    let workflows: [WorkflowDefinition]
}

struct WorkflowDefinition: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let path: String
    let state: String
}

struct WorkflowRun: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let displayTitle: String?
    let runNumber: Int
    let headBranch: String
    let headSHA: String
    let status: String
    let conclusion: String?
    let htmlURL: String
    let createdAt: String
    let runStartedAt: String?
    let updatedAt: String
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case displayTitle = "display_title"
        case runNumber = "run_number"
        case headBranch = "head_branch"
        case headSHA = "head_sha"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case runStartedAt = "run_started_at"
        case updatedAt = "updated_at"
    }
    static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    var buildStatus: BuildStatus {
        switch status {
        case "in_progress": return .inProgress
        case "queued", "waiting", "requested", "pending": return .queued
        case "completed": return conclusion == "success" ? .success : .failed
        default: return .queued
        }
    }
    var title: String {
        let candidate = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, !candidate.isEmpty { return candidate }
        return displayTitle ?? "GitHub Actions"
    }
    var shortSHA: String { String(headSHA.prefix(7)) }
}

struct WorkflowJobsResponse: Decodable { let jobs: [WorkflowJob] }

struct WorkflowJob: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let htmlURL: String
    let steps: [WorkflowJobStep]?
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, steps
        case htmlURL = "html_url"
    }
}

struct WorkflowJobStep: Decodable, Identifiable, Hashable {
    let number: Int
    let name: String
    let status: String
    let conclusion: String?
    let startedAt: String?
    let completedAt: String?
    var id: Int { number }
    enum CodingKeys: String, CodingKey {
        case number, name, status, conclusion
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct WorkflowArtifactsResponse: Decodable { let artifacts: [WorkflowArtifact] }

struct WorkflowArtifact: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let sizeInBytes: Int
    let expired: Bool
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, name, expired
        case sizeInBytes = "size_in_bytes"
        case createdAt = "created_at"
    }
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .file)
    }
}

struct RepositoryRun: Identifiable {
    let repository: GitHubRepository
    let run: WorkflowRun
    var id: String { "\(repository.id)-\(run.id)" }
}

enum GitHubAPIError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden(String)
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "GitHub API 地址无效。"
        case .unauthorized: return "Token 无效或已过期，请重新连接 GitHub。"
        case .forbidden(let message):
            return message.isEmpty ? "当前 Token 没有读取此仓库 Actions 的权限。" : message
        case .server(let message): return message
        case .invalidResponse: return "GitHub 返回了无法识别的数据。"
        }
    }
}

struct GitHubAPIClient {
    private let baseURL = "https://api.github.com"

    func currentUser(token: String) async throws -> GitHubUser {
        try await get("/user", token: token)
    }

    func repositories(token: String) async throws -> [GitHubRepository] {
        var all: [GitHubRepository] = []
        for page in 1...10 {
            let batch: [GitHubRepository] = try await get(
                "/user/repos?per_page=100&sort=updated&affiliation=owner,collaborator,organization_member&page=\(page)",
                token: token
            )
            all.append(contentsOf: batch)
            if batch.count < 100 { break }
        }
        return all
    }

    func workflowRuns(token: String, repository: String) async throws -> [WorkflowRun] {
        let response: WorkflowRunsResponse = try await get(
            "/repos/\(repository)/actions/runs?per_page=10",
            token: token
        )
        return response.workflowRuns
    }


    func workflows(token: String, repository: String) async throws -> [WorkflowDefinition] {
        let response: WorkflowsResponse = try await get(
            "/repos/\(repository)/actions/workflows?per_page=100",
            token: token
        )
        return response.workflows
    }

    func dispatchWorkflow(token: String, repository: String, workflowID: Int, ref: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["ref": ref])
        _ = try await requestData(
            "/repos/\(repository)/actions/workflows/\(workflowID)/dispatches",
            token: token,
            method: "POST",
            body: body
        )
    }

    func cancelWorkflowRun(token: String, repository: String, runID: Int) async throws {
        _ = try await requestData(
            "/repos/\(repository)/actions/runs/\(runID)/cancel",
            token: token,
            method: "POST"
        )
    }

    func rerunFailedJobs(token: String, repository: String, runID: Int) async throws {
        _ = try await requestData(
            "/repos/\(repository)/actions/runs/\(runID)/rerun-failed-jobs",
            token: token,
            method: "POST"
        )
    }

    func jobs(token: String, repository: String, runID: Int) async throws -> [WorkflowJob] {
        let response: WorkflowJobsResponse = try await get(
            "/repos/\(repository)/actions/runs/\(runID)/jobs?per_page=100",
            token: token
        )
        return response.jobs
    }

    func artifacts(token: String, repository: String, runID: Int) async throws -> [WorkflowArtifact] {
        let response: WorkflowArtifactsResponse = try await get(
            "/repos/\(repository)/actions/runs/\(runID)/artifacts?per_page=100",
            token: token
        )
        return response.artifacts
    }

    func downloadArtifact(token: String, repository: String, artifactID: Int, progress: @escaping @MainActor (Double) -> Void) async throws -> Data {
        guard let url = URL(string: baseURL + "/repos/\(repository)/actions/artifacts/\(artifactID)/zip") else {
            throw GitHubAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        await progress(0)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 { throw GitHubAPIError.unauthorized }
            throw GitHubAPIError.server("Artifact 下载失败（HTTP \(http.statusCode)）。")
        }
        await progress(1)
        return data
    }

    private func get<T: Decodable>(_ path: String, token: String) async throws -> T {
        let data = try await requestData(path, token: token)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.server("GitHub 数据解析失败：\(error.localizedDescription)")
        }
    }

    private func requestData(_ path: String, token: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw GitHubAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubAPIError.invalidResponse }
        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            let message = (try? JSONDecoder().decode(GitHubErrorPayload.self, from: data).message) ?? ""
            throw GitHubAPIError.forbidden(message)
        default:
            let message = (try? JSONDecoder().decode(GitHubErrorPayload.self, from: data).message)
                ?? "GitHub API 请求失败（HTTP \(http.statusCode)）。"
            throw GitHubAPIError.server(message)
        }
    }
}

private struct GitHubErrorPayload: Decodable { let message: String }

enum TokenKeychain {
    private static let service = "com.maguc98.BuildMonitor"
    private static let account = "github-personal-access-token"

    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(update) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class BuildMonitorStore: ObservableObject {
    @Published private(set) var username: String?
    @Published private(set) var repositories: [GitHubRepository] = []
    @Published private(set) var runsByRepository: [String: [WorkflowRun]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var hiddenRunIDs: Set<String> = UserDefaults.standard.stringArray(forKey: "BuildMonitor.hiddenRuns")?.reduce(into: Set<String>()) { $0.insert($1) } ?? []
    @Published private(set) var hiddenRepositoryIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "BuildMonitor.hiddenRepositories") ?? [])
    @Published private(set) var repositoryDisplayNames: [String: String] = UserDefaults.standard.dictionary(forKey: "BuildMonitor.repositoryDisplayNames") as? [String: String] ?? [:]
    @Published private(set) var repositoryNotes: [String: String] = UserDefaults.standard.dictionary(forKey: "BuildMonitor.repositoryNotes") as? [String: String] ?? [:]

    private let api = GitHubAPIClient()
    private var token: String?
    private var pollingTask: Task<Void, Never>?
    var isConnected: Bool { token != nil }

    var visibleRepositories: [GitHubRepository] {
        repositories.filter { !hiddenRepositoryIDs.contains($0.fullName) }
    }

    var hiddenRepositories: [GitHubRepository] {
        repositories.filter { hiddenRepositoryIDs.contains($0.fullName) }
    }

    var allRecentRuns: [RepositoryRun] {
        repositories.flatMap { repository in
            (runsByRepository[repository.fullName] ?? []).map {
                RepositoryRun(repository: repository, run: $0)
            }
        }
        .filter { !hiddenRunIDs.contains($0.id) }
        .sorted { $0.run.createdAt > $1.run.createdAt }
    }

    func latestRun(for repository: String) -> WorkflowRun? {
        runsByRepository[repository]?.first
    }

    func activeRuns(for repository: String) -> [WorkflowRun] {
        (runsByRepository[repository] ?? []).filter { $0.status == "in_progress" || $0.buildStatus == .queued }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func displayName(for repository: GitHubRepository) -> String {
        repositoryDisplayNames[repository.fullName] ?? repository.name
    }

    func note(for repository: GitHubRepository) -> String {
        repositoryNotes[repository.fullName] ?? ""
    }

    func setRepositoryHidden(_ repository: GitHubRepository, hidden: Bool) {
        if hidden {
            hiddenRepositoryIDs.insert(repository.fullName)
        } else {
            hiddenRepositoryIDs.remove(repository.fullName)
        }
        UserDefaults.standard.set(Array(hiddenRepositoryIDs).sorted(), forKey: "BuildMonitor.hiddenRepositories")
    }

    func updateRepositoryMetadata(_ repository: GitHubRepository, displayName: String, note: String) {
        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedName.isEmpty || cleanedName == repository.name {
            repositoryDisplayNames.removeValue(forKey: repository.fullName)
        } else {
            repositoryDisplayNames[repository.fullName] = cleanedName
        }

        if cleanedNote.isEmpty {
            repositoryNotes.removeValue(forKey: repository.fullName)
        } else {
            repositoryNotes[repository.fullName] = cleanedNote
        }

        UserDefaults.standard.set(repositoryDisplayNames, forKey: "BuildMonitor.repositoryDisplayNames")
        UserDefaults.standard.set(repositoryNotes, forKey: "BuildMonitor.repositoryNotes")
    }

    func hideHistoryRecord(_ item: RepositoryRun) {
        hiddenRunIDs.insert(item.id)
        UserDefaults.standard.set(Array(hiddenRunIDs), forKey: "BuildMonitor.hiddenRuns")
    }

    func restoreHiddenHistory() {
        hiddenRunIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: "BuildMonitor.hiddenRuns")
    }
    func restoreSession() async {
        guard let savedToken = TokenKeychain.read() else { return }
        token = savedToken
        do {
            let user = try await api.currentUser(token: savedToken)
            username = user.login
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect(token newToken: String) async throws {
        let cleaned = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw GitHubAPIError.unauthorized }
        let user = try await api.currentUser(token: cleaned)
        try TokenKeychain.save(cleaned)
        token = cleaned
        username = user.login
        await refresh()
        startPolling()
        BackgroundRefreshScheduler.schedule()
        if let errorMessage { throw GitHubAPIError.server(errorMessage) }
    }

    func disconnect() {
        stopPolling()
        TokenKeychain.delete()
        token = nil
        username = nil
        repositories = []
        runsByRepository = [:]
        lastRefreshed = nil
        hasLoaded = false
        errorMessage = nil
        RunNotificationTracker.reset()
    }

    func refresh() async {
        guard let token else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            let fetchedRepositories = try await api.repositories(token: token)
            let targets = Array(fetchedRepositories.prefix(40))
            let client = api
            let results = await withTaskGroup(of: (String, [WorkflowRun]).self) { group in
                for repository in targets {
                    group.addTask {
                        do {
                            let runs = try await client.workflowRuns(token: token, repository: repository.fullName)
                            return (repository.fullName, runs)
                        } catch {
                            return (repository.fullName, [])
                        }
                    }
                }
                var values: [(String, [WorkflowRun])] = []
                for await value in group { values.append(value) }
                return values
            }
            let newRunsByRepository = Dictionary(uniqueKeysWithValues: results)
            // Silent background refreshes still animate data changes in-place.
            // Keep network activity unobtrusive; animate only the UI updates.
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                repositories = fetchedRepositories
                runsByRepository = newRunsByRepository
            }

            let observedRuns = fetchedRepositories.prefix(40).flatMap { repository in
                (runsByRepository[repository.fullName] ?? []).map {
                    RepositoryRun(repository: repository, run: $0)
                }
            }
            await RunNotificationTracker.process(observedRuns)

            lastRefreshed = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPolling(interval: UInt64 = 1) {
        guard token != nil, pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: interval * 1_000_000_000)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }


    func availableWorkflows(repository: String) async throws -> [WorkflowDefinition] {
        guard let token else { throw GitHubAPIError.unauthorized }
        return try await api.workflows(token: token, repository: repository)
    }

    func startWorkflow(repository: String, workflowID: Int, ref: String) async throws {
        guard let token else { throw GitHubAPIError.unauthorized }
        try await api.dispatchWorkflow(token: token, repository: repository, workflowID: workflowID, ref: ref)
        await refresh()
    }

    func cancelWorkflowRun(repository: String, runID: Int) async throws {
        guard let token else { throw GitHubAPIError.unauthorized }
        try await api.cancelWorkflowRun(token: token, repository: repository, runID: runID)
        await refresh()
    }

    func rerunFailedJobs(repository: String, runID: Int) async throws {
        guard let token else { throw GitHubAPIError.unauthorized }
        try await api.rerunFailedJobs(token: token, repository: repository, runID: runID)
        await refresh()
    }

    func loadRunDetails(repository: String, runID: Int) async throws -> (jobs: [WorkflowJob], artifacts: [WorkflowArtifact]) {
        guard let token else { throw GitHubAPIError.unauthorized }
        async let jobs = api.jobs(token: token, repository: repository, runID: runID)
        async let artifacts = api.artifacts(token: token, repository: repository, runID: runID)
        return try await (jobs, artifacts)
    }

    func downloadArtifact(repository: String, artifact: WorkflowArtifact, progress: @escaping @MainActor (Double) -> Void) async throws -> URL {
        guard let token else { throw GitHubAPIError.unauthorized }
        let data = try await api.downloadArtifact(token: token, repository: repository, artifactID: artifact.id, progress: progress)
        let safeName = artifact.name.replacingOccurrences(of: "/", with: "-")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)-\(artifact.id).zip")
        try data.write(to: destination, options: .atomic)
        return destination
    }
}


enum BuildNotificationManager {
    static let enabledKey = "buildNotifications.enabled"
    static let successKey = "buildNotifications.success"
    static let failureKey = "buildNotifications.failure"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            enabledKey: false,
            successKey: true,
            failureKey: true
        ])
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func post(repository: String, run: WorkflowRun, status: BuildStatus) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }
        if status == .success && !defaults.bool(forKey: successKey) { return }
        if status == .failed && !defaults.bool(forKey: failureKey) { return }
        guard status == .success || status == .failed else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = status == .success ? "构建成功" : "构建失败"
        content.body = "\(repository) · \(run.title) · #\(run.runNumber)"
        content.sound = .default
        content.userInfo = [
            "repository": repository,
            "runID": run.id
        ]

        let request = UNNotificationRequest(
            identifier: "build-monitor-\(run.id)-\(status.rawValue)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}

enum RunNotificationTracker {
    private static let snapshotKey = "buildNotifications.runSnapshot.v1"
    private static let lastSyncKey = "buildNotifications.lastSync.v1"

    static func reset() {
        UserDefaults.standard.removeObject(forKey: snapshotKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
    }

    static func process(_ items: [RepositoryRun]) async {
        let defaults = UserDefaults.standard
        let previous = defaults.dictionary(forKey: snapshotKey) as? [String: String]
        let firstSnapshot = previous == nil
        let lastSync = defaults.object(forKey: lastSyncKey) as? Date
        var next = previous ?? [:]

        for item in items {
            let key = "\(item.repository.fullName)#\(item.run.id)"
            let current = item.run.buildStatus.rawValue
            let isTerminal = item.run.buildStatus == .success || item.run.buildStatus == .failed
            guard isTerminal else {
                next[key] = current
                continue
            }

            var shouldNotify = false
            if let oldStatus = previous?[key] {
                shouldNotify = oldStatus != current
            } else if !firstSnapshot, let lastSync,
                      let createdAt = ISO8601DateFormatter().date(from: item.run.createdAt) {
                shouldNotify = createdAt > lastSync
            }

            if shouldNotify {
                await BuildNotificationManager.post(
                    repository: item.repository.fullName,
                    run: item.run,
                    status: item.run.buildStatus
                )
            }
            next[key] = current
        }

        defaults.set(next, forKey: snapshotKey)
        defaults.set(Date(), forKey: lastSyncKey)
    }
}

enum BackgroundRefreshScheduler {
    static let identifier = "com.maguc98.BuildMonitor.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    static func schedule() {
        guard TokenKeychain.read() != nil,
              UserDefaults.standard.bool(forKey: BuildNotificationManager.enabledKey) else { return }

        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // iOS decides when the task can run; scheduling may be deferred or rejected.
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        let operation = Task {
            let succeeded = await BackgroundRefreshWorker.run()
            task.setTaskCompleted(success: succeeded)
        }
        task.expirationHandler = {
            operation.cancel()
        }
    }
}

enum BackgroundRefreshWorker {
    static func run() async -> Bool {
        guard UserDefaults.standard.bool(forKey: BuildNotificationManager.enabledKey),
              let token = TokenKeychain.read() else { return true }

        let api = GitHubAPIClient()
        do {
            let repositories = try await api.repositories(token: token)
            let selected = Array(repositories.prefix(20))
            let results = await withTaskGroup(of: [RepositoryRun].self) { group in
                for repository in selected {
                    group.addTask {
                        do {
                            let runs = try await api.workflowRuns(token: token, repository: repository.fullName)
                            return runs.map { RepositoryRun(repository: repository, run: $0) }
                        } catch {
                            return []
                        }
                    }
                }

                var collected: [RepositoryRun] = []
                for await batch in group {
                    collected.append(contentsOf: batch)
                }
                return collected
            }

            await RunNotificationTracker.process(results)
            return true
        } catch {
            return false
        }
    }
}

final class BuildNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BuildNotificationDelegate()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
