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
        self.keychain = Keychain(service: Self.service).synchronizable(false)
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
