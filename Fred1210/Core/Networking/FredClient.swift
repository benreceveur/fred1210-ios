import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Thin wrapper around the swift-openapi-generator `Client`. Centralizes:
///   - base URL injection from `FredConfig`
///   - per-request timeout configuration
///   - domain error mapping to `FredError`
///
/// The underlying `Client` type is generated at build time by the SPM plugin
/// reading `Core/API/openapi.json`. Until Xcode runs the build once, the
/// `Client` symbol will be red in the IDE — that's expected.
@MainActor
final class FredClient {
    private let config: FredConfig
    private let session: URLSession

    init(config: FredConfig) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    /// Builds the generated `Client` against the current host URL. Rebuilt on
    /// every call so host changes in `FredConfig` take effect immediately.
    ///
    /// The generator's `Client` type is in the module's generated sources —
    /// this function will be completed in task #18 after the first successful
    /// Xcode build produces the symbol.
    //
    // NOTE: body is intentionally commented out until swift-openapi-generator
    // runs. Uncomment when Xcode is installed and the first build completes.
    /*
    func makeClient() throws -> Client {
        return Client(
            serverURL: config.hostURL,
            transport: URLSessionTransport(configuration: .init(session: session))
        )
    }
    */
}

enum FredError: LocalizedError {
    case unauthorized
    case notFound
    case server(status: Int, message: String?)
    case transport(underlying: Error)
    case decoding(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized — check Tailscale identity header"
        case .notFound:
            return "Resource not found"
        case .server(let status, let message):
            return "Server error \(status)\(message.map { ": \($0)" } ?? "")"
        case .transport(let err):
            return "Network error: \(err.localizedDescription)"
        case .decoding(let err):
            return "Response decoding failed: \(err.localizedDescription)"
        }
    }
}
