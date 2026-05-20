import Foundation

@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable {
        case dashboard
        case chat
        case review
        case tasks
        case settings
        // `.inbox` retained for deep-link compatibility — route(.inbox) now
        // surfaces the inbox inside the Dashboard tab's NavigationStack via
        // `inboxRequested`.
        case inbox
    }

    enum Sheet: Identifiable, Equatable {
        case task(String)
        case recommendation(String)
        case research(String, String)
        case health
        case inbox

        var id: String {
            switch self {
            case .task(let id): return "task-\(id)"
            case .recommendation(let id): return "recommendation-\(id)"
            case .research(let id, _): return "research-\(id)"
            case .health: return "health"
            case .inbox: return "inbox"
            }
        }
    }

    @Published var selectedTab: Tab = .dashboard
    @Published var activeSheet: Sheet?
    /// True while the global voice sheet is presented. Lives on the router so
    /// any tab can trigger it (toolbar buttons, deep links, App Intents).
    @Published var isShowingVoiceSheet: Bool = false
    /// When true, VoiceView should auto-start recording on appear. Set by the
    /// long-press handler on the mic toolbar button — tap = open sheet idle,
    /// long-press = open sheet recording. Consumed exactly once: VoiceView
    /// flips it back to false after triggering startHoldToTalk.
    @Published var voiceAutoStart: Bool = false
    /// True while the quick-capture sheet is presented. Lives on the router
    /// so any tab can trigger it from its toolbar.
    @Published var isShowingQuickCapture: Bool = false

    func route(_ destination: RouteDestination) {
        switch destination {
        case .dashboard:
            selectedTab = .dashboard
        case .inbox:
            // Inbox is no longer a dedicated tab — open it on top of
            // Dashboard so the user lands in the same NavigationStack as
            // the rest of their work.
            selectedTab = .dashboard
            activeSheet = .inbox
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
            selectedTab = .dashboard
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
        case "inbox":
            route(.inbox)
        case "dashboard", "home", "":
            route(.dashboard)
        default:
            route(.dashboard)
        }
    }
}

enum RouteDestination: Equatable {
    case dashboard
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
        case "dashboard", "home": self = .dashboard
        case "inbox": self = .inbox
        case "chat": self = .chat
        case "review", "approval", "approvals", "repo": self = .review
        case "task", "tasks": self = .tasks
        case "setting", "settings": self = .settings
        case "health", "transport", "systemhealth": self = .health
        default: self = .dashboard
        }
    }
}

extension Notification.Name {
    static let fredRouteRequested = Notification.Name("fredRouteRequested")
}
