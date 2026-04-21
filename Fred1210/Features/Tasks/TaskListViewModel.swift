import Foundation

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [Components.Schemas.Task] = []
    @Published private(set) var isLoading = false
    @Published private(set) var cacheAge: Date?
    @Published var displayError: FredDisplayError?

    private let client: FredClient
    private let cache: ResponseCache

    init(client: FredClient, cache: ResponseCache = .shared) {
        self.client = client
        self.cache = cache
    }

    /// Populate from disk cache. Safe to call from `.task` — yields
    /// immediately if nothing is cached and the normal refresh path
    /// will fill in fresh data.
    func loadFromCache() async {
        if let entry = await cache.read(.tasks, as: [Components.Schemas.Task].self) {
            tasks = entry.value.sorted { lhs, rhs in
                priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
            cacheAge = entry.cachedAt
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let items = try await client.listTasks()
            let sorted = items.sorted { lhs, rhs in
                priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
            tasks = sorted
            displayError = nil
            cacheAge = Date()
            await cache.write(.tasks, sorted)
        } catch {
            displayError = FredDisplayError.from(
                error, endpoint: "Tasks",
                retry: { [weak self] in await self?.refresh() }
            )
        }
    }

    func create(
        title: String,
        description: String?,
        priority: Components.Schemas.CreateTaskRequest.PriorityPayload,
        attachment: Data? = nil
    ) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = Components.Schemas.CreateTaskRequest(
            title: trimmed,
            description: description?.isEmpty == false ? description : nil,
            status: .todo,
            priority: priority
        )

        do {
            var task = try await client.createTask(request)
            // If the sheet supplied an image, upload it after creation so
            // the task gets its id first, then we POST the binary to the
            // attachments route. Best-effort — attachment failure keeps the
            // task visible and surfaces the error separately.
            if let attachment {
                do {
                    task = try await client.uploadTaskAttachment(taskId: task.id, imageData: attachment)
                } catch {
                    displayError = FredDisplayError.from(error, endpoint: "Upload attachment", retry: nil)
                }
            }
            tasks.insert(task, at: 0)
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Create task", retry: nil)
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

    /// Directly set a task's status — used by the long-press context menu.
    func setStatus(_ task: Components.Schemas.Task, to status: Components.Schemas.UpdateTaskRequest.StatusPayload) async {
        await patch(task.id, updates: .init(status: status))
    }

    /// Directly set a task's priority — used by the long-press context menu.
    func setPriority(_ task: Components.Schemas.Task, to priority: Components.Schemas.UpdateTaskRequest.PriorityPayload) async {
        await patch(task.id, updates: .init(priority: priority))
    }

    func delete(_ task: Components.Schemas.Task) async {
        // Optimistic removal for snappy UX; revert on error.
        let index = tasks.firstIndex(where: { $0.id == task.id })
        if let index { tasks.remove(at: index) }
        do {
            try await client.deleteTask(id: task.id)
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Delete task", retry: nil)
            if let index { tasks.insert(task, at: index) }
        }
    }

    func clearError() { displayError = nil }

    // MARK: -

    private func patch(_ id: String, updates: Components.Schemas.UpdateTaskRequest) async {
        do {
            let updated = try await client.updateTask(id: id, patch: updates)
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index] = updated
            }
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Update task", retry: nil)
        }
    }

    private func priorityRank(_ priority: Components.Schemas.Task.PriorityPayload) -> Int {
        switch priority {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .none: return 4
        }
    }
}
