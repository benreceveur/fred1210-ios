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
                                .font(.system(size: Theme.Font.xs))
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
                    HStack {
                        Label("Notifications", systemImage: "bell")
                        Spacer()
                        Text(pushStatusLabel)
                            .font(.system(size: Theme.Font.xs, weight: .semibold))
                            .foregroundStyle(pushStatusColor)
                    }
                    if pushManager.authState == .notDetermined {
                        Button("Enable push notifications") {
                            Task { await pushManager.requestAuthorizationIfNeeded() }
                        }
                    } else if pushManager.authState == .denied {
                        Text("Enable notifications for Fred1210 in System Settings → Notifications.")
                            .font(.system(size: Theme.Font.xs))
                            .foregroundStyle(Theme.textMuted)
                    } else if let lastReg = pushManager.lastRegistration {
                        Text("Token registered \(lastReg.relativeAge())")
                            .font(.system(size: Theme.Font.xs))
                            .foregroundStyle(Theme.textMuted)
                    }
                    if let err = pushManager.lastError {
                        Text(err)
                            .font(.system(size: Theme.Font.xs))
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
                        MemoryView()
                    } label: {
                        Label("Memory", systemImage: "brain")
                    }
                    NavigationLink {
                        ConnectivityView()
                    } label: {
                        Label("Connectivity", systemImage: "antenna.radiowaves.left.and.right")
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
}
