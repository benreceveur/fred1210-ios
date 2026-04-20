import SwiftUI

/// Lets the user change the Fred server host URL at runtime. The host is
/// persisted in Keychain via FredConfig and survives app reinstalls. This
/// screen is the fallback when the baked-in Info.plist default doesn't
/// match the user's deployment (e.g. a TestFlight build shipped with the
/// placeholder host, or the server moved to a different Tailscale
/// hostname).
struct SettingsView: View {
    @EnvironmentObject var config: FredConfig
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

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(Theme.error)
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

                    Button("Reset to Build Default", role: .destructive) {
                        Task { await viewModel.resetToBuildDefault(via: config) }
                    }
                    .disabled(viewModel.buildTimeDefault == nil)
                }

                Section("About") {
                    LabeledContent("Version", value: viewModel.appVersion)
                    LabeledContent("Build", value: viewModel.appBuild)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.syncFromConfig(config) }
        }
    }
}
