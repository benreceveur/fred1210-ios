import Foundation

@MainActor
final class FredInboxViewModel: ObservableObject {
    @Published private(set) var tasks: [Components.Schemas.Task] = []
    @Published private(set) var recommendations: [FredClient.RepoRecommendation] = []
    @Published private(set) var research: [Components.Schemas.ResearchItem] = []
    @Published private(set) var transports: [Components.Schemas.TransportHealth] = []
    @Published private(set) var isLoading = false
    @Published var displayError: FredDisplayError?

    private let client: FredClient

    init(client: FredClient) {
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
        do {
            async let tasksRequest = client.listTasks()
            async let repoRequest = client.fetchRepoIntelligence()
            async let researchRequest = client.listRecentResearch(limit: 10)
            async let transportsRequest = client.fetchTransportHealth()

            let (tasks, repo, research, transports) = try await (
                tasksRequest,
                repoRequest,
                researchRequest,
                transportsRequest
            )
            self.tasks = tasks.sorted { lhs, rhs in
                priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
            self.recommendations = repo.recommendations
            self.research = research
            self.transports = transports
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(
                error,
                endpoint: "Inbox",
                retry: { [weak self] in await self?.load() }
            )
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
}
