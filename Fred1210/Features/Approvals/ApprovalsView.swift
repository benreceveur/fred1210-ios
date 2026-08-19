import SwiftUI

struct ApprovalsView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        ApprovalsContentView(client: clientHolder.client)
    }
}

private struct ApprovalsContentView: View {
    @StateObject private var viewModel: ApprovalsViewModel
    @State private var selectedRecommendationId: String?

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: ApprovalsViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header
                    pendingSection
                    if !viewModel.resolved.isEmpty {
                        resolvedSection
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.bgDark)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.runScan() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().tint(Theme.primary)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = viewModel.displayError {
                    ErrorBanner(error: error, onDismiss: viewModel.clearError)
                }
            }
            .sheet(item: Binding(
                get: { selectedRecommendationId.map { RecommendationIdentifier(id: $0) } },
                set: { selectedRecommendationId = $0?.id }
            )) { wrapper in
                RecommendationDetailSheet(recommendationId: wrapper.id)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Fred recommendations")
                .font(Theme.TextStyle.title3Bold)
                .foregroundStyle(Theme.textPrimary)
            Text(lastRunText)
                .font(Theme.TextStyle.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, Theme.Spacing.xs)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("Needs approval", count: viewModel.pending.count)
            if viewModel.pending.isEmpty {
                Card {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.success)
                        Text("No repo recommendations waiting.")
                            .font(Theme.TextStyle.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            } else {
                ForEach(viewModel.pending) { recommendation in
                    Button {
                        selectedRecommendationId = recommendation.id
                    } label: {
                        RecommendationCard(
                            recommendation: recommendation,
                            onApprove: {
                                Haptics.success()
                                Task { await viewModel.approve(recommendation) }
                            },
                            onDismiss: {
                                Haptics.warning()
                                Task { await viewModel.dismiss(recommendation) }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resolvedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("Resolved", count: viewModel.resolved.count)
            ForEach(viewModel.resolved.prefix(5)) { recommendation in
                Button {
                    selectedRecommendationId = recommendation.id
                } label: {
                    RecommendationCard(
                        recommendation: recommendation,
                        compact: true,
                        onApprove: {},
                        onDismiss: {}
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(Theme.TextStyle.captionSemibold)
                .foregroundStyle(Theme.textMuted)
                .tracking(0.5)
                .textCase(.uppercase)
            Spacer()
            Text("\(count)")
                .font(Theme.TextStyle.captionBold)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, Theme.Spacing.xs)
    }

    private var lastRunText: String {
        guard let lastRunAt = viewModel.lastRunAt else { return "No scan has run yet" }
        return "Last scan \(relativeAge(lastRunAt))"
    }

    private func relativeAge(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return iso }
        return date.formatted(.relative(presentation: .numeric))
    }
}

private struct RecommendationIdentifier: Identifiable {
    let id: String
}

private struct RecommendationCard: View {
    let recommendation: FredClient.RepoRecommendation
    var compact = false
    let onApprove: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.target.label)
                            .font(Theme.TextStyle.subheadlineBold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(recommendation.target.owner)/\(recommendation.target.repo)")
                            .font(Theme.TextStyle.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    Text(recommendation.posture.uppercased())
                        .font(Theme.TextStyle.captionBold)
                        .foregroundStyle(postureColor)
                }

                Text(recommendation.reason)
                    .font(Theme.TextStyle.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(compact ? 2 : 4)

                if !compact {
                    Label(recommendation.action, systemImage: "arrow.right.circle")
                        .font(Theme.TextStyle.footnoteSemibold)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)

                    HStack(spacing: Theme.Spacing.md) {
                        metric("Stars", "\(recommendation.snapshot.stars)")
                        metric("Forks", "\(recommendation.snapshot.forks)")
                        if let release = recommendation.snapshot.latestReleaseTag {
                            metric("Release", release)
                        }
                    }

                    HStack(spacing: Theme.Spacing.sm) {
                        Button(action: onApprove) {
                            Label("Approve", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.success)

                        Button(role: .destructive, action: onDismiss) {
                            Label("Dismiss", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text(recommendation.status.capitalized)
                        .font(Theme.TextStyle.captionSemibold)
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Text(value)
                .font(Theme.TextStyle.captionBold)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
    }

    private var postureColor: Color {
        switch recommendation.posture {
        case "adopt": return Theme.success
        case "adapt": return Theme.primary
        case "care": return Theme.warning
        default: return Theme.textMuted
        }
    }
}
