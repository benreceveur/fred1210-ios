import SwiftUI

/// Per-channel notification preferences. Users can mute (say) the daily
/// digest while still receiving urgent task alerts — each channel is
/// independent and stored per-device on the server.
struct NotificationSettingsView: View {
    @EnvironmentObject var pushManager: PushManager

    var body: some View {
        Form {
            Section {
                row(
                    "Daily digest",
                    "Morning briefing and scheduled summaries.",
                    systemImage: "sun.max",
                    isOn: binding(for: \.digest, key: "digest")
                )
                row(
                    "Urgent tasks",
                    "Overdue and in-progress task nudges.",
                    systemImage: "exclamationmark.circle",
                    isOn: binding(for: \.urgentTasks, key: "urgentTasks")
                )
                row(
                    "Research findings",
                    "Proactive research results and model evolution updates.",
                    systemImage: "doc.text.magnifyingglass",
                    isOn: binding(for: \.researchFindings, key: "researchFindings")
                )
                row(
                    "Transport alerts",
                    "Slack, Telegram, and provider health warnings.",
                    systemImage: "antenna.radiowaves.left.and.right",
                    isOn: binding(for: \.transportAlerts, key: "transportAlerts")
                )
                row(
                    "Needs approval",
                    "Recommendations Fred wants you to approve or dismiss.",
                    systemImage: "checkmark.seal",
                    isOn: binding(for: \.needsApproval, key: "needsApproval")
                )
                row(
                    "Security",
                    "Security posture findings and hardening work.",
                    systemImage: "lock.shield",
                    isOn: binding(for: \.security, key: "security")
                )
                row(
                    "Task completed",
                    "Work Fred finished without needing review.",
                    systemImage: "checkmark.circle",
                    isOn: binding(for: \.taskCompleted, key: "taskCompleted")
                )
                row(
                    "Fred blocked",
                    "Work stopped because Fred needs access, approval, or a decision.",
                    systemImage: "hand.raised",
                    isOn: binding(for: \.fredBlocked, key: "fredBlocked")
                )
                row(
                    "System health",
                    "Mac Mini, Docker, Tailscale, and runtime health changes.",
                    systemImage: "desktopcomputer.and.macbook",
                    isOn: binding(for: \.systemHealth, key: "systemHealth")
                )
            } header: {
                Text("Channels")
            } footer: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if pushManager.authState == .denied {
                        Text("System notifications are blocked. Enable them in Settings → Notifications first; channel preferences take effect once push is authorized.")
                    } else if !pushManager.preferencesLoaded {
                        Text("Preferences will sync after APNs registers this device.")
                    } else {
                        Text("Each channel is stored per-device. Muting one here does not affect other devices signed in to the same account.")
                    }
                    if let err = pushManager.lastError {
                        Text(err).foregroundStyle(Theme.error)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await pushManager.loadPreferences() }
    }

    @ViewBuilder
    private func row(
        _ title: String,
        _ subtitle: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(Theme.TextStyle.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.primary)
            }
        }
        .disabled(pushManager.authState == .denied)
    }

    /// Binds a single channel field to PushManager. Reading returns the
    /// current in-memory value; writing dispatches a PATCH and the
    /// resulting @Published update propagates back to the toggle.
    private func binding(
        for keyPath: KeyPath<PushManager.ChannelPreferences, Bool>,
        key: String
    ) -> Binding<Bool> {
        Binding(
            get: { pushManager.preferences[keyPath: keyPath] },
            set: { newValue in
                Task { await pushManager.updatePreferences([key: newValue]) }
            }
        )
    }
}
