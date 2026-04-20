import Foundation

/// Minimal HTTP client used exclusively by App Intents. Lives outside
/// the main app's ``FredClient`` because intents run in short-lived
/// extension processes and pulling in the full OpenAPIRuntime dependency
/// is wasteful. Reads the host URL from the shared Keychain group.
struct FredIntentClient {
    enum IntentError: LocalizedError {
        case notConfigured
        case serverError(status: Int, body: String?)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Open Fred1210 on your phone and configure the host URL first."
            case let .serverError(status, body):
                return "Fred returned HTTP \(status): \(body ?? "no body")"
            case let .transport(err):
                return "Can't reach Fred: \(err.localizedDescription)"
            }
        }
    }

    private let keychainService = "com.relayforgelabs.fred1210"
    private let keychainAccessGroup = "$(AppIdentifierPrefix)com.relayforgelabs.fred1210.shared"
    private let keychainKey = "fred-host"

    func sendChat(_ message: String) async throws -> String {
        let host = try hostURL()
        let url = host.appendingPathComponent("/api/agent/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["message": message])
        request.timeoutInterval = 90

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw IntentError.transport(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IntentError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                body: String(data: data, encoding: .utf8)
            )
        }
        struct Envelope: Codable { let response: String }
        return try JSONDecoder().decode(Envelope.self, from: data).response
    }

    func createTask(title: String, priority: String) async throws -> String {
        let host = try hostURL()
        let url = host.appendingPathComponent("/api/agent/tasks")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "title": title,
            "status": "todo",
            "priority": priority,
        ])
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw IntentError.transport(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IntentError.serverError(
                status: (response as? HTTPURLResponse)?.statusCode ?? -1,
                body: String(data: data, encoding: .utf8)
            )
        }
        struct Envelope: Codable {
            struct TaskPayload: Codable { let id: String; let title: String }
            let task: TaskPayload
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        return env.task.title
    }

    // MARK: -

    private func hostURL() throws -> URL {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainKey,
            kSecAttrAccessGroup: keychainAccessGroup,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let text = String(data: data, encoding: .utf8),
           let url = URL(string: text) {
            return url
        }
        query.removeValue(forKey: kSecAttrAccessGroup)
        result = nil
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let text = String(data: data, encoding: .utf8),
           let url = URL(string: text) {
            return url
        }
        throw IntentError.notConfigured
    }
}
