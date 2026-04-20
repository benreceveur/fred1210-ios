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
    /// Shared access group so extensions (share, widget, Siri intent, watch)
    /// read the same host URL as the main app. Must match the
    /// `keychain-access-groups` entitlement declared in project.yml. Xcode
    /// prefixes the group with the team ID at build time; KeychainAccess
    /// handles the expansion when the group is passed with the literal
    /// `$(AppIdentifierPrefix)` substring.
    static let accessGroup = "$(AppIdentifierPrefix)com.relayforgelabs.fred1210.shared"
    private static let hostKey = "fred-host"

    /// Fallback when Config/Local.xcconfig hasn't been set up and the
    /// user hasn't stored a host in Keychain yet. Deliberately a
    /// non-resolvable placeholder so misconfiguration fails loud.
    static let defaultHost: String = {
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "FredDefaultHost") as? String,
           !fromPlist.isEmpty {
            return fromPlist
        }
        return "https://fred.example.ts.net"
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

        let stored = try? self.keychain.get(Self.hostKey)
        let raw = stored?.isEmpty == false ? stored! : Self.defaultHost
        self.hostURL = URL(string: raw) ?? URL(string: Self.defaultHost)!
    }

    func setHost(_ urlString: String) throws {
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            throw FredConfigError.invalidURL
        }
        try keychain.set(urlString, key: Self.hostKey)
        DispatchQueue.main.async { self.hostURL = url }
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
