import SwiftUI

struct FredInboxView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        FredInboxContentView(client: clientHolder.client)
    }
}

private struct FredInboxContentView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: FredInboxViewModel

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: FredInboxViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header
                    attentionStrip
                    lane(
                        title: "Needs Bob",
                        icon: "person.crop.circle.badge.exclamationmark",
                        color: Theme.warning,
                        count: viewModel.needsBobTasks.count,
                        empty: "No decisions waiting"
                    ) {
                        ForEach(viewModel.needsBobTasks.prefix(4), id: \.id) { task in
                            inboxRow(
                                title: task.title,
                                detail: "\(task.status.rawValue) · \(task.priority.rawValue)",
                                icon: "checklist",
                                color: task.priority == .urgent ? Theme.error : Theme.warning
                            ) {
                                router.route(.task(task.id))
                            }
                        }
                    }
                    lane(
                        title: "Approvals",
                        icon: "checkmark.seal",
                        color: Theme.primary,
                        count: viewModel.pendingRecommendations.count,
                        empty: "No recommendations waiting"
                    ) {
                        ForEach(viewModel.pendingRecommendations.prefix(4)) { recommendation in
                            inboxRow(
                                title: recommendation.target.label,
                                detail: "\(recommendation.posture) · \(recommendation.reason)",
                                icon: "sparkles",
                                color: Theme.primary
                            ) {
                                router.route(.recommendation(recommendation.id))
                            }
                        }
                    }
                    lane(
                        title: "Fred Working",
                        icon: "bolt.horizontal.circle",
                        color: Theme.info,
                        count: viewModel.fredWorkingTasks.count,
                        empty: "No active Fred-owned work"
                    ) {
                        ForEach(viewModel.fredWorkingTasks.prefix(4), id: \.id) { task in
                            inboxRow(
                                title: task.title,
                                detail: task.updatedAt.formatted(.relative(presentation: .numeric)),
                                icon: "timer",
                                color: Theme.info
                            ) {
                                router.route(.task(task.id))
                            }
                        }
                    }
                    lane(
                        title: "Health",
                        icon: "waveform.path.ecg",
                        color: viewModel.degradedTransports.isEmpty ? Theme.success : Theme.error,
                        count: viewModel.degradedTransports.count,
                        empty: "All systems reporting healthy"
                    ) {
                        ForEach(viewModel.degradedTransports.prefix(4), id: \.transport) { transport in
                            inboxRow(
                                title: "\(transport.transport.rawValue.capitalized) degraded",
                                detail: transport.degradedReasons.joined(separator: ", "),
                                icon: "exclamationmark.triangle",
                                color: Theme.error
                            ) {
                                router.route(.health)
                            }
                        }
                    }
                    lane(
                        title: "Recent Research",
                        icon: "doc.text.magnifyingglass",
                        color: Theme.success,
                        count: viewModel.research.count,
                        empty: "No research saved yet"
                    ) {
                        ForEach(viewModel.research.prefix(4), id: \.id) { item in
                            inboxRow(
                                title: item.title,
                                detail: item.savedAt.formatted(.relative(presentation: .numeric)),
                                icon: "doc.text",
                                color: Theme.success
                            ) {
                                router.route(.research(item.id, item.title))
                            }
                        }
                    }
                    lane(
                        title: "Recently Done",
                        icon: "checkmark.circle",
                        color: Theme.success,
                        count: viewModel.completedTasks.count,
                        empty: "Nothing completed recently"
                    ) {
                        ForEach(viewModel.completedTasks.prefix(4), id: \.id) { task in
                            inboxRow(
                                title: task.title,
                                detail: "Completed \(task.updatedAt.formatted(.relative(presentation: .numeric)))",
                                icon: "checkmark.seal",
                                color: Theme.success
                            ) {
                                router.route(.task(task.id))
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.bgDark)
            .navigationTitle("Fred")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = viewModel.displayError {
                    ErrorBanner(error: error, onDismiss: viewModel.clearError)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fred Inbox")
                    .font(.system(size: Theme.Font.xxl, weight: .bold))
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
    }

    private var attentionStrip: some View {
        HStack(spacing: Theme.Spacing.md) {
            attentionMetric("Needs you", "\(viewModel.attentionCount)", Theme.warning)
            attentionMetric("Working", "\(viewModel.fredWorkingTasks.count)", Theme.info)
            attentionMetric("Done", "\(viewModel.completedTasks.prefix(20).count)", Theme.success)
        }
    }

    private func attentionMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: Theme.Font.xl, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: Theme.Font.xs, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func lane<Content: View>(
        title: String,
        icon: String,
        color: Color,
        count: Int,
        empty: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: Theme.Font.xs, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: Theme.Font.xs, weight: .bold))
                        .foregroundStyle(count == 0 ? Theme.textMuted : color)
                }
                if count == 0 {
                    Text(empty)
                        .font(.system(size: Theme.Font.sm))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.vertical, Theme.Spacing.xs)
                } else {
                    content()
                }
            }
        }
    }

    private func inboxRow(
        title: String,
        detail: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: Theme.Font.sm, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: Theme.Font.xs))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.bgInput.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
