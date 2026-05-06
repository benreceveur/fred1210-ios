import Foundation

@MainActor
protocol FredInboxClient: AnyObject {
    func listTasks() async throws -> [Components.Schemas.Task]
    func fetchRepoIntelligence() async throws -> FredClient.RepoIntelligenceDashboard
    func listRecentResearch(limit: Int) async throws -> [Components.Schemas.ResearchItem]
    func fetchTransportHealth() async throws -> [Components.Schemas.TransportHealth]
}

extension FredClient: FredInboxClient {}

@MainActor
final class FredInboxViewModel: ObservableObject {
    @Published private(set) var tasks: [Components.Schemas.Task] = []
    @Published private(set) var recommendations: [FredClient.RepoRecommendation] = []
    @Published private(set) var research: [Components.Schemas.ResearchItem] = []
    @Published private(set) var transports: [Components.Schemas.TransportHealth] = []
    @Published private(set) var isLoading = false
    @Published var displayError: FredDisplayError?

    private let client: FredInboxClient

    init(client: FredInboxClient) {
        self.client = client
    }

    var needsBobTasks: [Components.Schemas.Task] {
        tasks.filter { $0.status == .review || $0.priority == .urgent }
    }

    var fredWorkingTasks: [Components.Schemas.Task] {
        tasks.filter {
            $0.status == .inProgress
                && (($0.assignee ?? "").lowercased().contains("fred") || ($0.assignee ?? "").isEmpty)
        }
    }

    var completedTasks: [Components.Schemas.Task] {
        tasks.filter { $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var pendingRecommendations: [FredClient.RepoRecommendation] {
        recommendations.filter { $0.status == "pending" }
    }

    var degradedTransports: [Components.Schemas.TransportHealth] {
        transports.filter { $0.degraded }
    }

    var attentionCount: Int {
        needsBobTasks.count + pendingRecommendations.count + degradedTransports.count
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let tasksRequest = capture { try await client.listTasks() }
        async let repoRequest = capture { try await client.fetchRepoIntelligence() }
        async let researchRequest = capture { try await client.listRecentResearch(limit: 10) }
        async let transportsRequest = capture { try await client.fetchTransportHealth() }

        let (tasksResult, repoResult, researchResult, transportsResult) = await (
            tasksRequest,
            repoRequest,
            researchRequest,
            transportsRequest
        )

        var failures: [(String, Error)] = []

        switch tasksResult {
        case .success(let tasks):
            self.tasks = tasks.sorted { lhs, rhs in
                priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
        case .failure(let error):
            failures.append(("Tasks", error))
        }

        switch repoResult {
        case .success(let repo):
            self.recommendations = repo.recommendations
        case .failure(let error):
            failures.append(("Repo recommendations", error))
        }

        switch researchResult {
        case .success(let research):
            self.research = research
        case .failure(let error):
            failures.append(("Research", error))
        }

        switch transportsResult {
        case .success(let transports):
            self.transports = transports
        case .failure(let error):
            failures.append(("Transport health", error))
        }

        if failures.isEmpty {
            displayError = nil
        } else {
            displayError = partialInboxError(from: failures)
        }
    }

    func clearError() {
        displayError = nil
    }

    private func priorityRank(_ priority: Components.Schemas.Task.PriorityPayload) -> Int {
        switch priority {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .none: return 4
        }
    }

    private func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func partialInboxError(from failures: [(String, Error)]) -> FredDisplayError {
        let failedSections = failures.map(\.0).joined(separator: ", ")
        let detail = failures
            .map { section, error in
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                return "\(section): \(message)"
            }
            .joined(separator: "\n")

        return FredDisplayError(
            endpoint: "Inbox",
            primaryMessage: failures.count == 4 ? "Inbox failed to load" : "Some inbox sections did not load",
            detailMessage: "\(failedSections)\n\(detail)",
            httpStatus: nil,
            retry: { [weak self] in await self?.load() }
        )
    }
}
