import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Thin wrapper around the swift-openapi-generator `Client`. Centralizes:
///   - base URL injection from `FredConfig`
///   - per-request timeout configuration
///   - direct multipart handling for voice uploads (the generator's multipart
///     ergonomics are awkward; URLSession is clearer here)
///
/// Every typed wrapper uses the generator's throwing accessors
/// (`output.ok.body.json`). Non-2xx responses surface as
/// `ClientError` from OpenAPIRuntime which view models can translate to
/// user-facing messages.
@MainActor
final class FredClient {
    private let config: FredConfig
    private let session: URLSession

    init(config: FredConfig) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        // Fred's /api/agent/chat routes through the full agent pipeline
        // (LLM + tool loop + council fallback) which routinely takes
        // 20–60s under normal load. A 15s request timeout was
        // cancelling the request before the server finished,
        // surfacing as "send error" in the Chat tab. 120s matches the
        // existing resource timeout and covers p99 pipeline latency.
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    /// Wraps an API call with timing + RequestLog emission. We log via
    /// this helper instead of a URLProtocol because URLProtocol
    /// interception interferes with swift-openapi-runtime's
    /// URLSessionTransport response handling.
    private func logged<T>(
        _ method: String,
        _ endpoint: String,
        _ block: () async throws -> T
    ) async throws -> T {
        let started = Date()
        let fullURL = config.hostURL.appendingPathComponent(endpoint).absoluteString
        do {
            let result = try await block()
            await RequestLog.shared.record(.init(
                method: method, url: fullURL, status: 200,
                latencyMs: Int(Date().timeIntervalSince(started) * 1000),
                error: nil, timestamp: started
            ))
            return result
        } catch {
            let status: Int? = (error as? FredError).flatMap { err in
                if case let .server(code, _) = err { return code }
                if case .unauthorized = err { return 401 }
                if case .notFound = err { return 404 }
                return nil
            }
            await RequestLog.shared.record(.init(
                method: method, url: fullURL, status: status,
                latencyMs: Int(Date().timeIntervalSince(started) * 1000),
                error: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
                timestamp: started
            ))
            throw error
        }
    }

    // MARK: - Generated Client

    private func makeClient() -> Client {
        Client(
            serverURL: config.hostURL,
            configuration: Configuration(dateTranscoder: TolerantISO8601Transcoder()),
            transport: URLSessionTransport(configuration: .init(session: session))
        )
    }

    // MARK: - Typed wrappers

    func fetchAgentStatus() async throws -> Components.Schemas.AgentStatus {
        try await logged("GET", "/api/agent/status") {
            let output = try await makeClient().getAgentStatus(.init())
            return try output.ok.body.json
        }
    }

    func sendChatMessage(_ text: String) async throws -> Components.Schemas.ChatResponse {
        try await logged("POST", "/api/agent/chat") {
            let output = try await makeClient().postChat(
                .init(body: .json(.init(message: text)))
            )
            return try output.ok.body.json
        }
    }

    func fetchHistory() async throws -> Components.Schemas.HistoryResponse {
        try await logged("GET", "/api/agent/history") {
            let output = try await makeClient().getChatHistory(.init())
            return try output.ok.body.json
        }
    }

    func fetchDashboard() async throws -> Components.Schemas.DashboardResponse {
        try await logged("GET", "/api/agent/dashboard") {
            let output = try await makeClient().getDashboard(.init())
            return try output.ok.body.json
        }
    }

    func fetchTransportHealth() async throws -> [Components.Schemas.TransportHealth] {
        try await logged("GET", "/api/agent/transport/health") {
            let output = try await makeClient().getTransportHealth(.init())
            return try output.ok.body.json.transports
        }
    }

    func listTasks() async throws -> [Components.Schemas.Task] {
        try await logged("GET", "/api/agent/tasks") {
            let output = try await makeClient().listTasks(.init())
            return try output.ok.body.json.tasks
        }
    }

    func getTask(id: String) async throws -> Components.Schemas.Task {
        try await logged("GET", "/api/agent/tasks/\(id)") {
            let output = try await makeClient().getTask(.init(path: .init(id: id)))
            return try output.ok.body.json
        }
    }

    func createTask(_ request: Components.Schemas.CreateTaskRequest) async throws -> Components.Schemas.Task {
        try await logged("POST", "/api/agent/tasks") {
            let output = try await makeClient().createTask(.init(body: .json(request)))
            return try output.created.body.json.task
        }
    }

    func updateTask(
        id: String,
        patch: Components.Schemas.UpdateTaskRequest
    ) async throws -> Components.Schemas.Task {
        try await logged("PATCH", "/api/agent/tasks/\(id)") {
            let output = try await makeClient().updateTask(
                .init(path: .init(id: id), body: .json(patch))
            )
            return try output.ok.body.json.task
        }
    }

    func deleteTask(id: String) async throws {
        try await logged("DELETE", "/api/agent/tasks/\(id)") {
            let output = try await makeClient().deleteTask(.init(path: .init(id: id)))
            _ = try output.ok  // throws if not 2xx
        }
    }

    func fetchVoiceHealth() async throws -> Components.Schemas.VoiceHealthResponse {
        try await logged("GET", "/voice/health") {
            let output = try await makeClient().voiceHealth(.init())
            return try output.ok.body.json
        }
    }

    // MARK: - Direct multipart: voice turn
    //
    // The generator's multipart support for binary uploads is still awkward
    // in 1.6.x. URLSession is clearer for this one endpoint. We preserve the
    // voice metadata headers (X-Voice-*) that the server returns so the UI
    // can surface latency breakdowns.

    struct VoiceTurnResult {
        let audioData: Data
        let mimeType: String
        let transcript: String
        let responseText: String
        let sttProvider: String
        let ttsProvider: String
        let sttMs: Int
        let pipelineMs: Int
        let ttsMs: Int
        let totalMs: Int
    }

    func voiceTurn(
        audioFileURL: URL,
        language: String? = nil,
        voice: String? = nil,
        format: String = "mp3"
    ) async throws -> VoiceTurnResult {
        let url = config.hostURL.appendingPathComponent("voice/turn")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90  // STT + pipeline + TTS can be 30-60s

        let boundary = "fred-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try buildMultipartBody(
            boundary: boundary,
            audioFileURL: audioFileURL,
            language: language,
            voice: voice,
            format: format
        )
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FredError.transport(underlying: URLError(.badServerResponse))
        }

        if http.statusCode == 401 { throw FredError.unauthorized }
        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8)
            throw FredError.server(status: http.statusCode, message: msg)
        }

        func header(_ key: String) -> String {
            (http.value(forHTTPHeaderField: key)) ?? ""
        }
        func intHeader(_ key: String) -> Int { Int(header(key)) ?? 0 }
        func decodedHeader(_ key: String) -> String {
            header(key).removingPercentEncoding ?? header(key)
        }

        return VoiceTurnResult(
            audioData: data,
            mimeType: header("Content-Type"),
            transcript: decodedHeader("X-Voice-Transcript"),
            responseText: decodedHeader("X-Voice-Response"),
            sttProvider: header("X-Voice-STT-Provider"),
            ttsProvider: header("X-Voice-TTS-Provider"),
            sttMs: intHeader("X-Voice-STT-Ms"),
            pipelineMs: intHeader("X-Voice-Pipeline-Ms"),
            ttsMs: intHeader("X-Voice-TTS-Ms"),
            totalMs: intHeader("X-Voice-Total-Ms")
        )
    }

    private func buildMultipartBody(
        boundary: String,
        audioFileURL: URL,
        language: String?,
        voice: String?,
        format: String
    ) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }

        func appendFile(name: String, filename: String, mimeType: String, data: Data) {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(lineBreak)")
            body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
            body.append(data)
            body.append(lineBreak)
        }

        let audioData = try Data(contentsOf: audioFileURL)
        let filename = audioFileURL.lastPathComponent.isEmpty ? "recording.m4a" : audioFileURL.lastPathComponent
        appendFile(name: "audio", filename: filename, mimeType: "audio/mp4", data: audioData)

        if let language { appendField(name: "language", value: language) }
        if let voice { appendField(name: "voice", value: voice) }
        appendField(name: "format", value: format)

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
