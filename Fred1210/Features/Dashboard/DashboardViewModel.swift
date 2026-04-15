import Foundation

/// Normalized dashboard view state. Mirrors the mobile `DashboardData` shape
/// so the iOS screen can render the same cards without each view reaching
/// into the raw generated types.
struct DashboardSnapshot {
    struct UsageToday {
        var requests: Int
        var tokens: Int
        var cost: Double
        var errors: Int
    }
    struct TasksStats {
        var total: Int
        var overdue: Int
        var byStatus: [String: Int]
    }
    struct TeamStats {
        var total: Int
        var active: Int
        var degraded: Int
        var offline: Int
    }
    struct MemoryStats {
        var facts: Int
        var conversations: Int
        var lastActive: Date?
    }
    struct Schedule {
        var entriesCount: Int
        var remindersCount: Int
    }
    struct Pipelines {
        var total: Int
    }

    var agentStatus: Components.Schemas.AgentStatus?
    var usageToday = UsageToday(requests: 0, tokens: 0, cost: 0, errors: 0)
    var weekCost: Double = 0
    var tasks = TasksStats(total: 0, overdue: 0, byStatus: [:])
    var team: TeamStats?
    var memory = MemoryStats(facts: 0, conversations: 0, lastActive: nil)
    var schedule = Schedule(entriesCount: 0, remindersCount: 0)
    var pipelines = Pipelines(total: 0)
    var upstreamMonitors: Int = 0
    var transports: [Components.Schemas.TransportHealth] = []
    var nemoPlannerSuccessRate: Double?
    var nemoDaysTracked: Int = 0

    static let empty = DashboardSnapshot()
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot = DashboardSnapshot.empty
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: FredClient

    init(client: FredClient) {
        self.client = client
    }

    /// Fetch dashboard, status, and transport health in parallel.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let dashboardTask = client.fetchDashboard()
            async let statusTask = client.fetchAgentStatus()
            async let transportTask = client.fetchTransportHealth()
            let (dashboard, status, transports) = try await (dashboardTask, statusTask, transportTask)
            snapshot = normalize(dashboard: dashboard, status: status, transports: transports)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearError() { errorMessage = nil }

    // MARK: - Normalization

    private func normalize(
        dashboard: Components.Schemas.DashboardResponse,
        status: Components.Schemas.AgentStatus,
        transports: [Components.Schemas.TransportHealth]
    ) -> DashboardSnapshot {
        var snap = DashboardSnapshot()
        snap.agentStatus = status
        snap.transports = transports

        if let usage = dashboard.usage {
            snap.usageToday = .init(
                requests: usage.today?.requests ?? 0,
                tokens: usage.today?.tokens ?? 0,
                cost: usage.today?.cost ?? 0,
                errors: usage.today?.errors ?? 0
            )
            snap.weekCost = usage.weekCost ?? 0
        }

        if let tasks = dashboard.tasks {
            let items = tasks.items ?? []
            let byStatus = items.reduce(into: [String: Int]()) { acc, task in
                acc[task.status.rawValue, default: 0] += 1
            }
            let now = Date()
            let overdue = items.filter { task in
                guard task.status != .done, let due = task.dueDate else { return false }
                return due < now
            }.count
            snap.tasks = .init(
                total: tasks.count ?? items.count,
                overdue: overdue,
                byStatus: byStatus
            )
        }

        if let team = dashboard.team, team.error == nil {
            snap.team = .init(
                total: team.total ?? 0,
                active: team.active ?? 0,
                degraded: team.degraded ?? 0,
                offline: team.offline ?? 0
            )
        }

        if let memory = dashboard.memory {
            snap.memory = .init(
                facts: memory.facts ?? 0,
                conversations: memory.conversations ?? 0,
                lastActive: memory.lastActive
            )
        }

        if let schedule = dashboard.schedule {
            let stateCount = schedule.state?.additionalProperties.value.count ?? 0
            snap.schedule = .init(
                entriesCount: stateCount,
                remindersCount: schedule.reminders?.count ?? 0
            )
        }

        if let pipelines = dashboard.pipelines {
            snap.pipelines = .init(total: pipelines.count ?? pipelines.items?.count ?? 0)
        }

        if let upstream = dashboard.upstream, upstream.error == nil {
            var count = 0
            if upstream.monitor != nil { count += 1 }
            if upstream.shannon != nil { count += 1 }
            if upstream.openclaw != nil { count += 1 }
            if upstream.nemoclaw != nil { count += 1 }
            snap.upstreamMonitors = count
        }

        if let nemo = dashboard.nemo?.summary {
            snap.nemoPlannerSuccessRate = nemo.plannerSuccessRate
            snap.nemoDaysTracked = nemo.daysTracked ?? 0
        }

        return snap
    }
}
