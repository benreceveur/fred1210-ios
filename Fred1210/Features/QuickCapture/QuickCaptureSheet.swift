import SwiftUI

/// One-line task capture sheet. Lives on every tab so users can dump a
/// thought without first navigating to Tasks. Adds a task at default
/// (medium) priority — the user can refine via the Tasks tab later.
struct QuickCaptureSheet: View {
    @EnvironmentObject var clientHolder: ClientHolder
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var priority: Components.Schemas.CreateTaskRequest.PriorityPayload = .medium
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("What's on your mind?")
                    .font(Theme.TextStyle.captionSemibold)
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)

                TextField("Task title", text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(Theme.TextStyle.body)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(Theme.bgInput)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { Task { await save() } }

                priorityPicker

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.TextStyle.footnote)
                        .foregroundStyle(Theme.error)
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.bgDark)
            .navigationTitle("Quick capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Theme.primary)
                        } else {
                            Text("Save").font(Theme.TextStyle.bodySemibold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { titleFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    private var priorityPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Priority")
                .font(Theme.TextStyle.captionSemibold)
                .foregroundStyle(Theme.textMuted)
                .textCase(.uppercase)
            HStack(spacing: Theme.Spacing.sm) {
                priorityChip(.low, label: "Low", icon: "arrow.down")
                priorityChip(.medium, label: "Medium", icon: "minus")
                priorityChip(.high, label: "High", icon: "arrow.up")
                priorityChip(.urgent, label: "Urgent", icon: "flame.fill")
            }
        }
    }

    private func priorityChip(
        _ value: Components.Schemas.CreateTaskRequest.PriorityPayload,
        label: String,
        icon: String
    ) -> some View {
        let selected = priority == value
        return Button {
            priority = value
            Haptics.tap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(Theme.TextStyle.footnoteSemibold)
            }
            .foregroundStyle(selected ? .white : Theme.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(selected ? Theme.primary : Theme.bgInput)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) priority")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            let request = Components.Schemas.CreateTaskRequest(
                title: trimmed,
                priority: priority
            )
            _ = try await clientHolder.client.createTask(request)
            Haptics.success()
            dismiss()
        } catch {
            Haptics.failure()
            errorMessage = (error as NSError).localizedDescription
        }
    }
}
