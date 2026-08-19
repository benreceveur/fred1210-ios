import SwiftUI

/// Read-only view of Fred's per-user fact store. Gated behind Face ID
/// because it can contain personal preferences (health, family, finances)
/// that Fred has learned over time.
struct MemoryView: View {
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var facts: [FredClient.MemoryFact] = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var unlocked = false

    var body: some View {
        Group {
            if !unlocked {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "faceid")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.primary)
                    Text("Memory is biometric-gated")
                        .font(Theme.TextStyle.subheadline)
                        .foregroundStyle(Theme.textMuted)
                    Button("Unlock") {
                        Task {
                            unlocked = await Biometrics.authenticate(reason: "View Fred's memory")
                            if unlocked { await load() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bgDark)
            } else {
                factsList
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Auto-prompt on first open so the user doesn't have to tap Unlock twice.
            if !unlocked {
                unlocked = await Biometrics.authenticate(reason: "View Fred's memory")
                if unlocked { await load() }
            }
        }
    }

    @ViewBuilder
    private var factsList: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Theme.error)
                    .listRowBackground(Theme.bgCard)
            }
            if isLoading && facts.isEmpty {
                HStack {
                    ProgressView().tint(Theme.primary)
                    Text("Loading memory…").foregroundStyle(Theme.textMuted)
                }
                .listRowBackground(Theme.bgCard)
            } else if facts.isEmpty {
                Text("No facts recorded yet. Fred builds this up from your chats.")
                    .foregroundStyle(Theme.textMuted)
                    .listRowBackground(Theme.bgCard)
            } else {
                let grouped = Dictionary(grouping: facts, by: { $0.category })
                ForEach(grouped.keys.sorted(), id: \.self) { category in
                    Section(category.uppercased()) {
                        ForEach(grouped[category] ?? []) { fact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fact.fact)
                                    .font(Theme.TextStyle.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(relativeAge(fact.timestamp))
                                    .font(Theme.TextStyle.caption)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .listRowBackground(Theme.bgCard)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .searchable(text: $query, prompt: "Search facts")
        .onChange(of: query) { _ in
            Task { await load() }
        }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            facts = try await clientHolder.client.listMemoryFacts(
                limit: 200,
                query: query.isEmpty ? nil : query
            )
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load memory: \(error.localizedDescription)"
        }
    }

    private func relativeAge(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return iso }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
