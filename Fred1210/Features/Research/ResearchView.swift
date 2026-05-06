import SwiftUI

/// Browsable feed of Fred's saved research. Opened from the Dashboard
/// "Recent Research" card — pulls more items than the card shows.
struct ResearchView: View {
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var items: [Components.Schemas.ResearchItem] = []
    @State private var reviewed: [String: ReviewedResearchRecord] = [:]
    @State private var showingReviewed = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var visibleItems: [Components.Schemas.ResearchItem] {
        showingReviewed ? items : items.filter { reviewed[$0.id] == nil }
    }

    var body: some View {
        List {
            Section {
                Toggle("Show reviewed research", isOn: $showingReviewed)
                    .foregroundStyle(Theme.textPrimary)
            }
            .listRowBackground(Theme.bgCard)

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
            } else if visibleItems.isEmpty {
                Text("No research saved yet. Ask Fred to research something and save the findings.")
                    .foregroundStyle(Theme.textMuted)
                    .listRowBackground(Theme.bgCard)
            } else {
                ForEach(visibleItems, id: \.id) { item in
                    NavigationLink {
                        ResearchDetailView(itemId: item.id, fallbackTitle: item.title)
                    } label: {
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: Theme.Font.md, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(2)
                                Text(item.savedAt.formatted(.relative(presentation: .numeric)))
                                    .font(.system(size: Theme.Font.xs))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            if let decision = reviewed[item.id]?.decision {
                                Text(decision.rawValue.uppercased())
                                    .font(.system(size: Theme.Font.xs, weight: .bold))
                                    .foregroundStyle(Theme.success)
                            }
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
            reviewed = await ReviewedResearchStore.shared.records()
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
    @State private var decision: ReviewedResearchRecord.Decision?
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
                    decisionControls(for: detail)
                    decisionSummary(for: detail)
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
        .toolbar {
            if let detail {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await createFollowUpTask(for: detail) }
                    } label: {
                        Image(systemName: "checklist.checked")
                            .foregroundStyle(Theme.primary)
                    }
                    .accessibilityLabel("Create follow-up task")
                }
            }
        }
        .task {
            await load()
        }
    }

    private func decisionSummary(for detail: FredClient.ResearchDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let recommendation = firstMatchingLine(in: detail.content, markers: ["recommendation", "recommend", "action"]) {
                summaryBlock(
                    title: "Recommendation",
                    icon: "sparkles",
                    color: Theme.primary,
                    body: recommendation
                )
            }

            let bullets = extractBullets(from: detail.content).prefix(3)
            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Label("Key points", systemImage: "list.bullet.rectangle")
                        .font(.system(size: Theme.Font.xs, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                    ForEach(Array(bullets), id: \.self) { bullet in
                        Text("• \(bullet)")
                            .font(.system(size: Theme.Font.sm))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.bgInput.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }

            let links = extractLinks(from: detail.content).prefix(3)
            if !links.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Label("Sources", systemImage: "link")
                        .font(.system(size: Theme.Font.xs, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                    ForEach(Array(links), id: \.self) { link in
                        if let url = URL(string: link) {
                            Link(link, destination: url)
                                .font(.system(size: Theme.Font.xs))
                                .foregroundStyle(Theme.info)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.bgInput.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
        }
    }

    private func decisionControls(for detail: FredClient.ResearchDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                decisionButton("Adopt", .adopt, Theme.success, detail)
                decisionButton("Adapt", .adapt, Theme.primary, detail)
                decisionButton("Ignore", .ignore, Theme.textMuted, detail)
            }
            if let decision {
                Label("Marked \(decision.rawValue)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: Theme.Font.xs, weight: .semibold))
                    .foregroundStyle(Theme.success)
            }
        }
    }

    private func decisionButton(
        _ title: String,
        _ value: ReviewedResearchRecord.Decision,
        _ color: Color,
        _ detail: FredClient.ResearchDetail
    ) -> some View {
        Button {
            Task { await mark(detail, as: value) }
        } label: {
            Text(title)
                .font(.system(size: Theme.Font.xs, weight: .bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }

    private func summaryBlock(title: String, icon: String, color: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(title, systemImage: icon)
                .font(.system(size: Theme.Font.xs, weight: .bold))
                .foregroundStyle(color)
            Text(body)
                .font(.system(size: Theme.Font.sm))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(4)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.bgInput.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private func createFollowUpTask(for detail: FredClient.ResearchDetail) async {
        do {
            try await clientHolder.client.createTaskRaw([
                "title": "Review research: \(detail.title)",
                "description": "Created from iOS research detail \(detail.id)",
                "status": "todo",
                "priority": "medium"
            ])
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't create task: \(error.localizedDescription)"
        }
    }

    private func mark(_ detail: FredClient.ResearchDetail, as nextDecision: ReviewedResearchRecord.Decision) async {
        await ReviewedResearchStore.shared.mark(id: detail.id, title: detail.title, decision: nextDecision)
        decision = nextDecision
    }

    private func firstMatchingLine(in content: String, markers: [String]) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let cleaned = cleanMarkdownLine(line)
            let lower = cleaned.lowercased()
            if markers.contains(where: { lower.contains($0) }), cleaned.count > 12 {
                return cleaned
            }
        }
        return nil
    }

    private func extractBullets(from content: String) -> [String] {
        content.components(separatedBy: .newlines)
            .map(cleanMarkdownLine)
            .filter { !$0.isEmpty }
            .filter { line in
                content.contains("- \(line)") || content.contains("* \(line)") || line.contains(":")
            }
    }

    private func extractLinks(from content: String) -> [String] {
        let pattern = #"https?://[^\s\)\]]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex.matches(in: content, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: content) else { return nil }
            return String(content[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        }
    }

    private func cleanMarkdownLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[-*#\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await clientHolder.client.fetchResearchDetail(id: itemId)
            decision = await ReviewedResearchStore.shared.records()[itemId]?.decision
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
