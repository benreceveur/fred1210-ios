import SwiftUI

/// Top-level Settings tab. Hosts host-URL config, diagnostics, and about
/// info. Kept intentionally small — deeper configuration (notification
/// channels, feature flags) arrives in later phases.
struct SettingsView: View {
    @EnvironmentObject var config: FredConfig
    @EnvironmentObject var pushManager: PushManager
    @StateObject private var viewModel = SettingsViewModel()
    @FocusState private var hostFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.ts.net", text: $viewModel.hostDraft)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($hostFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await viewModel.save(via: config) } }
                } header: {
                    Text("Fred Host")
                } footer: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("The URL the app connects to. Use your Tailscale-served Fred host (e.g. https://bobs-mac-mini.tail5a2996.ts.net).")
                        if let plist = viewModel.buildTimeDefault {
                            Text("Build default: \(plist)")
                                .font(Theme.TextStyle.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }

                if let saved = viewModel.savedMessage {
                    Section {
                        Label(saved, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.save(via: config) }
                    } label: {
                        HStack {
                            Text("Save")
                            Spacer()
                            if viewModel.isSaving { ProgressView().tint(Theme.primary) }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.hostDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Reset to build default", role: .destructive) {
                        Task { await viewModel.resetToBuildDefault(via: config) }
                    }
                    .disabled(viewModel.buildTimeDefault == nil)
                }

                Section {
                    diagnosticRow("Active", config.hostURL.absoluteString)
                    diagnosticRow("Stored (Keychain)", config.storedHostRaw ?? "—")
                    diagnosticRow("iCloud sync", config.icloudHostRaw ?? "—")
                    if let plist = viewModel.buildTimeDefault {
                        diagnosticRow("Build default", plist)
                    }
                } header: {
                    Text("Host Diagnostics")
                } footer: {
                    Text("If \"Active\" differs from what you typed, the URL was rejected by the parser and the fallback kicked in. The build default is the last-resort hardcoded URL — \"Reset to build default\" writes it directly to Keychain.")
                        .font(Theme.TextStyle.caption)
                        .foregroundStyle(Theme.textMuted)
                }

                Section {
                    HStack {
                        Label("Notifications", systemImage: "bell")
                        Spacer()
                        Text(pushStatusLabel)
                            .font(Theme.TextStyle.captionSemibold)
                            .foregroundStyle(pushStatusColor)
                    }
                    if pushManager.authState == .notDetermined {
                        Button("Enable push notifications") {
                            Task { await pushManager.requestAuthorizationIfNeeded() }
                        }
                    } else if pushManager.authState == .denied {
                        Text("Enable notifications for Fred1210 in System Settings → Notifications.")
                            .font(Theme.TextStyle.caption)
                            .foregroundStyle(Theme.textMuted)
                    } else if let lastReg = pushManager.lastRegistration {
                        Text("Token registered \(lastReg.relativeAge())")
                            .font(Theme.TextStyle.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    if let err = pushManager.lastError {
                        Text(err)
                            .font(Theme.TextStyle.caption)
                            .foregroundStyle(Theme.error)
                    }
                    // Channel-level mute/unmute lives behind its own screen
                    // to keep Settings scannable.
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notification channels", systemImage: "slider.horizontal.3")
                    }
                    .disabled(pushManager.authState == .denied)
                }

                Section {
                    NavigationLink {
                        DashboardView()
                    } label: {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                    NavigationLink {
                        MemoryView()
                    } label: {
                        Label("Memory", systemImage: "brain")
                    }
                    NavigationLink {
                        ConnectivityView()
                    } label: {
                        Label("Health console", systemImage: "waveform.path.ecg")
                    }
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "stethoscope")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: viewModel.appVersion)
                    LabeledContent("Build", value: viewModel.appBuild)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.syncFromConfig(config)
                Task { await pushManager.refreshAuthStatus() }
            }
        }
    }

    private var pushStatusLabel: String {
        switch pushManager.authState {
        case .notDetermined: return "OFF"
        case .authorized: return "ON"
        case .provisional: return "QUIET"
        case .denied: return "BLOCKED"
        }
    }

    private var pushStatusColor: Color {
        switch pushManager.authState {
        case .authorized, .provisional: return Theme.success
        case .denied: return Theme.error
        case .notDetermined: return Theme.textMuted
        }
    }

    /// One row in the Host Diagnostics section. Renders the label on
    /// the leading edge and the raw value on the trailing edge, with
    /// the value monospaced so subtle whitespace / hidden characters
    /// in a malformed stored URL are easier to spot.
    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Theme.TextStyle.captionSemibold)
                .foregroundStyle(Theme.textMuted)
            Spacer(minLength: Theme.Spacing.sm)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
