import Foundation
import KeychainAccess

/// Fred server configuration — host URL persisted to the Keychain so it
/// survives app reinstalls (matching the iOS behavior of expo-secure-store
/// in the React Native app).
final class FredConfig: ObservableObject {
    static let defaultHost = "https://bobs-mac-mini.tail5a2996.ts.net"
    static let service = "com.relayforgelabs.fred1210"
    private static let hostKey = "fred-host"

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
