import SwiftUI

struct StandaloneTaskDetailView: View {
    let taskId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var task: Components.Schemas.Task?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let task {
                    List {
                        Section {
                            Text(task.title)
                                .font(.system(size: Theme.Font.lg, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.bgCard)

                        if let desc = task.description, !desc.isEmpty {
                            Section("Description") {
                                Text(desc)
                                    .font(.system(size: Theme.Font.md))
                                    .foregroundStyle(Theme.textPrimary)
                                    .textSelection(.enabled)
                            }
                            .listRowBackground(Theme.bgCard)
                        }

                        Section("Timeline") {
                            TaskTimelineView(task: task)
                        }
                        .listRowBackground(Theme.bgCard)

                        Section("Receipt") {
                            LabeledContent("Status", value: task.status.rawValue.uppercased())
                            LabeledContent("Priority", value: task.priority.rawValue.uppercased())
                            LabeledContent("Updated", value: task.updatedAt.formatted(.dateTime))
                            if let tags = task.tags, !tags.isEmpty {
                                LabeledContent("Tags", value: tags.joined(separator: ", "))
                            }
                        }
                        .listRowBackground(Theme.bgCard)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                } else if isLoading {
                    ProgressView()
                        .tint(Theme.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 42))
                            .foregroundStyle(Theme.warning)
                        Text(errorMessage ?? "Task unavailable")
                            .font(.system(size: Theme.Font.md))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.bgDark)
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            task = try await clientHolder.client.getTask(id: taskId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
