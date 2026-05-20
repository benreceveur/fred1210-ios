import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        DashboardContentView(client: clientHolder.client)
    }
}

private struct DashboardContentView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var reachability: FredReachability
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
                    actionCenterCard
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
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        router.activeSheet = .inbox
                    } label: {
                        Image(systemName: "tray.full")
                            .accessibilityLabel("Open inbox")
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Dashboard")
                            .font(Theme.TextStyle.headline)
                            .foregroundStyle(Theme.textPrimary)
                        ReachabilityDot(state: reachability.state) {
                            Task { await reachability.pollNow() }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        router.isShowingQuickCapture = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityLabel("Quick capture task")
                    }
                    Button {
                        router.isShowingVoiceSheet = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .accessibilityLabel("Ask Fred by voice")
                            .accessibilityHint("Long-press to start recording immediately")
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            router.voiceAutoStart = true
                            router.isShowingVoiceSheet = true
                        }
                    )
                }
            }
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
        // TimelineView re-renders every 30s so the "Updated Ns ago" stays
        // fresh without having to publish a tick on the view model.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(Theme.TextStyle.title3Bold)
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 4) {
                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                        if let updatedAgo = updatedAgoText(now: context.date) {
                            Text("·")
                            Text(updatedAgo)
                                .accessibilityLabel("Updated \(updatedAgo)")
                        }
                    }
                    .font(Theme.TextStyle.caption)
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
    }

    /// Compact "Updated 12s ago" / "Updated 2m ago" string. Returns nil when
    /// we don't yet have a refresh timestamp — header omits the "·" cleanly.
    private func updatedAgoText(now: Date) -> String? {
        guard let then = viewModel.lastRefreshedAt else { return nil }
        let seconds = max(0, Int(now.timeIntervalSince(then)))
        if seconds < 60 { return "updated \(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "updated \(minutes)m ago" }
        let hours = minutes / 60
        return "updated \(hours)h ago"
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

    private var actionCenterCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Image(systemName: "rectangle.3.group.bubble.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                    Text("Action center")
                        .font(Theme.TextStyle.captionSemibold)
                        .foregroundStyle(Theme.textMuted)
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(needsBob.count + fredWorking.count + healthIssues.count)")
                        .font(Theme.TextStyle.captionBold)
                        .foregroundStyle(Theme.textSecondary)
                }

                actionLane(
                    title: "Needs Bob",
                    icon: "person.crop.circle.badge.exclamationmark",
                    color: Theme.warning,
                    items: needsBob.map { $0.title },
                    empty: "No approvals waiting",
                    emptyAction: ("Open approvals", { router.selectedTab = .review })
                )
                actionLane(
                    title: "Fred Working",
                    icon: "bolt.horizontal.circle",
                    color: Theme.primary,
                    items: fredWorking.map { $0.title },
                    empty: "No active Fred tasks",
                    emptyAction: ("Ask Fred to start something", { router.selectedTab = .chat })
                )
                actionLane(
                    title: "Health",
                    icon: "waveform.path.ecg",
                    color: healthIssues.isEmpty ? Theme.success : Theme.error,
                    items: healthIssues,
                    empty: "All transports healthy",
                    emptyAction: nil
                )
                actionLane(
                    title: "Recently Done",
                    icon: "checkmark.seal",
                    color: Theme.success,
                    items: recentlyDone.map { $0.title },
                    empty: "Nothing completed recently",
                    emptyAction: ("Open tasks", { router.selectedTab = .tasks })
                )
            }
        }
    }

    private var needsBob: [Components.Schemas.Task] {
        viewModel.snapshot.recentTasks
            .filter { $0.status == .review || $0.priority == .urgent }
            .prefix(3)
            .map { $0 }
    }

    private var fredWorking: [Components.Schemas.Task] {
        viewModel.snapshot.recentTasks
            .filter {
                $0.status == .inProgress
                    && (($0.assignee ?? "").lowercased().contains("fred") || ($0.assignee ?? "").isEmpty)
            }
            .prefix(3)
            .map { $0 }
    }

    private var recentlyDone: [Components.Schemas.Task] {
        viewModel.snapshot.recentTasks
            .filter { $0.status == .done }
            .prefix(3)
            .map { $0 }
    }

    private var healthIssues: [String] {
        viewModel.snapshot.transports
            .filter { $0.degraded }
            .prefix(3)
            .map { "\($0.transport.rawValue.capitalized) degraded" }
    }

    private func actionLane(
        title: String,
        icon: String,
        color: Color,
        items: [String],
        empty: String,
        emptyAction: (label: String, action: () -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(title)
                    .font(Theme.TextStyle.footnoteSemibold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(items.isEmpty ? "0" : "\(items.count)")
                    .font(Theme.TextStyle.captionBold)
                    .foregroundStyle(items.isEmpty ? Theme.textMuted : color)
            }
            if items.isEmpty {
                if let emptyAction {
                    Button {
                        Haptics.tap()
                        emptyAction.action()
                    } label: {
                        HStack(spacing: 4) {
                            Text(empty)
                                .font(Theme.TextStyle.caption)
                                .foregroundStyle(Theme.textMuted)
                            Text("·")
                                .font(Theme.TextStyle.caption)
                                .foregroundStyle(Theme.textMuted)
                            Text(emptyAction.label)
                                .font(Theme.TextStyle.captionSemibold)
                                .foregroundStyle(Theme.primary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                        }
                        .padding(.leading, 26)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(empty). \(emptyAction.label).")
                } else {
                    Text(empty)
                        .font(Theme.TextStyle.caption)
                        .foregroundStyle(Theme.textMuted)
                        .padding(.leading, 26)
                }
            } else {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(Theme.TextStyle.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .padding(.leading, 26)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.bgInput.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

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
                        .font(Theme.TextStyle.captionSemibold)
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
                        .font(Theme.TextStyle.footnote)
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
                .font(Theme.TextStyle.footnote)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(value)")
                .font(Theme.TextStyle.footnoteSemibold)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func transportRow(_ transport: Components.Schemas.TransportHealth) -> some View {
        HStack {
            Circle()
                .fill(transport.degraded ? Theme.warning : Theme.success)
                .frame(width: 6, height: 6)
            Text(transport.transport.rawValue.capitalized)
                .font(Theme.TextStyle.footnote)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(transport.degraded ? "Degraded" : "OK")
                .font(Theme.TextStyle.captionSemibold)
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
                            .font(Theme.TextStyle.captionSemibold)
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
                            .font(Theme.TextStyle.footnote)
                            .foregroundStyle(Theme.textMuted)
                    } else {
                        ForEach(viewModel.snapshot.recentResearch.prefix(3)) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.title)
                                    .font(Theme.TextStyle.footnote)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.savedAt.formatted(.relative(presentation: .numeric)))
                                    .font(Theme.TextStyle.caption)
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
