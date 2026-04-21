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
                VStack(spacing: Theme.Spacing.md) {
                    greetingHeader
                    topStatsRow
                    teamCard
                    secondaryStatsRow
                    researchCard
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
            }
            .background(Theme.bgDark)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await viewModel.refresh() }
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

    // MARK: - Header

    @ViewBuilder
    private var greetingHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: Theme.Font.xl, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: Theme.Font.xs))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            if viewModel.isLoading {
                ProgressView().tint(Theme.primary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.top, Theme.Spacing.xs)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Up late"
        }
    }

    // MARK: - Top stats row — Today + Tasks

    private var topStatsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            todayCard
            tasksCard
        }
    }

    private var todayCard: some View {
        let cal = viewModel.snapshot.calendar
        let statText: String
        let hint: String?
        if !cal.configured {
            statText = "—"
            hint = "Calendar not configured"
        } else if let summary = cal.nextSummary {
            statText = "\(cal.count)"
            hint = "Next: \(summary)"
        } else {
            statText = "\(cal.count)"
            hint = cal.count == 0 ? "Nothing scheduled" : nil
        }
        return StatCard(
            icon: "calendar",
            iconTint: Theme.info,
            stat: statText,
            label: "Today",
            hint: hint
        )
    }

    private var tasksCard: some View {
        let tasks = viewModel.snapshot.tasks
        let urgent = tasks.byStatus["in-progress"] ?? 0
        let hint = tasks.overdue > 0
            ? "\(tasks.overdue) overdue"
            : urgent > 0 ? "\(urgent) in progress" : nil
        return StatCard(
            icon: "checklist",
            iconTint: tasks.overdue > 0 ? Theme.warning : Theme.primary,
            stat: "\(tasks.total)",
            label: "Tasks",
            hint: hint
        )
    }

    // MARK: - Team status card

    private var teamCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: "network")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(teamTint)
                    Text("Team & providers")
                        .font(.system(size: Theme.Font.xs, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Spacer()
                }
                if let team = viewModel.snapshot.team {
                    teamRow(label: "Active", value: team.active, color: Theme.success)
                    if team.degraded > 0 {
                        teamRow(label: "Degraded", value: team.degraded, color: Theme.warning)
                    }
                    if team.offline > 0 {
                        teamRow(label: "Offline", value: team.offline, color: Theme.error)
                    }
                } else {
                    Text("Team status unavailable")
                        .font(.system(size: Theme.Font.sm))
                        .foregroundStyle(Theme.textMuted)
                }
                if !viewModel.snapshot.transports.isEmpty {
                    Divider().overlay(Theme.border)
                    ForEach(viewModel.snapshot.transports, id: \.transport) { transport in
                        transportRow(transport)
                    }
                }
            }
        }
    }

    private var teamTint: Color {
        guard let team = viewModel.snapshot.team else { return Theme.textMuted }
        if team.offline > 0 { return Theme.error }
        if team.degraded > 0 { return Theme.warning }
        return Theme.success
    }

    private func teamRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: Theme.Font.sm))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(value)")
                .font(.system(size: Theme.Font.sm, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func transportRow(_ transport: Components.Schemas.TransportHealth) -> some View {
        HStack {
            Circle()
                .fill(transport.degraded ? Theme.warning : Theme.success)
                .frame(width: 6, height: 6)
            Text(transport.transport.rawValue.capitalized)
                .font(.system(size: Theme.Font.sm))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(transport.degraded ? "Degraded" : "OK")
                .font(.system(size: Theme.Font.xs, weight: .semibold))
                .foregroundStyle(transport.degraded ? Theme.warning : Theme.success)
        }
    }

    // MARK: - Secondary stats row — Memory + Automations

    private var secondaryStatsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(
                icon: "brain",
                iconTint: Theme.primary,
                stat: "\(viewModel.snapshot.memory.facts)",
                label: "Memory facts",
                hint: "\(viewModel.snapshot.memory.conversations) conversations"
            )
            StatCard(
                icon: "sparkles",
                iconTint: Theme.info,
                stat: "\(viewModel.snapshot.automations.enabled)",
                label: "Agent loops",
                hint: viewModel.snapshot.automations.total > viewModel.snapshot.automations.enabled
                    ? "of \(viewModel.snapshot.automations.total) total"
                    : "all enabled"
            )
        }
    }

    // MARK: - Research card

    private var researchCard: some View {
        NavigationLink {
            ResearchView()
        } label: {
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                        Text("Recent research")
                            .font(.system(size: Theme.Font.xs, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                    if viewModel.snapshot.recentResearch.isEmpty {
                        Text("Nothing saved yet. Ask Fred to research something and save the findings.")
                            .font(.system(size: Theme.Font.sm))
                            .foregroundStyle(Theme.textMuted)
                    } else {
                        ForEach(viewModel.snapshot.recentResearch.prefix(3)) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.title)
                                    .font(.system(size: Theme.Font.sm))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.savedAt.formatted(.relative(presentation: .numeric)))
                                    .font(.system(size: Theme.Font.xs))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Auto refresh

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak viewModel] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if Task.isCancelled { return }
                await viewModel?.refresh()
            }
        }
    }
}
