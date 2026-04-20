import Foundation

/// In-memory ring buffer of the last N HTTP requests the app made. Powers
/// the Settings → Diagnostics screen so users (and future me) can see
/// exactly what URL failed, its HTTP status, and its latency the next
/// time something breaks in prod — without Xcode attached.
///
/// Intentionally small (N = 50) and in-memory only: we don't want to
/// persist request URLs to disk where they could leak bearer tokens in
/// query strings. If the app is killed the log clears.
actor RequestLog {
    static let shared = RequestLog()

    private let capacity = 50
    private var entries: [Entry] = []

    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let method: String
        let url: String
        let status: Int?
        let latencyMs: Int
        let error: String?
        let timestamp: Date
    }

    func record(_ entry: Entry) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    /// Newest first.
    func snapshot() -> [Entry] {
        entries.reversed()
    }

    func clear() {
        entries.removeAll()
    }
}
