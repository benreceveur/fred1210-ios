import Foundation

@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable {
        case inbox
        case chat
        case review
        case tasks
        case settings
    }

    enum Sheet: Identifiable, Equatable {
        case task(String)
        case recommendation(String)
        case research(String, String)
        case health

        var id: String {
            switch self {
            case .task(let id): return "task-\(id)"
            case .recommendation(let id): return "recommendation-\(id)"
            case .research(let id, _): return "research-\(id)"
            case .health: return "health"
            }
        }
    }

    @Published var selectedTab: Tab = .inbox
    @Published var activeSheet: Sheet?

    func route(_ destination: RouteDestination) {
        switch destination {
        case .inbox:
            selectedTab = .inbox
        case .chat:
            selectedTab = .chat
        case .review:
            selectedTab = .review
        case .tasks:
            selectedTab = .tasks
        case .settings:
            selectedTab = .settings
        case .health:
            selectedTab = .settings
            activeSheet = .health
        case .task(let id):
            selectedTab = .tasks
            activeSheet = .task(id)
        case .recommendation(let id):
            selectedTab = .review
            activeSheet = .recommendation(id)
        case .research(let id, let title):
            selectedTab = .inbox
            activeSheet = .research(id, title)
        }
    }

    func route(from userInfo: [AnyHashable: Any]) {
        let stringValue: (String) -> String? = { key in
            if let value = userInfo[key] as? String { return value }
            if let value = userInfo[key] { return String(describing: value) }
            return nil
        }

        if let taskId = stringValue("taskId") ?? stringValue("task_id") {
            route(.task(taskId))
            return
        }
        if let recommendationId = stringValue("recommendationId") ?? stringValue("recommendation_id") {
            route(.recommendation(recommendationId))
            return
        }
        if let researchId = stringValue("researchId") ?? stringValue("research_id") {
            route(.research(researchId, stringValue("title") ?? "Research"))
            return
        }
        if let screen = stringValue("screen") ?? stringValue("tab") ?? stringValue("kind") {
            route(RouteDestination(screen: screen))
        }
    }

    func route(url: URL) {
        guard url.scheme == "fred1210" else { return }
        let host = url.host?.lowercased() ?? ""
        let parts = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "task":
            if let id = parts.first { route(.task(id)) }
        case "recommendation", "approval":
            if let id = parts.first { route(.recommendation(id)) }
        case "research":
            if let id = parts.first { route(.research(id, "Research")) }
        case "health":
            route(.health)
        case "chat":
            route(.chat)
        case "tasks":
            route(.tasks)
        case "review":
            route(.review)
        default:
            route(.inbox)
        }
    }
}

enum RouteDestination: Equatable {
    case inbox
    case chat
    case review
    case tasks
    case settings
    case health
    case task(String)
    case recommendation(String)
    case research(String, String)

    init(screen: String) {
        switch screen.lowercased() {
        case "chat": self = .chat
        case "review", "approval", "approvals", "repo": self = .review
        case "task", "tasks": self = .tasks
        case "setting", "settings": self = .settings
        case "health", "transport", "systemhealth": self = .health
        default: self = .inbox
        }
    }
}

extension Notification.Name {
    static let fredRouteRequested = Notification.Name("fredRouteRequested")
}
