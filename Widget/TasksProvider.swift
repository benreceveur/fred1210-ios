import WidgetKit
import Foundation

/// Data fetched from Fred's `/api/agent/tasks` endpoint. Lightweight
/// mirror of the main app's Task schema — just the fields the widget
/// needs to render.
struct WidgetTask: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let status: String
    let priority: String
    let dueDate: String?

    var isDone: Bool { status == "done" }

    var priorityRank: Int {
        switch priority {
        case "urgent": return 0
        case "high": return 1
        case "medium": return 2
        case "low": return 3
        default: return 4  // "none"
        }
    }

    static func sample(_ title: String, _ priority: String) -> WidgetTask {
        WidgetTask(id: UUID().uuidString, title: title, status: "todo", priority: priority, dueDate: nil)
    }
}

struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let hasHost: Bool
    let errorMessage: String?

    static let placeholder = TasksEntry(
        date: Date(),
        tasks: [
            .sample("Tap to configure", "high"),
            .sample("Open Fred1210 on your phone first", "medium"),
        ],
        hasHost: true,
        errorMessage: nil
    )
}

struct TasksProvider: TimelineProvider {
    /// Must match FredConfig's accessGroup + service + key. Duplicated
    /// here so the widget doesn't depend on the main app module.
    private let keychainService = "com.relayforgelabs.fred1210"
    private let keychainAccessGroup = "$(AppIdentifierPrefix)com.relayforgelabs.fred1210.shared"
    private let keychainKey = "fred-host"

    /// WidgetKit calls this for the snapshot shown in the widget gallery.
    func placeholder(in context: Context) -> TasksEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        Task {
            let entry = await buildEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            let next = Date(timeIntervalSinceNow: 15 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    // MARK: -

    private func buildEntry() async -> TasksEntry {
        guard let host = readHostURL() else {
            return TasksEntry(date: Date(), tasks: [], hasHost: false, errorMessage: nil)
        }
        do {
            let tasks = try await fetchTasks(host: host)
            let openTasks = tasks.filter { !$0.isDone }.sorted { $0.priorityRank < $1.priorityRank }
            return TasksEntry(date: Date(), tasks: openTasks, hasHost: true, errorMessage: nil)
        } catch {
            return TasksEntry(date: Date(), tasks: [], hasHost: true, errorMessage: error.localizedDescription)
        }
    }

    private func readHostURL() -> URL? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainKey,
            kSecAttrAccessGroup: keychainAccessGroup,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
           let text = String(data: data, encoding: .utf8),
           let url = URL(string: text) {
            return url
        }
        // Fallback without access group (legacy installs).
        query.removeValue(forKey: kSecAttrAccessGroup)
        result = nil
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let text = String(data: data, encoding: .utf8),
           let url = URL(string: text) {
            return url
        }
        return nil
    }

    private func fetchTasks(host: URL) async throws -> [WidgetTask] {
        let url = host.appendingPathComponent("/api/agent/tasks")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(
                domain: "Fred1210Widget", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: "Server returned \((response as? HTTPURLResponse)?.statusCode ?? -1)"]
            )
        }
        struct Envelope: Codable { let tasks: [WidgetTask] }
        return try JSONDecoder().decode(Envelope.self, from: data).tasks
    }
}
