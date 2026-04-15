import Foundation

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [Components.Schemas.Task] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: FredClient

    init(client: FredClient) {
        self.client = client
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let items = try await client.listTasks()
            tasks = items.sorted { lhs, rhs in
                priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func create(title: String, description: String?, priority: Components.Schemas.CreateTaskRequest.PriorityPayload) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = Components.Schemas.CreateTaskRequest(
            title: trimmed,
            description: description?.isEmpty == false ? description : nil,
            status: .todo,
            priority: priority
        )

        do {
            let task = try await client.createTask(request)
            tasks.insert(task, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func toggleStatus(_ task: Components.Schemas.Task) async {
        let nextStatus: Components.Schemas.UpdateTaskRequest.StatusPayload
        switch task.status {
        case .todo: nextStatus = .inProgress
        case .inProgress: nextStatus = .done
        case .done: nextStatus = .todo
        case .inbox: nextStatus = .todo
        case .review: nextStatus = .done
        }
        await patch(task.id, updates: .init(status: nextStatus))
    }

    func delete(_ task: Components.Schemas.Task) async {
        // Optimistic removal for snappy UX; revert on error.
        let index = tasks.firstIndex(where: { $0.id == task.id })
        if let index { tasks.remove(at: index) }
        do {
            try await client.deleteTask(id: task.id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if let index { tasks.insert(task, at: index) }
        }
    }

    func clearError() { errorMessage = nil }

    // MARK: -

    private func patch(_ id: String, updates: Components.Schemas.UpdateTaskRequest) async {
        do {
            let updated = try await client.updateTask(id: id, patch: updates)
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index] = updated
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func priorityRank(_ priority: Components.Schemas.Task.PriorityPayload) -> Int {
        switch priority {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}
