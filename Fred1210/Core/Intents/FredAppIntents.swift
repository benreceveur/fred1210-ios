import Foundation
import AppIntents

/// Ask Fred a question from Siri, Shortcuts, or Spotlight. "Hey Siri,
/// ask Fred what's urgent today" → speaks Fred's answer.
struct AskFredIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Fred"
    static let description = IntentDescription(
        "Send Fred a chat message and get his response — useful for quick briefings, calendar checks, or asking him to kick off research.",
        categoryName: "Fred"
    )
    static let openAppWhenRun = false

    @Parameter(
        title: "Question",
        description: "What do you want to ask Fred?",
        inputOptions: .init(multiline: true)
    )
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Fred \(\.$question)")
    }

    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let client = FredIntentClient()
        let response = try await client.sendChat(question)
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

/// Create a task via Siri or Shortcuts without opening the app.
struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Fred task"
    static let description = IntentDescription(
        "Add a new task to Fred's task board.",
        categoryName: "Fred"
    )
    static let openAppWhenRun = false

    @Parameter(title: "Title", description: "What should Fred add to your task list?")
    var title: String

    @Parameter(
        title: "Priority",
        description: "How urgent is this?",
        default: .medium
    )
    var priority: FredPriority

    static var parameterSummary: some ParameterSummary {
        Summary("Create Fred task \(\.$title) with \(\.$priority) priority")
    }

    func perform() async throws -> some ProvidesDialog {
        let client = FredIntentClient()
        let created = try await client.createTask(title: title, priority: priority.rawValue)
        return .result(dialog: IntentDialog(stringLiteral: "Added '\(created)' to your Fred tasks."))
    }
}

/// Voice-first variant that lets Siri capture the task title via dictation
/// so the user doesn't have to type.
struct CreateTaskViaVoiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Tell Fred to add a task"
    static let description = IntentDescription(
        "Dictate a task and Fred adds it at medium priority. Great for hands-free capture.",
        categoryName: "Fred"
    )
    static let openAppWhenRun = false

    @Parameter(
        title: "What should I add?",
        description: "Dictate the task — Fred will add it with medium priority.",
        requestValueDialog: IntentDialog("What task should I add?")
    )
    var dictation: String

    static var parameterSummary: some ParameterSummary {
        Summary("Tell Fred to add \(\.$dictation)")
    }

    func perform() async throws -> some ProvidesDialog {
        let client = FredIntentClient()
        let created = try await client.createTask(title: dictation, priority: "medium")
        return .result(dialog: IntentDialog(stringLiteral: "Got it — added '\(created)'."))
    }
}

/// Ask Fred to review a GitHub repo by URL.
struct ReviewRepoIntent: AppIntent {
    static let title: LocalizedStringResource = "Review GitHub repo"
    static let description = IntentDescription(
        "Ask Fred to clone a public GitHub repo, inspect its implementation, and recommend whether to adopt.",
        categoryName: "Fred"
    )
    static let openAppWhenRun = false

    @Parameter(
        title: "Repo URL",
        description: "github.com/owner/repo",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var repoURL: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Fred to review \(\.$repoURL)")
    }

    func perform() async throws -> some ProvidesDialog {
        let client = FredIntentClient()
        let message = "Review this repo: \(repoURL.absoluteString)"
        let response = try await client.sendChat(message)
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - Enums exposed to AppIntents

enum FredPriority: String, AppEnum {
    case urgent, high, medium, low, none

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Fred priority")
    static let caseDisplayRepresentations: [FredPriority: DisplayRepresentation] = [
        .urgent: "Urgent",
        .high: "High",
        .medium: "Medium",
        .low: "Low",
        .none: "None",
    ]
}

// MARK: - Shortcuts gallery

/// Curated Shortcuts suggestions that appear in the Shortcuts app gallery.
struct Fred1210AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskFredIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Ask \(.applicationName)",
            ],
            shortTitle: "Ask Fred",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )
        AppShortcut(
            intent: CreateTaskViaVoiceIntent(),
            phrases: [
                "Tell \(.applicationName) to add a task",
                "Add a task to \(.applicationName)",
            ],
            shortTitle: "Add task via Fred",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: ReviewRepoIntent(),
            phrases: [
                "Have \(.applicationName) review a repo",
                "Ask \(.applicationName) about a GitHub repo",
            ],
            shortTitle: "Review repo with Fred",
            systemImageName: "chevron.left.forwardslash.chevron.right"
        )
    }
}
