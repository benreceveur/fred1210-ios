import Foundation

/// URLProtocol subclass that observes every HTTP request made via the
/// Fred URLSession and appends a snapshot (method, URL, status, latency)
/// to ``RequestLog.shared``. Install by adding it to the `protocolClasses`
/// of the session's ``URLSessionConfiguration``.
///
/// We don't actually load anything here — we hand off to a default
/// URLSession (without our own protocol installed, to avoid recursion)
/// and forward data/response/error events back to the client.
final class RequestLogProtocol: URLProtocol {
    private static let forwardingSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        return URLSession(configuration: cfg)
    }()

    private var dataTask: URLSessionDataTask?
    private var startedAt: Date?
    private var receivedResponse: HTTPURLResponse?

    override class func canInit(with request: URLRequest) -> Bool {
        // Avoid re-entrancy: only handle each request once.
        guard URLProtocol.property(forKey: "RequestLogProtocolHandled", in: request) == nil else {
            return false
        }
        // Only log http(s) — skip data: and other schemes.
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: "RequestLogProtocolHandled", in: mutable)

        startedAt = Date()
        let task = Self.forwardingSession.dataTask(
            with: mutable as URLRequest,
            completionHandler: { [weak self] data, response, error in
                guard let self else { return }
                Task { await self.log(data: data, response: response, error: error) }
                if let error {
                    self.client?.urlProtocol(self, didFailWithError: error)
                    return
                }
                if let response {
                    self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                if let data {
                    self.client?.urlProtocol(self, didLoad: data)
                }
                self.client?.urlProtocolDidFinishLoading(self)
            }
        )
        dataTask = task
        task.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
    }

    // MARK: - Log building

    private func log(data: Data?, response: URLResponse?, error: Error?) async {
        let latencyMs: Int = {
            guard let started = startedAt else { return 0 }
            return Int(Date().timeIntervalSince(started) * 1000)
        }()
        let status = (response as? HTTPURLResponse)?.statusCode
        let entry = RequestLog.Entry(
            method: request.httpMethod ?? "GET",
            url: displayURL(request.url),
            status: status,
            latencyMs: latencyMs,
            error: error?.localizedDescription,
            timestamp: startedAt ?? Date()
        )
        await RequestLog.shared.record(entry)
    }

    /// Strip query string from logged URLs so any accidental tokens in
    /// query params never land in a log readable from the Settings UI.
    private func displayURL(_ url: URL?) -> String {
        guard let url else { return "(nil)" }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.query = nil
        return comps?.url?.absoluteString ?? url.absoluteString
    }
}
