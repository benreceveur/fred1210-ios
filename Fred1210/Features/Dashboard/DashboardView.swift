import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        DashboardContentView(client: clientHolder.client)
    }
}

private struct DashboardContentView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var refreshTask: Task<Void, Never>?

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    if viewModel.isLoading && isEmptyFirstLoad {
                        ProgressView()
                            .tint(Theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xxl)
                    } else {
                        cards
                    }
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.bgDark)
            .refreshable { await viewModel.refresh() }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.refresh()
                startAutoRefresh()
            }
            .onDisappear { refreshTask?.cancel() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = viewModel.displayError {
                    ErrorBanner(error: error, onDismiss: viewModel.clearError)
                }
            }
        }
    }

    private var isEmptyFirstLoad: Bool {
        viewModel.snapshot.agentStatus == nil && viewModel.snapshot.transports.isEmpty
    }

    @ViewBuilder
    private var cards: some View {
        let snap = viewModel.snapshot

        if let status = snap.agentStatus {
            StatusCard(title: "Agent Status", icon: "cpu", iconColor: Theme.primary) {
                HStack(spacing: Theme.Spacing.xl) {
                    Stat(label: "Provider", value: status.llm.activeProvider)
                    Stat(label: "Tier", value: status.tier.name)
                    Stat(
                        label: "Sandbox",
                        value: status.sandbox.status.rawValue,
                        color: status.sandbox.status == .running ? Theme.success : Theme.error
                    )
                }
            }
        }

        StatusCard(title: "Today's Usage", icon: "chart.bar.fill", iconColor: Theme.info) {
            HStack(spacing: Theme.Spacing.xl) {
                Stat(label: "Requests", value: "\(snap.usageToday.requests)")
                Stat(label: "Tokens", value: formatNumber(snap.usageToday.tokens))
                Stat(label: "Cost", value: String(format: "$%.2f", snap.usageToday.cost))
                Stat(
                    label: "Errors",
                    value: "\(snap.usageToday.errors)",
                    color: snap.usageToday.errors > 0 ? Theme.error : Theme.success
                )
            }
        }

        if snap.weekCost > 0 {
            StatusCard(title: "Weekly Spend", icon: "wallet.pass", iconColor: Theme.info) {
                HStack { Stat(label: "This Week", value: String(format: "$%.2f", snap.weekCost)) }
            }
        }

        StatusCard(title: "Tasks", icon: "checkmark.square.fill", iconColor: Theme.success) {
            HStack(spacing: Theme.Spacing.xl) {
                Stat(label: "Total", value: "\(snap.tasks.total)")
                Stat(
                    label: "Overdue",
                    value: "\(snap.tasks.overdue)",
                    color: snap.tasks.overdue > 0 ? Theme.warning : Theme.success
                )
                Stat(label: "In Progress", value: "\(snap.tasks.byStatus["in-progress"] ?? 0)")
                Stat(label: "Done", value: "\(snap.tasks.byStatus["done"] ?? 0)")
            }
        }

        ForEach(snap.transports, id: \.transport) { transport in
            StatusCard(
                title: "\(transport.transport.rawValue.capitalized) Transport",
                icon: transport.transport == .slack ? "bubble.left.and.bubble.right.fill" : "paperplane.fill",
                iconColor: transport.degraded ? Theme.warning : Theme.success
            ) {
                HStack(spacing: Theme.Spacing.xl) {
                    Stat(
                        label: "Status",
                        value: transport.degraded ? "Degraded" : "Healthy",
                        color: transport.degraded ? Theme.warning : Theme.success
                    )
                    Stat(label: "Queue", value: "\(transport.queuePending)")
                    Stat(label: "Failures", value: "\(transport.consecutiveFailures)")
                }
            }
        }

        if snap.schedule.entriesCount > 0 {
            StatusCard(title: "Schedule", icon: "clock.fill", iconColor: Theme.primaryLight) {
                HStack(spacing: Theme.Spacing.xl) {
                    Stat(label: "Jobs", value: "\(snap.schedule.entriesCount)")
                    Stat(label: "Reminders", value: "\(snap.schedule.remindersCount)")
                }
            }
        }

        if snap.pipelines.total > 0 {
            StatusCard(title: "Pipelines", icon: "arrow.triangle.branch", iconColor: Theme.primaryLight) {
                HStack { Stat(label: "Total", value: "\(snap.pipelines.total)") }
            }
        }

        if let team = snap.team {
            StatusCard(title: "Team", icon: "person.3.fill", iconColor: Theme.primaryLight) {
                HStack(spacing: Theme.Spacing.xl) {
                    Stat(label: "Active", value: "\(team.active)", color: Theme.success)
                    Stat(
                        label: "Degraded",
                        value: "\(team.degraded)",
                        color: team.degraded > 0 ? Theme.warning : Theme.textMuted
                    )
                    Stat(label: "Total", value: "\(team.total)")
                }
            }
        }

        StatusCard(title: "Memory", icon: "lightbulb.fill", iconColor: Theme.primaryLight) {
            HStack(spacing: Theme.Spacing.xl) {
                Stat(label: "Facts", value: "\(snap.memory.facts)")
                Stat(label: "Conversations", value: "\(snap.memory.conversations)")
                Stat(label: "Last Active", value: formatRelative(snap.memory.lastActive))
            }
        }

        if snap.upstreamMonitors > 0 {
            StatusCard(title: "Upstream", icon: "icloud.and.arrow.down", iconColor: Theme.info) {
                HStack { Stat(label: "Monitors", value: "\(snap.upstreamMonitors)") }
            }
        }

        if let rate = snap.nemoPlannerSuccessRate, snap.nemoDaysTracked > 0 {
            StatusCard(title: "NeMo Planner", icon: "sparkles", iconColor: Theme.primaryLight) {
                HStack(spacing: Theme.Spacing.xl) {
                    Stat(
                        label: "Success",
                        value: "\(Int(rate * 100))%",
                        color: rate >= 0.9 ? Theme.success : Theme.warning
                    )
                    Stat(label: "Days", value: "\(snap.nemoDaysTracked)")
                }
            }
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak viewModel] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10s
                if Task.isCancelled { break }
                await viewModel?.refresh()
            }
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func formatRelative(_ date: Date?) -> String {
        guard let date else { return "never" }
        let diff = date.timeIntervalSinceNow
        let absDiff: Double = diff < 0 ? -diff : diff
        let suffix = diff < 0 ? "ago" : "from now"
        if absDiff < 3600 { return "\(Int(absDiff / 60))m \(suffix)" }
        if absDiff < 172_800 { return "\(Int(absDiff / 3600))h \(suffix)" }
        return "\(Int(absDiff / 86_400))d \(suffix)"
    }
}

// MARK: - Reusable card + stat

struct StatusCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: Theme.Font.md, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            content()
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

struct Stat: View {
    let label: String
    let value: String
    var color: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: Theme.Font.lg, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: Theme.Font.xs))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(minWidth: 60, alignment: .leading)
    }
}
