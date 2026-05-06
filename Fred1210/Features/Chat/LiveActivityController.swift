#if canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
final class LiveActivityController {
    private var activity: Activity<FredTurnActivityAttributes>?

    func start(prompt: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = FredTurnActivityAttributes(
            prompt: String(prompt.prefix(80)),
            turnId: UUID().uuidString
        )
        let state = FredTurnActivityAttributes.ContentState(
            phase: "Planning",
            currentTool: nil,
            toolCount: 0,
            elapsedSec: 0
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func update(phase: String, currentTool: String?, toolCount: Int, startedAt: Date?) async {
        guard let activity else { return }
        let elapsed = startedAt.map { max(0, Int(Date().timeIntervalSince($0))) } ?? 0
        let state = FredTurnActivityAttributes.ContentState(
            phase: phase,
            currentTool: currentTool,
            toolCount: toolCount,
            elapsedSec: elapsed
        )
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func end(summary: String) async {
        guard let activity else { return }
        let state = FredTurnActivityAttributes.ContentState(
            phase: summary,
            currentTool: nil,
            toolCount: 0,
            elapsedSec: 0
        )
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date(timeIntervalSinceNow: 60))
        )
        self.activity = nil
    }
}
#endif
