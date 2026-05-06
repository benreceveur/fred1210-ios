import Foundation

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [Components.Schemas.Task] = []
    @Published private(set) var isLoading = false
    @Published private(set) var cacheAge: Date?
    @Published private(set) var pendingMutationCount = 0
    @Published private(set) var pendingCreateTitles: [String] = []
    @Published var displayError: FredDisplayError?

    private let client: FredClient
    private let cache: ResponseCache
    private let pendingStore: PendingTaskMutationStore
    private var pendingStatusOverrides: [String: Components.Schemas.Task.StatusPayload] = [:]
    private var pendingPriorityOverrides: [String: Components.Schemas.Task.PriorityPayload] = [:]
    private var pendingDeleteIds = Set<String>()

    init(
        client: FredClient,
        cache: ResponseCache = .shared,
        pendingStore: PendingTaskMutationStore = .shared
    ) {
        self.client = client
        self.cache = cache
        self.pendingStore = pendingStore
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
            await drainPendingMutations()
            let items = try await client.listTasks()
            let sorted = items.sorted { lhs, rhs in
                priorityRank(lhs.priority) < priorityRank(rhs.priority)
            }
            tasks = sorted.filter { !pendingDeleteIds.contains($0.id) }
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
            if shouldQueue(error) {
                await pendingStore.enqueue(.init(
                    kind: .create,
                    payload: createPayload(
                        title: trimmed,
                        description: description,
                        priority: priority
                    )
                ))
                await loadPendingMutations()
                displayError = FredDisplayError(
                    endpoint: "Create task",
                    primaryMessage: "Task queued",
                    detailMessage: "Fred will create this task when the Mac Mini is reachable again.",
                    httpStatus: nil,
                    retry: { [weak self] in await self?.refresh() }
                )
            } else {
                displayError = FredDisplayError.from(error, endpoint: "Create task", retry: nil)
            }
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
        await patch(
            task.id,
            updates: .init(status: nextStatus),
            rawPayload: ["status": nextStatus.rawValue]
        )
    }

    /// Directly set a task's status — used by the long-press context menu.
    func setStatus(_ task: Components.Schemas.Task, to status: Components.Schemas.UpdateTaskRequest.StatusPayload) async {
        await patch(
            task.id,
            updates: .init(status: status),
            rawPayload: ["status": status.rawValue]
        )
    }

    /// Directly set a task's priority — used by the long-press context menu.
    func setPriority(_ task: Components.Schemas.Task, to priority: Components.Schemas.UpdateTaskRequest.PriorityPayload) async {
        await patch(
            task.id,
            updates: .init(priority: priority),
            rawPayload: ["priority": priority.rawValue]
        )
    }

    func delete(_ task: Components.Schemas.Task) async {
        // Optimistic removal for snappy UX; revert on error.
        let index = tasks.firstIndex(where: { $0.id == task.id })
        if let index { tasks.remove(at: index) }
        do {
            try await client.deleteTask(id: task.id)
        } catch {
            if shouldQueue(error) {
                pendingDeleteIds.insert(task.id)
                await pendingStore.enqueue(.init(kind: .delete, taskId: task.id))
                await loadPendingMutations()
                displayError = FredDisplayError(
                    endpoint: "Delete task",
                    primaryMessage: "Delete queued",
                    detailMessage: "Fred will delete this task when the Mac Mini is reachable again.",
                    httpStatus: nil,
                    retry: { [weak self] in await self?.refresh() }
                )
            } else {
                displayError = FredDisplayError.from(error, endpoint: "Delete task", retry: nil)
                if let index { tasks.insert(task, at: index) }
            }
        }
    }

    func clearError() { displayError = nil }

    func loadPendingMutations() async {
        let pending = await pendingStore.list()
        pendingMutationCount = pending.count
        pendingCreateTitles = pending
            .filter { $0.kind == .create }
            .compactMap { $0.payload["title"] }
        rebuildPendingOverrides(from: pending)
        tasks = tasks.filter { !pendingDeleteIds.contains($0.id) }
    }

    func status(for task: Components.Schemas.Task) -> Components.Schemas.Task.StatusPayload {
        pendingStatusOverrides[task.id] ?? task.status
    }

    func priority(for task: Components.Schemas.Task) -> Components.Schemas.Task.PriorityPayload {
        pendingPriorityOverrides[task.id] ?? task.priority
    }

    func hasPendingMutation(_ task: Components.Schemas.Task) -> Bool {
        pendingStatusOverrides[task.id] != nil
            || pendingPriorityOverrides[task.id] != nil
            || pendingDeleteIds.contains(task.id)
    }

    // MARK: -

    private func patch(
        _ id: String,
        updates: Components.Schemas.UpdateTaskRequest,
        rawPayload: [String: String]
    ) async {
        do {
            let updated = try await client.updateTask(id: id, patch: updates)
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index] = updated
            }
        } catch {
            if shouldQueue(error) {
                applyPendingOverride(taskId: id, payload: rawPayload)
                await pendingStore.enqueue(.init(kind: .update, taskId: id, payload: rawPayload))
                await loadPendingMutations()
                displayError = FredDisplayError(
                    endpoint: "Update task",
                    primaryMessage: "Task update queued",
                    detailMessage: "The change is saved locally and will sync when Fred is reachable.",
                    httpStatus: nil,
                    retry: { [weak self] in await self?.refresh() }
                )
            } else {
                displayError = FredDisplayError.from(error, endpoint: "Update task", retry: nil)
            }
        }
    }

    private func drainPendingMutations() async {
        let pending = await pendingStore.list()
        guard !pending.isEmpty else {
            await loadPendingMutations()
            return
        }

        for mutation in pending {
            do {
                switch mutation.kind {
                case .create:
                    try await client.createTaskRaw(mutation.payload)
                case .update:
                    guard let taskId = mutation.taskId else { continue }
                    try await client.updateTaskRaw(id: taskId, payload: mutation.payload)
                case .delete:
                    guard let taskId = mutation.taskId else { continue }
                    try await client.deleteTask(id: taskId)
                }
                await pendingStore.remove(id: mutation.id)
            } catch {
                await pendingStore.markFailed(id: mutation.id, error: error.localizedDescription)
                break
            }
        }
        await loadPendingMutations()
    }

    private func rebuildPendingOverrides(from pending: [PendingTaskMutation]) {
        pendingStatusOverrides = [:]
        pendingPriorityOverrides = [:]
        pendingDeleteIds = []

        for mutation in pending {
            switch mutation.kind {
            case .create:
                continue
            case .update:
                guard let taskId = mutation.taskId else { continue }
                applyPendingOverride(taskId: taskId, payload: mutation.payload)
            case .delete:
                if let taskId = mutation.taskId {
                    pendingDeleteIds.insert(taskId)
                }
            }
        }
    }

    private func applyPendingOverride(taskId: String, payload: [String: String]) {
        if let status = payload["status"], let parsed = parseTaskStatus(status) {
            pendingStatusOverrides[taskId] = parsed
        }
        if let priority = payload["priority"], let parsed = parseTaskPriority(priority) {
            pendingPriorityOverrides[taskId] = parsed
        }
    }

    private func createPayload(
        title: String,
        description: String?,
        priority: Components.Schemas.CreateTaskRequest.PriorityPayload
    ) -> [String: String] {
        var payload: [String: String] = [
            "title": title,
            "status": "todo",
            "priority": priority.rawValue
        ]
        if let description, !description.isEmpty {
            payload["description"] = description
        }
        return payload
    }

    private func parseTaskStatus(_ raw: String) -> Components.Schemas.Task.StatusPayload? {
        switch raw {
        case "inbox": return .inbox
        case "todo": return .todo
        case "in-progress": return .inProgress
        case "review": return .review
        case "done": return .done
        default: return nil
        }
    }

    private func parseTaskPriority(_ raw: String) -> Components.Schemas.Task.PriorityPayload? {
        switch raw {
        case "none": return Components.Schemas.Task.PriorityPayload.none
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        case "urgent": return .urgent
        default: return nil
        }
    }

    private func shouldQueue(_ error: Error) -> Bool {
        if case FredError.transport = error {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet
            ].contains(nsError.code)
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

    /// Tag this task with `gh-create:<owner>/<repo>` and kick off an
    /// immediate sync so the upstream issue appears without waiting for
    /// the next cron tick. After the server files the issue it'll rewrite
    /// the tag to `external:<owner>/<repo>#<n>`; a refresh pulls that back.
    func pushToGithub(_ task: Components.Schemas.Task, repoSlug: String) async {
        let trimmed = repoSlug.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("/") else { return }
        let createTag = "gh-create:\(trimmed)"
        let existing = task.tags ?? []
        // No-op if already tagged (e.g. user tapped twice).
        guard !existing.contains(createTag) else { return }
        let patch = Components.Schemas.UpdateTaskRequest(
            tags: existing + [createTag]
        )
        do {
            _ = try await client.updateTask(id: task.id, patch: patch)
            try? await client.triggerGithubSync()
            await refresh()
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Push to GitHub", retry: nil)
        }
    }
}
