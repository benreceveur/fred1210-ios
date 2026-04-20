import SwiftUI
import UIKit

/// SwiftUI's App lifecycle doesn't expose the remote-notification
/// registration callbacks. We bridge via ``UIApplicationDelegateAdaptor``
/// in ``Fred1210App`` and forward the token to ``PushManager``.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Set by Fred1210App so the delegate callbacks can reach the
    /// shared push manager without @EnvironmentObject plumbing.
    static var pushManager: PushManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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

    // Tap-to-open: iOS later we'll route to a specific tab based on
    // notification.category (digest → Chat, task → Tasks, etc.). For
    // Phase 2 just open the app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
