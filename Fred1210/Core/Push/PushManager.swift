import Foundation
import UIKit
import UserNotifications

/// Coordinates APNs device-token registration with the Fred server.
///
/// Lifecycle:
///   1. On app launch, call ``requestAuthorizationIfNeeded()`` to ask the
///      user for notification permission. Idempotent — no-op if already
///      authorized.
///   2. iOS delivers the device token to the ``UIApplicationDelegate``
///      which hands it here via ``registerDeviceToken(_:)``.
///   3. We POST the hex-encoded token to ``/api/agent/push/register`` so
///      Fred can later send digests, alerts, and research notifications
///      through APNs.
///   4. On explicit sign-out or uninstall-but-reinstall flows we call
///      ``unregister()`` to DELETE the token.
///
/// Thread-safe: publishes to ``@MainActor`` for SwiftUI consumers.
@MainActor
final class PushManager: ObservableObject {
    enum AuthState: Equatable {
        case notDetermined
        case authorized
        case denied
        case provisional
    }

    @Published private(set) var authState: AuthState = .notDetermined
    @Published private(set) var lastRegistration: Date?
    @Published private(set) var lastError: String?

    private let config: FredConfig
    private let session: URLSession

    init(config: FredConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Check current notification status. Safe to call every launch.
    func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authState = map(settings.authorizationStatus)
        if authState == .authorized || authState == .provisional {
            // Re-registering on every authorized launch ensures iOS gives us
            // a fresh device token if the previous one was invalidated.
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Ask iOS for notification permission. No-op if the user already
    /// answered — either yes or no.
    func requestAuthorizationIfNeeded() async {
        await refreshAuthStatus()
        guard authState == .notDetermined else { return }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            authState = granted ? .authorized : .denied
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            lastError = "Authorization request failed: \(error.localizedDescription)"
        }
    }

    /// Forward the hex-encoded APNs device token to Fred.
    func registerDeviceToken(_ token: Data) async {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        let url = config.hostURL.appendingPathComponent("/api/agent/push/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["token": hex, "platform": "ios"],
            options: []
        )
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                lastError = "Server rejected push token: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                return
            }
            lastRegistration = Date()
            lastError = nil
        } catch {
            lastError = "Token registration failed: \(error.localizedDescription)"
        }
    }

    /// Record APNs registration failure so the user can see it in
    /// Settings → Diagnostics instead of silently failing.
    func recordRegistrationFailure(_ error: Error) {
        lastError = "APNs registration failed: \(error.localizedDescription)"
    }

    // MARK: -

    private func map(_ status: UNAuthorizationStatus) -> AuthState {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .authorized
        @unknown default: return .notDetermined
        }
    }
}
