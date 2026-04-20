import Foundation

/// A structured, display-ready error that carries the context a user needs
/// to understand what failed and try again. Built from any thrown error but
/// augmented with:
///
///   - the logical endpoint name that failed ("Dashboard", "Tasks", ...)
///   - an HTTP status code when known
///   - an optional retry closure so the banner can offer a one-tap retry
///     without the caller re-plumbing button state
///
/// Replaces the previous pattern of a bare `String?` errorMessage shown in
/// an alert, which lost the endpoint / status context and couldn't retry.
struct FredDisplayError: Identifiable {
    let id = UUID()
    let endpoint: String
    let primaryMessage: String
    let detailMessage: String?
    let httpStatus: Int?
    let retry: (() async -> Void)?

    /// Best-effort one-liner suitable for a banner headline.
    var title: String {
        if let httpStatus {
            return "\(endpoint) failed (HTTP \(httpStatus))"
        }
        return "\(endpoint) failed"
    }

    /// Longer explanation suitable for the banner body. Always present;
    /// falls back to the primary message when no detail is available.
    var body: String {
        detailMessage ?? primaryMessage
    }

    /// Classify any thrown error into a display error. Handles our own
    /// ``FredError`` cases precisely and falls back to
    /// ``LocalizedError.errorDescription`` / ``Error.localizedDescription``
    /// for anything else (e.g. swift-openapi-runtime's ``ClientError``).
    static func from(
        _ error: Error,
        endpoint: String,
        retry: (() async -> Void)? = nil
    ) -> FredDisplayError {
        switch error {
        case let fredError as FredError:
            return from(fredError: fredError, endpoint: endpoint, retry: retry)
        default:
            let desc = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return FredDisplayError(
                endpoint: endpoint,
                primaryMessage: desc,
                detailMessage: describeNestedError(error),
                httpStatus: httpStatus(from: error),
                retry: retry
            )
        }
    }

    private static func from(
        fredError: FredError,
        endpoint: String,
        retry: (() async -> Void)?
    ) -> FredDisplayError {
        switch fredError {
        case .unauthorized:
            return FredDisplayError(
                endpoint: endpoint,
                primaryMessage: "Not authorized",
                detailMessage: "Fred couldn't identify you. Check that Tailscale is connected and the account matches the allowed user on the server.",
                httpStatus: 401,
                retry: retry
            )
        case .notFound:
            return FredDisplayError(
                endpoint: endpoint,
                primaryMessage: "Not found",
                detailMessage: "The server doesn't recognize this endpoint. Your app and the Fred server may be on different versions.",
                httpStatus: 404,
                retry: retry
            )
        case let .server(status, message):
            return FredDisplayError(
                endpoint: endpoint,
                primaryMessage: "Server error",
                detailMessage: message,
                httpStatus: status,
                retry: retry
            )
        case let .transport(underlying):
            return FredDisplayError(
                endpoint: endpoint,
                primaryMessage: "Can't reach Fred",
                detailMessage: underlying.localizedDescription,
                httpStatus: nil,
                retry: retry
            )
        case let .decoding(underlying):
            return FredDisplayError(
                endpoint: endpoint,
                primaryMessage: "Response didn't match what the app expects",
                detailMessage: underlying.localizedDescription,
                httpStatus: nil,
                retry: retry
            )
        }
    }

    /// Pull an HTTP status out of whatever we got. swift-openapi-runtime's
    /// ``ClientError`` exposes the upstream response via `causeDescription`
    /// strings, not structured fields — we fall back to regex scraping.
    private static func httpStatus(from error: Error) -> Int? {
        let text = String(describing: error)
        if let range = text.range(of: #"status code (\d{3})"#, options: .regularExpression) {
            let digits = text[range].filter { $0.isNumber }
            return Int(digits)
        }
        return nil
    }

    private static func describeNestedError(_ error: Error) -> String? {
        let text = String(describing: error)
        // Keep the detail short; most swift-openapi errors are multi-line
        // causeDescription strings that are too noisy for a banner body.
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? text
        return firstLine.count > 300 ? String(firstLine.prefix(300)) + "…" : firstLine
    }
}
