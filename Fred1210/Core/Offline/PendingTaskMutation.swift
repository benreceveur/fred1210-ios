import Foundation

struct PendingTaskMutation: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case create
        case update
        case delete
    }

    let id: UUID
    let kind: Kind
    let taskId: String?
    let payload: [String: String]
    let enqueuedAt: Date
    var attemptCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        kind: Kind,
        taskId: String? = nil,
        payload: [String: String] = [:],
        enqueuedAt: Date = Date(),
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.taskId = taskId
        self.payload = payload
        self.enqueuedAt = enqueuedAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}

actor PendingTaskMutationStore {
    static let shared = PendingTaskMutationStore()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxEntries = 200

    init(fileURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = fileURL ?? documents.appendingPathComponent("pending-task-mutations.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func list() async -> [PendingTaskMutation] {
        readAll()
    }

    func enqueue(_ mutation: PendingTaskMutation) async {
        var current = readAll()
        current.append(mutation)
        if current.count > maxEntries {
            current = Array(current.suffix(maxEntries))
        }
        writeAll(current)
    }

    func remove(id: UUID) async {
        writeAll(readAll().filter { $0.id != id })
    }

    func markFailed(id: UUID, error: String) async {
        var current = readAll()
        guard let index = current.firstIndex(where: { $0.id == id }) else { return }
        current[index].attemptCount += 1
        current[index].lastError = error
        writeAll(current)
    }

    func clear() async {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func readAll() -> [PendingTaskMutation] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([PendingTaskMutation].self, from: data)
                .sorted { $0.enqueuedAt < $1.enqueuedAt }
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return []
        }
    }

    private func writeAll(_ mutations: [PendingTaskMutation]) {
        do {
            let data = try encoder.encode(mutations)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort queue persistence. The caller still shows the live error.
        }
    }
}
