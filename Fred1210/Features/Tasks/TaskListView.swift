import SwiftUI
import UIKit
import PhotosUI

struct TaskListView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        TaskListContentView(client: clientHolder.client)
    }
}

private struct TaskListContentView: View {
    @EnvironmentObject var clientHolder: ClientHolder
    @StateObject private var viewModel: TaskListViewModel
    @State private var showingCreateSheet = false
    @State private var showCompleted = false
    @State private var detailTaskId: String?
    @State private var pushSheetTask: Components.Schemas.Task?

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: TaskListViewModel(client: client))
    }

    private var openTasks: [Components.Schemas.Task] {
        viewModel.tasks.filter { $0.status != .done }
    }

    private var completedTasks: [Components.Schemas.Task] {
        viewModel.tasks.filter { $0.status == .done }
    }

    /// Renders a single task row with the standard swipe actions + context
    /// menu. Pulled out as a helper so open-tasks and the collapsible
    /// Completed section both get the same affordances without duplication.
    @ViewBuilder
    private func taskRow(_ task: Components.Schemas.Task) -> some View {
        TaskRow(task: task)
            .contentShape(Rectangle())
            .onTapGesture { detailTaskId = task.id }
            .listRowBackground(Theme.bgCard)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    Task { await viewModel.setStatus(task, to: task.status == .done ? .todo : .done) }
                } label: {
                    Label(task.status == .done ? "Reopen" : "Done",
                          systemImage: task.status == .done ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                }
                .tint(task.status == .done ? Theme.primary : Theme.success)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    Task { await viewModel.toggleStatus(task) }
                } label: {
                    Label("Advance", systemImage: "arrow.right.circle")
                }
                .tint(Theme.primary)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    Task {
                        let ok = await Biometrics.authenticate(reason: "Delete task")
                        guard ok else { return }
                        await viewModel.delete(task)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Menu("Priority") {
                    priorityButton("Urgent", "flame", .urgent, task: task)
                    priorityButton("High", "arrow.up", .high, task: task)
                    priorityButton("Medium", "minus", .medium, task: task)
                    priorityButton("Low", "arrow.down", .low, task: task)
                    priorityButton("None", "circle", .none, task: task)
                }
                Menu("Status") {
                    statusButton("Inbox", "tray", .inbox, task: task)
                    statusButton("To Do", "circle", .todo, task: task)
                    statusButton("In Progress", "arrow.triangle.2.circlepath", .inProgress, task: task)
                    statusButton("Review", "eye", .review, task: task)
                    statusButton("Done", "checkmark.circle", .done, task: task)
                }
                Divider()
                Button {
                    UIPasteboard.general.string = task.title
                } label: {
                    Label("Copy title", systemImage: "doc.on.doc")
                }
                // Push-to-GitHub only when the task isn't already mirrored.
                // `external:` tag means it came from GitHub, so the button
                // would just confuse; hide it.
                if !(task.tags ?? []).contains(where: { $0.hasPrefix("external:") }) {
                    Button {
                        pushSheetTask = task
                    } label: {
                        Label("Push to GitHub…", systemImage: "arrow.up.right.circle")
                    }
                }
                Button(role: .destructive) {
                    Task {
                        let ok = await Biometrics.authenticate(reason: "Delete task")
                        guard ok else { return }
                        await viewModel.delete(task)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    /// Wraps a priority-menu entry so each button forwards to the view
    /// model without callers repeating the Task { await } boilerplate.
    private func priorityButton(
        _ title: String, _ icon: String,
        _ priority: Components.Schemas.UpdateTaskRequest.PriorityPayload,
        task: Components.Schemas.Task
    ) -> some View {
        Button {
            Task { await viewModel.setPriority(task, to: priority) }
        } label: {
            Label(title, systemImage: icon)
        }
    }

    /// Wraps a status-menu entry.
    private func statusButton(
        _ title: String, _ icon: String,
        _ status: Components.Schemas.UpdateTaskRequest.StatusPayload,
        task: Components.Schemas.Task
    ) -> some View {
        Button {
            Task { await viewModel.setStatus(task, to: status) }
        } label: {
            Label(title, systemImage: icon)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView()
                        .tint(Theme.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.tasks.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 60))
                            .foregroundStyle(Theme.textMuted)
                        Text("No tasks yet")
                            .font(.system(size: Theme.Font.md))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Open work lives in the default (unheadered) section so
                        // the common case — active tasks — reads like a clean
                        // list. Completed work is tucked into a collapsible
                        // footer section so it doesn't dilute the outstanding view.
                        if openTasks.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Theme.success)
                                Text("All caught up — no open tasks")
                                    .font(.system(size: Theme.Font.md))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .listRowBackground(Theme.bgCard)
                        } else {
                            ForEach(openTasks, id: \.id) { task in
                                taskRow(task)
                            }
                        }

                        if !completedTasks.isEmpty {
                            Section {
                                if showCompleted {
                                    ForEach(completedTasks, id: \.id) { task in
                                        taskRow(task)
                                    }
                                }
                            } header: {
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showCompleted.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Completed · \(completedTasks.count)")
                                            .font(.system(size: Theme.Font.xs, weight: .semibold))
                                        Spacer()
                                    }
                                    .foregroundStyle(Theme.textMuted)
                                    .textCase(nil)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.bgDark)
            .refreshable { await viewModel.refresh() }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .task {
                await viewModel.loadFromCache()
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateTaskSheet { title, description, priority, imageData in
                    Task {
                        await viewModel.create(
                            title: title,
                            description: description,
                            priority: priority,
                            attachment: imageData
                        )
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: Binding(
                get: { detailTaskId.map { DetailIdentifier(id: $0) } },
                set: { detailTaskId = $0?.id }
            )) { wrapper in
                TaskDetailView(taskId: wrapper.id, viewModel: viewModel)
                    .environmentObject(clientHolder)
            }
            .sheet(item: Binding(
                get: { pushSheetTask.map { PushTargetWrapper(task: $0) } },
                set: { pushSheetTask = $0?.task }
            )) { wrapper in
                PushToGithubSheet(
                    task: wrapper.task,
                    onPush: { repoSlug in
                        Task { await viewModel.pushToGithub(wrapper.task, repoSlug: repoSlug) }
                    }
                )
                .environmentObject(clientHolder)
                .presentationDetents([.medium])
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = viewModel.displayError {
                    ErrorBanner(error: error, onDismiss: viewModel.clearError)
                }
            }
        }
    }
}

// MARK: - Row

private struct TaskRow: View {
    let task: Components.Schemas.Task
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            if let firstAttachment = task.attachments?.first,
               firstAttachment.mimeType.hasPrefix("image/") {
                TaskAttachmentThumbnail(taskId: task.id, attachmentId: firstAttachment.id)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: Theme.Font.md, weight: .semibold))
                    .foregroundStyle(task.status == .done ? Theme.textMuted : Theme.textPrimary)
                    .strikethrough(task.status == .done, color: Theme.textMuted)
                HStack(spacing: Theme.Spacing.sm) {
                    Text(task.status.rawValue.replacingOccurrences(of: "-", with: " ").uppercased())
                        .font(.system(size: Theme.Font.xs, weight: .semibold))
                        .foregroundStyle(statusColor)
                    if let tags = task.tags, !tags.isEmpty {
                        Text("· \(tags.joined(separator: ", "))")
                            .font(.system(size: Theme.Font.xs))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(task.priority.rawValue.uppercased())
                .font(.system(size: Theme.Font.xs, weight: .bold))
                .foregroundStyle(priorityColor)
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return Theme.error
        case .high: return Theme.warning
        case .medium: return Theme.info
        case .low: return Theme.textMuted
        case .none: return Theme.textMuted
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .inbox: return Theme.textMuted
        case .todo: return Theme.info
        case .inProgress: return Theme.primary
        case .review: return Theme.warning
        case .done: return Theme.success
        }
    }
}

// MARK: - Create sheet

private struct CreateTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var priority: Components.Schemas.CreateTaskRequest.PriorityPayload = .medium
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?

    /// Callback fires with the optional image bytes so the caller uploads
    /// the attachment after the task is created.
    let onCreate: (String, String?, Components.Schemas.CreateTaskRequest.PriorityPayload, Data?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("What needs to be done?", text: $title)
                }
                Section("Description") {
                    TextField("Optional details", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("Urgent").tag(Components.Schemas.CreateTaskRequest.PriorityPayload.urgent)
                        Text("High").tag(Components.Schemas.CreateTaskRequest.PriorityPayload.high)
                        Text("Medium").tag(Components.Schemas.CreateTaskRequest.PriorityPayload.medium)
                        Text("Low").tag(Components.Schemas.CreateTaskRequest.PriorityPayload.low)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Attachment") {
                    PhotosPicker(
                        selection: $pickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Label(pickedImageData == nil ? "Attach photo" : "Photo attached", systemImage: "paperclip")
                            Spacer()
                            if let data = pickedImageData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .onChange(of: pickerItem) { newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                await MainActor.run { pickedImageData = data }
                            }
                        }
                    }
                    if pickedImageData != nil {
                        Button("Remove photo", role: .destructive) {
                            pickerItem = nil
                            pickedImageData = nil
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title, description, priority, pickedImageData)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// Small square thumbnail for task attachments. Fetches the binary from
/// `/api/agent/tasks/:id/attachments/:attId` and renders it inline on the
/// task row so the user sees the image without opening a detail view.
private struct TaskAttachmentThumbnail: View {
    let taskId: String
    let attachmentId: String
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.bgInput)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(Theme.textMuted)
                    )
            }
        }
        .task {
            guard image == nil else { return }
            if let data = try? await clientHolder.client.fetchAttachmentData(
                taskId: taskId, attachmentId: attachmentId
            ), let ui = UIImage(data: data) {
                image = ui
            }
        }
    }
}

/// Wrapper to let `sheet(item:)` key off a task id (the generated
/// Components.Schemas.Task is not Identifiable).
private struct DetailIdentifier: Identifiable {
    let id: String
}

private struct PushTargetWrapper: Identifiable {
    let task: Components.Schemas.Task
    var id: String { task.id }
}
