import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        TaskListContentView(client: clientHolder.client)
    }
}

private struct TaskListContentView: View {
    @StateObject private var viewModel: TaskListViewModel
    @State private var showingCreateSheet = false

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: TaskListViewModel(client: client))
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
                        ForEach(viewModel.tasks, id: \.id) { task in
                            TaskRow(task: task)
                                .listRowBackground(Theme.bgCard)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.delete(task) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Task { await viewModel.toggleStatus(task) }
                                    } label: {
                                        Label("Advance", systemImage: "arrow.right.circle")
                                    }
                                    .tint(Theme.primary)
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
                CreateTaskSheet { title, description, priority in
                    Task { await viewModel.create(title: title, description: description, priority: priority) }
                }
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

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
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

    let onCreate: (String, String?, Components.Schemas.CreateTaskRequest.PriorityPayload) -> Void

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
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title, description, priority)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
