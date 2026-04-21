import Foundation
import BackgroundTasks
import UIKit

/// Schedules a background task that pre-fetches Fred's dashboard + tasks
/// roughly every 30 minutes when iOS allows it. Next launch opens to
/// live data instead of a 3-second loading state.
///
/// iOS decides when to actually run the task based on battery, network,
/// and user habits — the 30-minute value is a suggestion, not a
/// guarantee. Apple typically grants us ~2–3 runs per day under normal
/// usage patterns.
final class BackgroundRefresh {
    /// Must match the BGTaskSchedulerPermittedIdentifiers entry in Info.plist.
    static let refreshTaskIdentifier = "com.relayforgelabs.fred1210.refresh"

    static let minimumInterval: TimeInterval = 30 * 60

    /// Call once during app startup to wire up the task handler.
    static func register(refresh: @Sendable @escaping () async -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            handle(task, refresh: refresh)
        }
    }

    /// Ask iOS to schedule the next refresh. Safe to call on launch and
    /// every time the app backgrounds — iOS coalesces duplicate
    /// submissions.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Submission can fail in the simulator or if the entitlement
            // isn't granted. Not fatal — foreground refresh still works.
            #if DEBUG
            print("[BackgroundRefresh] scheduleNext failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: -

    private static func handle(_ task: BGTask, refresh: @Sendable @escaping () async -> Void) {
        // Always submit the next request before starting work so we stay
        // in the rotation even if the current run times out.
        scheduleNext()

        let refreshTask = Task {
            await refresh()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }
    }
}
