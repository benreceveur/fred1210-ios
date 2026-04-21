import SwiftUI
import UIKit

/// Detail view for a single task — shown as a sheet when the user taps a
/// row in TaskListView. Surfaces everything the row hides: full description,
/// all attachments (tap for fullscreen), tags, timestamps, GitHub linkage.
struct TaskDetailView: View {
    let taskId: String
    let viewModel: TaskListViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var clientHolder: ClientHolder

    @State private var fullscreenAttachmentData: Data?

    private var task: Components.Schemas.Task? {
        viewModel.tasks.first(where: { $0.id == taskId })
    }

    var body: some View {
        NavigationStack {
            if let task = task {
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

                    Section("Status & priority") {
                        LabeledContent("Status", value: task.status.rawValue.uppercased())
                        LabeledContent("Priority", value: task.priority.rawValue.uppercased())
                        if let tags = task.tags, !tags.isEmpty {
                            LabeledContent("Tags", value: tags.joined(separator: ", "))
                                .lineLimit(3)
                        }
                    }
                    .listRowBackground(Theme.bgCard)

                    // GitHub deep link when this task is mirrored from an
                    // upstream issue (external:<owner>/<repo>#<n> tag).
                    if let ghUrl = githubUrl(from: task.tags) {
                        Section("GitHub") {
                            Link(destination: ghUrl) {
                                Label {
                                    Text(ghUrl.path.dropFirst())
                                        .foregroundStyle(Theme.primary)
                                        .font(.system(size: Theme.Font.sm))
                                } icon: {
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                        }
                        .listRowBackground(Theme.bgCard)
                    }

                    if let attachments = task.attachments, !attachments.isEmpty {
                        Section("Attachments · \(attachments.count)") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(attachments, id: \.id) { att in
                                        TaskAttachmentDetailTile(
                                            taskId: task.id,
                                            attachment: att,
                                            onTap: { data in fullscreenAttachmentData = data }
                                        )
                                    }
                                }
                            }
                        }
                        .listRowBackground(Theme.bgCard)
                    }

                    Section("Timestamps") {
                        LabeledContent("Created", value: task.createdAt.formatted(.dateTime))
                        LabeledContent("Updated", value: task.updatedAt.formatted(.dateTime))
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Actions") {
                        Menu("Change status") {
                            statusAction("Inbox", "tray", .inbox, for: task)
                            statusAction("To Do", "circle", .todo, for: task)
                            statusAction("In Progress", "arrow.triangle.2.circlepath", .inProgress, for: task)
                            statusAction("Review", "eye", .review, for: task)
                            statusAction("Done", "checkmark.circle", .done, for: task)
                        }
                        Button(role: .destructive) {
                            Task {
                                let ok = await Biometrics.authenticate(reason: "Delete task")
                                guard ok else { return }
                                await viewModel.delete(task)
                                await MainActor.run { dismiss() }
                            }
                        } label: {
                            Label("Delete task", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Theme.bgCard)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Theme.bgDark)
                .navigationTitle("Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(item: Binding(
                    get: { fullscreenAttachmentData.map { AttachmentBlob(data: $0) } },
                    set: { fullscreenAttachmentData = $0?.data }
                )) { blob in
                    AttachmentFullscreenView(data: blob.data) {
                        fullscreenAttachmentData = nil
                    }
                }
            } else {
                // Task disappeared (deleted while sheet was open)
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.textMuted)
                    Text("Task no longer exists")
                        .foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bgDark)
            }
        }
    }

    @ViewBuilder
    private func statusAction(
        _ title: String,
        _ icon: String,
        _ status: Components.Schemas.UpdateTaskRequest.StatusPayload,
        for task: Components.Schemas.Task
    ) -> some View {
        Button {
            Task { await viewModel.setStatus(task, to: status) }
        } label: {
            Label(title, systemImage: icon)
        }
    }

    /// Pull an `external:<owner>/<repo>#<n>` tag and turn it into a
    /// navigable github.com URL.
    private func githubUrl(from tags: [String]?) -> URL? {
        guard let ext = tags?.first(where: { $0.hasPrefix("external:") }) else { return nil }
        let slug = ext.replacingOccurrences(of: "external:", with: "")
        // slug format: owner/repo#n
        let parts = slug.components(separatedBy: "#")
        guard parts.count == 2 else { return nil }
        return URL(string: "https://github.com/\(parts[0])/issues/\(parts[1])")
    }
}

private struct AttachmentBlob: Identifiable {
    let data: Data
    var id: Int { data.count }
}

private struct TaskAttachmentDetailTile: View {
    let taskId: String
    let attachment: Components.Schemas.TaskAttachment
    let onTap: (Data) -> Void
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var image: UIImage?
    @State private var rawData: Data?

    var body: some View {
        Button {
            if let data = rawData { onTap(data) }
        } label: {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.bgInput)
                        .frame(width: 88, height: 88)
                        .overlay {
                            ProgressView().tint(Theme.primary)
                        }
                }
            }
        }
        .disabled(image == nil)
        .task {
            guard image == nil else { return }
            if let data = try? await clientHolder.client.fetchAttachmentData(
                taskId: taskId, attachmentId: attachment.id
            ) {
                rawData = data
                if let ui = UIImage(data: data) { image = ui }
            }
        }
    }
}

private struct AttachmentFullscreenView: View {
    let data: Data
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
