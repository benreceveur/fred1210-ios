import SwiftUI
import UIKit

/// SwiftUI's App lifecycle doesn't expose the remote-notification
/// registration callbacks. We bridge via ``UIApplicationDelegateAdaptor``
/// in ``Fred1210App`` and forward the token to ``PushManager``.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Set by Fred1210App so the delegate callbacks can reach the
    /// shared push manager without @EnvironmentObject plumbing.
    static var pushManager: PushManager?

    /// Holder for the FredClient so action handlers can call the approval /
    /// task APIs without needing the in-app router. Set by Fred1210App.
    static var clientHolder: ClientHolder?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Register actionable categories so push notifications can show
        // Approve / Dismiss / Mark done buttons without opening the app.
        Self.pushManager?.registerCategories()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard let manager = Self.pushManager else { return }
        Task { await manager.registerDeviceToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            Self.pushManager?.recordRegistrationFailure(error)
        }
    }

    // Show alert/sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Tap-to-open OR inline action: server pushes can include keys such as
    // `taskId`, `recommendationId`, `researchId`, `screen`, `kind`. When the
    // notification's category is one of the actionable ones (see
    // `PushManager.CategoryID`) and the response carries an `actionIdentifier`
    // beyond the default tap, we forward to the matching API on the FredClient
    // and skip routing into the app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier

        switch action {
        case PushManager.ActionID.approve.rawValue:
            Task {
                await Self.handleApprovalAction(approve: true, userInfo: info)
                completionHandler()
            }
            return
        case PushManager.ActionID.dismiss.rawValue:
            Task {
                await Self.handleApprovalAction(approve: false, userInfo: info)
                completionHandler()
            }
            return
        case PushManager.ActionID.complete.rawValue:
            Task {
                await Self.handleTaskComplete(userInfo: info)
                completionHandler()
            }
            return
        default:
            // Default tap (or unknown action): open the relevant screen in
            // the app via the existing route-by-userInfo notification.
            NotificationCenter.default.post(
                name: .fredRouteRequested,
                object: nil,
                userInfo: info
            )
            completionHandler()
        }
    }

    private static func handleApprovalAction(
        approve: Bool,
        userInfo: [AnyHashable: Any]
    ) async {
        guard let id = stringValue(in: userInfo, keys: ["recommendationId", "recommendation_id"]),
              let client = await clientHolder?.client else { return }
        do {
            _ = try await client.resolveRepoRecommendation(
                id: id,
                action: approve ? "approve" : "dismiss"
            )
        } catch {
            // Inline-action failure: surface as a follow-up notification
            // through the existing route-request channel so the user lands
            // in the in-app approval screen and can retry.
            NotificationCenter.default.post(
                name: .fredRouteRequested,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private static func handleTaskComplete(userInfo: [AnyHashable: Any]) async {
        guard let id = stringValue(in: userInfo, keys: ["taskId", "task_id"]),
              let client = await clientHolder?.client else { return }
        do {
            try await client.updateTaskRaw(id: id, payload: ["status": "done"])
        } catch {
            NotificationCenter.default.post(
                name: .fredRouteRequested,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private static func stringValue(
        in userInfo: [AnyHashable: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = userInfo[key] as? String, !value.isEmpty { return value }
            if let value = userInfo[key] { return String(describing: value) }
        }
        return nil
    }
}
