import SwiftUI

/// Sheet lets the user pick a configured GH sync repo and tags the Fred
/// task with `gh-create:<owner>/<repo>`. The next sync tick (or an
/// immediate manual trigger) files an upstream issue.
struct PushToGithubSheet: View {
    let task: Components.Schemas.Task
    let onPush: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var repos: [String] = []
    @State private var customRepo = ""
    @State private var selected: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Push this task upstream as a new GitHub issue") {
                    Text(task.title)
                        .font(.system(size: Theme.Font.md, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .listRowBackground(Theme.bgCard)

                if isLoading {
                    Section {
                        HStack {
                            ProgressView().tint(Theme.primary)
                            Text("Loading configured repos…")
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .listRowBackground(Theme.bgCard)
                } else if !repos.isEmpty {
                    Section("Configured repos") {
                        ForEach(repos, id: \.self) { repo in
                            Button {
                                selected = repo
                            } label: {
                                HStack {
                                    Image(systemName: selected == repo ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(Theme.primary)
                                    Text(repo)
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.bgCard)
                }

                Section("Custom repo (owner/repo)") {
                    TextField("e.g. benreceveur/ScratchRepo", text: $customRepo)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: customRepo) { newValue in
                            if !newValue.isEmpty { selected = newValue }
                        }
                }
                .listRowBackground(Theme.bgCard)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(Theme.bgCard)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bgDark)
            .navigationTitle("Push to GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Push") {
                        guard let repo = chosenRepo() else {
                            errorMessage = "Pick a repo or type owner/repo"
                            return
                        }
                        onPush(repo)
                        dismiss()
                    }
                    .disabled(chosenRepo() == nil)
                }
            }
            .task {
                isLoading = true
                do {
                    let (r, _) = try await clientHolder.client.listConfiguredSyncRepos()
                    repos = r
                } catch {
                    errorMessage = "Couldn't load configured repos: \(error.localizedDescription)"
                }
                isLoading = false
            }
        }
    }

    private func chosenRepo() -> String? {
        let trimmed = customRepo.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed.contains("/") { return trimmed }
        if let selected, selected.contains("/") { return selected }
        return nil
    }
}
