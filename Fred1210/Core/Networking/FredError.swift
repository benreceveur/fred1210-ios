import Foundation

/// Domain errors surfaced by `FredClient`. View models translate these to
/// user-facing messages.
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
