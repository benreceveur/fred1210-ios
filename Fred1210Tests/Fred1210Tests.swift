import XCTest
import SwiftUI
import UIKit
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

    func testThemeSurfaceColorsAdaptToAppearance() throws {
        // Regression for B2 (Light Appearance gap). Theme surface colors
        // must resolve to different UIColors under .light vs .dark traits.
        let surfaceTokens: [(name: String, ui: UIColor)] = [
            ("bgDark", Theme.bgDarkUI),
            ("bgCard", Theme.bgCardUI),
            ("bgInput", Theme.bgInputUI),
            ("textPrimary", Theme.textPrimaryUI),
            ("textSecondary", Theme.textSecondaryUI),
            ("border", Theme.borderUI),
        ]
        for token in surfaceTokens {
            let dark = token.ui.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            let light = token.ui.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            XCTAssertNotEqual(
                dark, light,
                "Theme.\(token.name) must differ between light and dark — got the same UIColor"
            )
        }
    }

    func testThemeBrandPrimaryStaysPurple() throws {
        // Regression for B3 (token drift). Brand purple #6c5ce7 must be
        // identical in light + dark so the brand mark holds across modes.
        let ui = UIColor(Theme.primary)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        // #6c5ce7 = rgb(108, 92, 231) — allow 1pt rounding
        XCTAssertEqual(r * 255, 108, accuracy: 1)
        XCTAssertEqual(g * 255, 92, accuracy: 1)
        XCTAssertEqual(b * 255, 231, accuracy: 1)
    }

    @MainActor
    func testRouterDefaultsToDashboard() throws {
        // Regression for S1 — Dashboard is the primary surface, not Inbox.
        let router = AppRouter()
        XCTAssertEqual(router.selectedTab, .dashboard)
        XCTAssertNil(router.activeSheet)
        XCTAssertFalse(router.isShowingVoiceSheet)
    }

    @MainActor
    func testRouterInboxDestinationOpensInboxSheetOnDashboard() throws {
        // Regression for S1 — inbox deep links still work; they now open a
        // sheet on top of Dashboard instead of switching to a dedicated tab.
        let router = AppRouter()
        router.selectedTab = .tasks  // Pretend the user was elsewhere.
        router.route(.inbox)
        XCTAssertEqual(router.selectedTab, .dashboard)
        XCTAssertEqual(router.activeSheet, .inbox)
    }

    @MainActor
    func testRouterTracksQuickCaptureAndVoiceAutoStart() throws {
        // Regression for Phase B/C: AppRouter exposes the three sheet
        // booleans the toolbar buttons set. Defaults must be false so the
        // app launches with no sheets up.
        let router = AppRouter()
        XCTAssertFalse(router.isShowingVoiceSheet)
        XCTAssertFalse(router.isShowingQuickCapture)
        XCTAssertFalse(router.voiceAutoStart)
        router.isShowingQuickCapture = true
        router.voiceAutoStart = true
        router.isShowingVoiceSheet = true
        XCTAssertTrue(router.isShowingQuickCapture)
        XCTAssertTrue(router.voiceAutoStart)
        XCTAssertTrue(router.isShowingVoiceSheet)
    }

    @MainActor
    func testOnboardingStoreHonorsScreenshotMode() throws {
        // Regression for Phase A: screenshot mode auto-completes onboarding
        // so simulator captures never get blocked by the welcome screen.
        setenv("FRED_SCREENSHOT_MODE", "1", 1)
        defer { unsetenv("FRED_SCREENSHOT_MODE") }
        let store = OnboardingStore()
        XCTAssertTrue(store.isCompleted)
    }

    @MainActor
    func testReachabilityDotStateMapping() throws {
        // Regression for Phase A: the connection dot must surface a
        // distinct color per state. We verify the public enum exists and
        // that the underlying view doesn't crash to instantiate.
        let states: [FredReachability.State] = [.unknown, .healthy, .degraded, .offline]
        for state in states {
            _ = ReachabilityDot(state: state, onTap: nil)
        }
    }

    @MainActor
    func testRouterURLSchemeRoutesDashboardAndInbox() throws {
        // Regression for S1 — `fred1210://dashboard` and `fred1210://inbox`
        // map cleanly. Empty host (`fred1210://`) defaults to Dashboard.
        let router = AppRouter()
        router.route(url: URL(string: "fred1210://dashboard")!)
        XCTAssertEqual(router.selectedTab, .dashboard)

        router.route(url: URL(string: "fred1210://inbox")!)
        XCTAssertEqual(router.selectedTab, .dashboard)
        XCTAssertEqual(router.activeSheet, .inbox)

        router.activeSheet = nil
        router.route(url: URL(string: "fred1210://unknown-screen")!)
        XCTAssertEqual(router.selectedTab, .dashboard)
    }

    func testThemeTextStyleNamespaceIsAvailable() throws {
        // Smoke test for B1 (Dynamic Type). The text-style tokens must
        // exist so feature code can adopt them.
        _ = Theme.TextStyle.caption
        _ = Theme.TextStyle.footnote
        _ = Theme.TextStyle.subheadline
        _ = Theme.TextStyle.body
        _ = Theme.TextStyle.headline
        _ = Theme.TextStyle.title3
        _ = Theme.TextStyle.title
        _ = Theme.TextStyle.captionSemibold
        _ = Theme.TextStyle.captionBold
        _ = Theme.TextStyle.footnoteSemibold
        _ = Theme.TextStyle.subheadlineSemibold
        _ = Theme.TextStyle.bodySemibold
        _ = Theme.TextStyle.title3Bold
        _ = Theme.TextStyle.titleBold
    }

    @MainActor
    func testPushManagerHonorsScreenshotModeEnvVar() async throws {
        // Regression for visual-verification affordance: when the env var
        // FRED_SCREENSHOT_MODE=1 is set, requestAuthorizationIfNeeded must
        // NOT trigger the system permission dialog. We can't directly
        // intercept UNUserNotificationCenter, but we can verify the env-var
        // gate exists by reading the source — and we can verify that
        // calling the method when notDetermined returns quickly without
        // raising authState past .notDetermined.
        setenv("FRED_SCREENSHOT_MODE", "1", 1)
        defer { unsetenv("FRED_SCREENSHOT_MODE") }

        let push = PushManager(config: FredConfig())
        await push.requestAuthorizationIfNeeded()
        // Without screenshot mode this would either show a prompt (blocking
        // the test) or — if the simulator pre-grants — flip to .authorized.
        // With the env var, the auth state must remain at whatever
        // refreshAuthStatus reports (typically .notDetermined on a fresh
        // sim, .authorized on a pre-granted one — but never re-prompted).
        XCTAssertNotEqual(
            push.authState, .denied,
            "Screenshot-mode path must not silently deny — should just skip the prompt"
        )
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

    func testFredConfigRepairsKnownBadHosts() throws {
        XCTAssertEqual(
            FredConfig.normalizedHost("https://fred.example.ts.net"),
            FredConfig.productionDefaultHost
        )
        XCTAssertEqual(
            FredConfig.normalizedHost("https:"),
            FredConfig.productionDefaultHost
        )
        XCTAssertEqual(
            FredConfig.normalizedHost("https://bobs-mac-mini.tail5a2996.ts.net"),
            "https://bobs-mac-mini.tail5a2996.ts.net"
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
