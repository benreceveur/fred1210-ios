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

    /// Per-channel opt-in/out. Mirrors the server's
    /// ``push-delivery.ChannelPreferences`` shape exactly.
    struct ChannelPreferences: Codable, Equatable {
        var digest: Bool
        var urgentTasks: Bool
        var researchFindings: Bool
        var transportAlerts: Bool

        static let allOn = ChannelPreferences(
            digest: true, urgentTasks: true,
            researchFindings: true, transportAlerts: true
        )
    }

    @Published private(set) var authState: AuthState = .notDetermined
    @Published private(set) var lastRegistration: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var preferences: ChannelPreferences = .allOn
    @Published private(set) var preferencesLoaded = false

    private let config: FredConfig
    private let session: URLSession
    /// Hex-encoded APNs token kept in memory after the latest registration.
    /// Used to key preference GET/PATCH calls so we don't have to
    /// re-read it from Keychain on every toggle.
    private var lastHexToken: String?

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
            lastHexToken = hex
            lastRegistration = Date()
            lastError = nil
            // Pull current channel preferences so the Settings UI reflects
            // whatever the server already has for this token.
            await loadPreferences()
        } catch {
            lastError = "Token registration failed: \(error.localizedDescription)"
        }
    }

    /// GET /api/agent/push/preferences?token=<hex>. Safe no-op if we
    /// haven't registered a token yet (first launch before APNs callback).
    func loadPreferences() async {
        guard let token = lastHexToken else { return }
        var components = URLComponents(
            url: config.hostURL.appendingPathComponent("/api/agent/push/preferences"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            struct Envelope: Decodable { let preferences: ChannelPreferences }
            let env = try JSONDecoder().decode(Envelope.self, from: data)
            preferences = env.preferences
            preferencesLoaded = true
        } catch {
            // Non-fatal — UI falls back to allOn default.
        }
    }

    /// PATCH /api/agent/push/preferences with the supplied fields. Only
    /// keys present in `patch` are sent; server merges into existing state.
    func updatePreferences(_ patch: [String: Bool]) async {
        guard let token = lastHexToken else {
            lastError = "Push token not yet registered — try again in a moment."
            return
        }
        let url = config.hostURL.appendingPathComponent("/api/agent/push/preferences")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["token": token]
        for (k, v) in patch { body[k] = v }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                lastError = "Preference update rejected: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                return
            }
            struct Envelope: Decodable { let preferences: ChannelPreferences }
            let env = try JSONDecoder().decode(Envelope.self, from: data)
            preferences = env.preferences
            preferencesLoaded = true
            lastError = nil
        } catch {
            lastError = "Preference update failed: \(error.localizedDescription)"
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
