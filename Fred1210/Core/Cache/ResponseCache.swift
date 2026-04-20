import Foundation

/// On-disk JSON cache for last-successful API responses. Lets Dashboard
/// and Tasks render instantly on launch instead of showing a 3-second
/// loading state. When a fetch fails but cache is warm, the UI can
/// display cached data with a "stale since X min ago" badge.
///
/// Files live under `~/Library/Caches/fred-response-cache/<key>.json`.
/// The `Caches/` directory may be evicted by iOS under storage pressure
/// — that's the correct policy for reconstruct-able data.
///
/// Not thread-safe for writes to the same key concurrently; ViewModels
/// don't race on the same key so that's acceptable. Reads are safe.
actor ResponseCache {
    static let shared = ResponseCache()

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dateFormatter: ISO8601DateFormatter

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directory = caches.appendingPathComponent("fred-response-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        // Use the same fractional-second ISO8601 format as the server
        // (and as TolerantISO8601Transcoder on the network client) so
        // cached + fresh data round-trip cleanly.
        encoder.dateEncodingStrategy = .custom(Self.encodeISO8601)
        decoder.dateDecodingStrategy = .custom(Self.decodeISO8601)
        self.encoder = encoder
        self.decoder = decoder
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = fmt
    }

    // Sendable-safe date encoding helpers: each call creates its own
    // formatter instance so the strategy closures don't capture mutable
    // state and Swift 6's Sendable checker stays happy.
    @Sendable
    private static func encodeISO8601(_ date: Date, _ encoder: Encoder) throws {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var container = encoder.singleValueContainer()
        try container.encode(fmt.string(from: date))
    }

    @Sendable
    private static func decodeISO8601(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return withFractional.date(from: value) ?? plain.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }

    /// Cache keys used by the app. Keep this list central so typos don't
    /// silently create orphan files that never get read.
    enum Key: String {
        case dashboard
        case tasks
    }

    struct Entry<T: Codable>: Codable {
        let value: T
        let cachedAt: Date
    }

    func read<T: Codable>(_ key: Key, as type: T.Type) async -> Entry<T>? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(Entry<T>.self, from: data)
        } catch {
            // Corrupt/obsolete cache entry — remove and treat as cold miss.
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    func write<T: Codable>(_ key: Key, _ value: T) async {
        let entry = Entry(value: value, cachedAt: Date())
        let url = fileURL(for: key)
        do {
            let data = try encoder.encode(entry)
            try data.write(to: url, options: .atomic)
        } catch {
            // Best-effort — cache write failures shouldn't block the UI path.
        }
    }

    func clear() async {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for key: Key) -> URL {
        directory.appendingPathComponent("\(key.rawValue).json")
    }
}

/// Helpers for the "stale since X ago" badge text.
extension Date {
    func relativeAge(reference: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: reference)
    }
}
