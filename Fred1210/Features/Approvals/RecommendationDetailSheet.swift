import SwiftUI

struct RecommendationDetailSheet: View {
    let recommendationId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var recommendation: FredClient.RepoRecommendation?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let recommendation {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            header(recommendation)
                            timeline(recommendation)
                            details(recommendation)
                            actionButtons(recommendation)
                        }
                        .padding(Theme.Spacing.md)
                    }
                } else if isLoading {
                    ProgressView()
                        .tint(Theme.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text(errorMessage ?? "Recommendation unavailable")
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            }
            .background(Theme.bgDark)
            .navigationTitle("Recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func header(_ item: FredClient.RepoRecommendation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(item.target.label)
                    .font(.system(size: Theme.Font.xl, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(item.target.owner)/\(item.target.repo)")
                    .font(.system(size: Theme.Font.sm))
                    .foregroundStyle(Theme.textMuted)
                Text(item.posture.uppercased())
                    .font(.system(size: Theme.Font.xs, weight: .bold))
                    .foregroundStyle(postureColor(item.posture))
            }
        }
    }

    private func timeline(_ item: FredClient.RepoRecommendation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Thread")
                    .font(.system(size: Theme.Font.xs, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .tracking(0.5)
                    .textCase(.uppercase)
                threadRow("Found", "Fred detected a repo signal worth reviewing.", "sparkles", Theme.primary)
                threadRow("Why", item.reason, "questionmark.circle", Theme.warning)
                threadRow("Recommendation", item.action, "arrow.right.circle", Theme.success)
                if let release = item.snapshot.latestReleaseTag {
                    threadRow("Release", release, "shippingbox", Theme.info)
                }
                if let message = item.snapshot.latestCommitMessage, !message.isEmpty {
                    threadRow("Latest commit", message, "number", Theme.textMuted)
                }
            }
        }
    }

    private func details(_ item: FredClient.RepoRecommendation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Evidence")
                    .font(.system(size: Theme.Font.xs, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .tracking(0.5)
                    .textCase(.uppercase)
                LabeledContent("Status", value: item.status.capitalized)
                LabeledContent("Stars", value: "\(item.snapshot.stars)")
                LabeledContent("Forks", value: "\(item.snapshot.forks)")
                if let url = URL(string: item.snapshot.url) {
                    Link("Open GitHub", destination: url)
                        .foregroundStyle(Theme.info)
                }
            }
            .foregroundStyle(Theme.textPrimary)
        }
    }

    private func actionButtons(_ item: FredClient.RepoRecommendation) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                Task { await resolve(item, action: "approve") }
            } label: {
                Label("Approve", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.success)
            .disabled(item.status != "pending")

            Button(role: .destructive) {
                Task { await resolve(item, action: "dismiss") }
            } label: {
                Label("Dismiss", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(item.status != "pending")
        }
    }

    private func threadRow(_ title: String, _ detail: String, _ icon: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: Theme.Font.sm, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: Theme.Font.xs))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dashboard = try await clientHolder.client.fetchRepoIntelligence()
            recommendation = dashboard.recommendations.first { $0.id == recommendationId }
            errorMessage = recommendation == nil ? "Recommendation not found" : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolve(_ item: FredClient.RepoRecommendation, action: String) async {
        do {
            recommendation = try await clientHolder.client.resolveRepoRecommendation(id: item.id, action: action)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func postureColor(_ posture: String) -> Color {
        switch posture {
        case "adopt": return Theme.success
        case "adapt": return Theme.primary
        case "care": return Theme.warning
        default: return Theme.textMuted
        }
    }
}
