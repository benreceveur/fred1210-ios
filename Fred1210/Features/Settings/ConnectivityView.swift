import SwiftUI

/// Self-serve tools for verifying that Fred's transports are healthy —
/// the things you'd otherwise SSH into the Mac Mini to check. Shows live
/// transport-health snapshot and offers a test push button.
struct ConnectivityView: View {
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var transports: [Components.Schemas.TransportHealth] = []
    @State private var chatHealth: String = "unknown"
    @State private var isLoading = false
    @State private var pushResult: String?
    @State private var lastError: String?

    var body: some View {
        List {
            Section("Transports") {
                healthSummaryRow("Mac Mini", status: chatHealth == "unreachable" ? "Unreachable" : "Reachable", ok: chatHealth != "unreachable")
                healthSummaryRow("Fred API", status: chatHealth, ok: chatHealth.hasPrefix("OK"))
                if transports.isEmpty && !isLoading {
                    Text("No transport data yet — pull to refresh.")
                        .foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(transports, id: \.transport) { transport in
                        HStack {
                            Circle()
                                .fill(transport.degraded ? Theme.warning : Theme.success)
                                .frame(width: 8, height: 8)
                            Text(transport.transport.rawValue.capitalized)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(transport.degraded ? "Degraded" : "OK")
                                .font(Theme.TextStyle.captionSemibold)
                                .foregroundStyle(transport.degraded ? Theme.warning : Theme.success)
                        }
                    }
                }
            }
            .listRowBackground(Theme.bgCard)

            Section("Push notifications") {
                Button {
                    Task { await sendTestPush() }
                } label: {
                    Label("Send test push to this device", systemImage: "bell.badge")
                }
                if let pushResult {
                    Text(pushResult)
                        .font(Theme.TextStyle.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .listRowBackground(Theme.bgCard)

            if let lastError {
                Section {
                    Text(lastError)
                        .foregroundStyle(Theme.error)
                }
                .listRowBackground(Theme.bgCard)
            }

            Section {
                Text("If a transport stays degraded, restart Fred via LaunchAgent:\n\n`launchctl kickstart -k gui/$(id -u)/com.fred1210bot`")
                    .font(Theme.TextStyle.caption)
                    .foregroundStyle(Theme.textMuted)
            } header: {
                Text("Recovery")
            }
            .listRowBackground(Theme.bgCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .navigationTitle("Connectivity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable { await load() }
        .task { await load() }
    }

    private func healthSummaryRow(_ title: String, status: String, ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Theme.success : Theme.error)
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(status)
                .font(Theme.TextStyle.captionSemibold)
                .foregroundStyle(ok ? Theme.success : Theme.warning)
                .lineLimit(1)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            transports = try await clientHolder.client.fetchTransportHealth()
            // Chat pipeline health is a lightweight LLM-router readiness ping.
            // Not mapped through the generated client; do a raw check.
            chatHealth = (try? await rawChatHealth()) ?? "unreachable"
            lastError = nil
        } catch {
            lastError = "Couldn't load transport health: \(error.localizedDescription)"
        }
    }

    private func rawChatHealth() async throws -> String {
        let url = clientHolder.client.hostURL.appendingPathComponent("/api/agent/chat/health")
        let (data, _) = try await URLSession.shared.data(from: url)
        if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ok = obj["ok"] as? Bool {
            if ok {
                let provider = obj["provider"] as? String ?? "?"
                return "OK · \(provider)"
            }
            return "FAIL · \(obj["reason"] as? String ?? "unknown")"
        }
        return "unknown"
    }

    private func sendTestPush() async {
        do {
            let result = try await clientHolder.client.sendPushTest()
            let skipped = result.skipped ?? 0
            pushResult = "sent \(result.sent), failed \(result.failed)" + (skipped > 0 ? ", skipped \(skipped)" : "")
            lastError = nil
        } catch {
            lastError = "Test push failed: \(error.localizedDescription)"
        }
    }
}
