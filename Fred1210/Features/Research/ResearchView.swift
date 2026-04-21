import SwiftUI

/// Browsable feed of Fred's saved research. Opened from the Dashboard
/// "Recent Research" card — pulls more items than the card shows.
struct ResearchView: View {
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var items: [Components.Schemas.ResearchItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Theme.error)
                    .listRowBackground(Theme.bgCard)
            }
            if isLoading && items.isEmpty {
                HStack {
                    ProgressView().tint(Theme.primary)
                    Text("Loading research…").foregroundStyle(Theme.textMuted)
                }
                .listRowBackground(Theme.bgCard)
            } else if items.isEmpty {
                Text("No research saved yet. Ask Fred to research something and save the findings.")
                    .foregroundStyle(Theme.textMuted)
                    .listRowBackground(Theme.bgCard)
            } else {
                ForEach(items, id: \.id) { item in
                    NavigationLink {
                        ResearchDetailView(itemId: item.id, fallbackTitle: item.title)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: Theme.Font.md, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                            Text(item.savedAt.formatted(.relative(presentation: .numeric)))
                                .font(.system(size: Theme.Font.xs))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .listRowBackground(Theme.bgCard)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .navigationTitle("Research")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Theme.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await clientHolder.client.listRecentResearch(limit: 50)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load research: \(error.localizedDescription)"
        }
    }
}

/// Full markdown body for a single research item. The user can tap
/// "Discuss with Fred" to seed a Chat turn with the item's title as
/// the starting prompt.
struct ResearchDetailView: View {
    let itemId: String
    let fallbackTitle: String
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var detail: FredClient.ResearchDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let detail {
                    Text(detail.title)
                        .font(.system(size: Theme.Font.xl, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(relativeAge(detail.savedAt))
                        .font(.system(size: Theme.Font.xs))
                        .foregroundStyle(Theme.textMuted)
                    Divider().overlay(Theme.border)
                    // Markdown rendering — SwiftUI's AttributedString(markdown:)
                    // handles common cases (headings, lists, links) without a
                    // full CommonMark parser.
                    if let attributed = try? AttributedString(
                        markdown: detail.content,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attributed)
                            .font(.system(size: Theme.Font.md))
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                    } else {
                        Text(detail.content)
                            .font(.system(size: Theme.Font.md))
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                    }
                } else if isLoading {
                    HStack {
                        ProgressView().tint(Theme.primary)
                        Text("Loading…").foregroundStyle(Theme.textMuted)
                    }
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.error)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.bgDark)
        .navigationTitle(fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Theme.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await clientHolder.client.fetchResearchDetail(id: itemId)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load: \(error.localizedDescription)"
        }
    }

    private func relativeAge(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return iso }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .full
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
