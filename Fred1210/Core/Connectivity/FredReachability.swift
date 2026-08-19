import Foundation
import SwiftUI

/// Poll Fred's `/api/agent/status` endpoint so the UI can show a 3-state dot
/// (healthy / degraded / offline) without waiting for the user to perform an
/// action that fails. Separate from `Connectivity` — Connectivity tracks the
/// system network path; this tracks whether Fred itself is reachable on the
/// current path.
@MainActor
final class FredReachability: ObservableObject {
    enum State: String {
        case unknown    // haven't checked yet — render as muted dot
        case healthy    // last check OK within the last interval
        case degraded   // 1-2 consecutive failures or last success > 90s ago
        case offline    // 3+ consecutive failures
    }

    @Published private(set) var state: State = .unknown
    @Published private(set) var lastSuccessAt: Date?
    @Published private(set) var consecutiveFailures: Int = 0

    private let client: FredClient
    /// Polling cadence while the app is foregrounded. 30s is a reasonable
    /// trade-off — frequent enough to catch drift, infrequent enough that a
    /// dozen of these per minute don't drain battery on cellular.
    private let interval: TimeInterval = 30
    private var pollTask: Task<Void, Never>?

    init(client: FredClient) {
        self.client = client
    }

    /// Start the background poll loop. Idempotent — repeated calls cancel the
    /// previous task and start a fresh one (used when the host URL changes).
    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollNow() async {
        await poll()
    }

    private func poll() async {
        do {
            _ = try await client.fetchAgentStatus()
            consecutiveFailures = 0
            lastSuccessAt = Date()
            state = .healthy
        } catch {
            consecutiveFailures += 1
            state = consecutiveFailures >= 3 ? .offline : .degraded
        }
    }
}

/// Tiny dot used in the nav bar to surface Fred-reachability without
/// stealing space from the title. Tap target wraps to 44pt for HIG.
struct ReachabilityDot: View {
    let state: FredReachability.State
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .frame(width: 44, height: 44) // HIG tap target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fred connection: \(label)")
    }

    private var color: Color {
        switch state {
        case .unknown:  return Theme.textMuted
        case .healthy:  return Theme.success
        case .degraded: return Theme.warning
        case .offline:  return Theme.error
        }
    }

    private var label: String {
        switch state {
        case .unknown:  return "checking"
        case .healthy:  return "healthy"
        case .degraded: return "degraded"
        case .offline:  return "offline"
        }
    }
}
