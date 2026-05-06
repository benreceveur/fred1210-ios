import XCTest
@testable import Fred1210

final class Fred1210Tests: XCTestCase {
    func testThemeExposesAllBrandColors() throws {
        // Smoke test: the theme tokens load without crashing.
        _ = Theme.primary
        _ = Theme.bgDark
        _ = Theme.textPrimary
        XCTAssertEqual(Theme.Spacing.lg, 16)
        XCTAssertEqual(Theme.Font.md, 15)
    }

    func testFredConfigFallsBackToDefaultHost() throws {
        // When the keychain has no stored host, hostURL should equal
        // the hard-coded Tailscale fallback.
        let config = FredConfig()
        XCTAssertEqual(
            config.hostURL.absoluteString,
            FredConfig.defaultHost,
            "FredConfig should default to the Tailscale host when keychain is empty"
        )
    }

    @MainActor
    func testInboxKeepsLoadedSectionsWhenOneRequestIsCancelled() async throws {
        let client = MockInboxClient()
        client.repoResult = .failure(URLError(.cancelled))

        let viewModel = FredInboxViewModel(client: client)
        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.tasks.map(\.id), ["urgent-task", "todo-task"])
        XCTAssertEqual(viewModel.research.map(\.id), ["research-1"])
        XCTAssertEqual(viewModel.transports.map(\.transport), [.slack])
        XCTAssertTrue(viewModel.recommendations.isEmpty)
        XCTAssertEqual(viewModel.displayError?.primaryMessage, "Some inbox sections did not load")
        XCTAssertTrue(viewModel.displayError?.body.contains("Repo recommendations") == true)
    }
}

@MainActor
private final class MockInboxClient: FredInboxClient {
    var tasksResult: Result<[Components.Schemas.Task], Error> = .success([
        .init(
            id: "todo-task",
            title: "Todo",
            status: .todo,
            priority: .medium,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        ),
        .init(
            id: "urgent-task",
            title: "Urgent",
            status: .review,
            priority: .urgent,
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
    ])
    var repoResult: Result<FredClient.RepoIntelligenceDashboard, Error> = .success(.init(
        lastRunAt: "2026-05-06T00:00:00Z",
        recommendations: [
            .init(
                id: "repo-rec",
                target: .init(owner: "benreceveur", repo: "fred", label: "Fred", category: "agent-runtime", safety: nil),
                snapshot: .init(url: "https://github.com/benreceveur/fred", stars: 1, forks: 0, latestReleaseTag: nil, latestCommitMessage: nil),
                posture: "adapt",
                reason: "Useful signal",
                action: "Review",
                status: "pending",
                createdAt: "2026-05-06T00:00:00Z",
                updatedAt: "2026-05-06T00:00:00Z",
                taskId: nil
            )
        ]
    ))
    var researchResult: Result<[Components.Schemas.ResearchItem], Error> = .success([
        .init(
            id: "research-1",
            title: "Research",
            savedAt: Date(timeIntervalSince1970: 3),
            summary: "Summary"
        )
    ])
    var transportsResult: Result<[Components.Schemas.TransportHealth], Error> = .success([
        .init(
            transport: .slack,
            queuePending: 0,
            degraded: false,
            degradedReasons: [],
            consecutiveFailures: 0
        )
    ])

    func listTasks() async throws -> [Components.Schemas.Task] {
        try tasksResult.get()
    }

    func fetchRepoIntelligence() async throws -> FredClient.RepoIntelligenceDashboard {
        try repoResult.get()
    }

    func listRecentResearch(limit: Int) async throws -> [Components.Schemas.ResearchItem] {
        try researchResult.get()
    }

    func fetchTransportHealth() async throws -> [Components.Schemas.TransportHealth] {
        try transportsResult.get()
    }
}
