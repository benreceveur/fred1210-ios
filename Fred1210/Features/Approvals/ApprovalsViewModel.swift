import Foundation

@MainActor
final class ApprovalsViewModel: ObservableObject {
    @Published private(set) var recommendations: [FredClient.RepoRecommendation] = []
    @Published private(set) var lastRunAt: String?
    @Published private(set) var isLoading = false
    @Published var displayError: FredDisplayError?

    private let client: FredClient

    init(client: FredClient) {
        self.client = client
    }

    var pending: [FredClient.RepoRecommendation] {
        recommendations.filter { $0.status == "pending" }
    }

    var resolved: [FredClient.RepoRecommendation] {
        recommendations.filter { $0.status != "pending" }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dashboard = try await client.fetchRepoIntelligence()
            recommendations = dashboard.recommendations
            lastRunAt = dashboard.lastRunAt
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(
                error,
                endpoint: "Review queue",
                retry: { [weak self] in await self?.load() }
            )
        }
    }

    func runScan() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dashboard = try await client.runRepoIntelligenceScan()
            recommendations = dashboard.recommendations
            lastRunAt = dashboard.lastRunAt
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(
                error,
                endpoint: "Repo scan",
                retry: { [weak self] in await self?.runScan() }
            )
        }
    }

    func approve(_ recommendation: FredClient.RepoRecommendation) async {
        await resolve(recommendation, action: "approve", endpoint: "Approve recommendation")
    }

    func dismiss(_ recommendation: FredClient.RepoRecommendation) async {
        await resolve(recommendation, action: "dismiss", endpoint: "Dismiss recommendation")
    }

    func clearError() {
        displayError = nil
    }

    private func resolve(
        _ recommendation: FredClient.RepoRecommendation,
        action: String,
        endpoint: String
    ) async {
        do {
            let updated = try await client.resolveRepoRecommendation(id: recommendation.id, action: action)
            if let index = recommendations.firstIndex(where: { $0.id == updated.id }) {
                recommendations[index] = updated
            }
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(
                error,
                endpoint: endpoint,
                retry: { [weak self] in await self?.load() }
            )
        }
    }
}
