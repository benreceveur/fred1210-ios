import Foundation
import KeychainAccess

/// Fred server configuration — host URL persisted to the Keychain so it
/// survives app reinstalls (matching the iOS behavior of expo-secure-store
/// in the React Native app).
///
/// The default host is read from the Info.plist key `FredDefaultHost`,
/// which is populated at build time from Config/Local.xcconfig. That file
/// is gitignored so each developer's Tailscale hostname stays local.
/// See Config/Local.xcconfig.example for the template.
final class FredConfig: ObservableObject {
    static let service = "com.relayforgelabs.fred1210"
    static let productionDefaultHost = "https://bobs-mac-mini.tail5a2996.ts.net"
    /// Shared access group so extensions (share, widget, Siri intent, watch)
    /// read the same host URL as the main app. Must match the
    /// `keychain-access-groups` entitlement declared in project.yml. Xcode
    /// prefixes the group with the team ID at build time; KeychainAccess
    /// handles the expansion when the group is passed with the literal
    /// `$(AppIdentifierPrefix)` substring.
    static let accessGroup = "$(AppIdentifierPrefix)com.relayforgelabs.fred1210.shared"
    private static let hostKey = "fred-host"
    /// iCloud Key-Value store key. NSUbiquitousKeyValueStore is per-iCloud
    /// account and propagates within seconds across iPhone / iPad / Mac
    /// (where the app is installed). 5kb total limit per app — we use a
    /// single URL key well inside that.
    private static let icloudHostKey = "fred-host-icloud"

    /// Fallback when Config/Local.xcconfig hasn't been set up and the
    /// user hasn't stored a host in Keychain yet.
    static let defaultHost: String = {
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "FredDefaultHost") as? String,
           !fromPlist.isEmpty {
            return normalizedHost(fromPlist)
        }
        return productionDefaultHost
    }()

    @Published private(set) var hostURL: URL

    private let keychain: Keychain

    init() {
        // One-time migration: read any pre-Phase-1 value stored under the
        // non-shared service keychain and copy it into the shared group.
        // After migration, all reads/writes go through the shared group so
        // future extensions see the same host the main app is using.
        let shared = Keychain(service: Self.service, accessGroup: Self.accessGroup).synchronizable(false)
        if (try? shared.get(Self.hostKey)) == nil {
            let legacy = Keychain(service: Self.service).synchronizable(false)
            let legacyValue = (try? legacy.get(Self.hostKey)) ?? nil
            if let legacyValue, !legacyValue.isEmpty {
                try? shared.set(legacyValue, key: Self.hostKey)
            }
        }
        self.keychain = shared

        // If the Keychain has no host yet but iCloud KV does — usually
        // because the user already set up Fred on another device — adopt
        // the iCloud value as the starting point.
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        let icloud = kv.string(forKey: Self.icloudHostKey)
        let stored = try? self.keychain.get(Self.hostKey)
        let initialRaw: String = {
            if let stored, !stored.isEmpty { return stored }
            if let icloud, !icloud.isEmpty { return icloud }
            return Self.defaultHost
        }()
        let normalized = Self.normalizedHost(initialRaw)
        self.hostURL = URL(string: normalized)!
        if normalized != initialRaw || stored != normalized {
            try? self.keychain.set(normalized, key: Self.hostKey)
            kv.set(normalized, forKey: Self.icloudHostKey)
        }

        // Listen for iCloud KV pushes from other devices. SwiftUI views
        // re-render via @Published `hostURL` when the value lands.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleICloudHostChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kv
        )
    }

    func setHost(_ urlString: String) throws {
        let normalized = Self.normalizedHost(urlString, repairPlaceholders: false)
        guard let url = URL(string: normalized), url.scheme != nil, url.host != nil else {
            throw FredConfigError.invalidURL
        }
        try keychain.set(normalized, key: Self.hostKey)
        // Mirror to iCloud KV so a fresh install on another device picks
        // up this URL on first launch. 5kb cap is well above any URL.
        let kv = NSUbiquitousKeyValueStore.default
        kv.set(normalized, forKey: Self.icloudHostKey)
        kv.synchronize()
        DispatchQueue.main.async { self.hostURL = url }
    }

    @objc private func handleICloudHostChange(_ notification: Notification) {
        // iCloud only pushes when the *external* value changed — i.e. when
        // another device wrote it. Adopt the new value if it differs from
        // what we currently have stored locally.
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              reason != NSUbiquitousKeyValueStoreQuotaViolationChange else {
            return
        }
        let kv = NSUbiquitousKeyValueStore.default
        guard let incoming = kv.string(forKey: Self.icloudHostKey),
              !incoming.isEmpty else { return }
        let normalized = Self.normalizedHost(incoming, repairPlaceholders: false)
        guard let url = URL(string: normalized),
              url.scheme != nil, url.host != nil,
              url.absoluteString != hostURL.absoluteString else { return }
        try? keychain.set(normalized, key: Self.hostKey)
        DispatchQueue.main.async { self.hostURL = url }
    }

    static func normalizedHost(_ raw: String?, repairPlaceholders: Bool = true) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return productionDefaultHost }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            return repairPlaceholders ? productionDefaultHost : trimmed
        }

        if repairPlaceholders, isKnownBadHost(host) {
            return productionDefaultHost
        }

        return trimmed
    }

    private static func isKnownBadHost(_ host: String) -> Bool {
        host == "fred.example.ts.net" || host.hasSuffix(".example.ts.net") || host == "example.ts.net"
    }
}

enum FredConfigError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Fred host URL must be a valid absolute URL (e.g. https://example.ts.net)"
        }
    }
}
