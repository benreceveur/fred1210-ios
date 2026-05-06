import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var hostDraft: String = ""
    @Published private(set) var isSaving = false
    @Published var savedMessage: String?

    /// Surfaced in the UI so users can see what the installed build
    /// shipped with — handy when diagnosing "app can't connect".
    let buildTimeDefault: String? = {
        FredConfig.normalizedHost(Bundle.main.object(forInfoDictionaryKey: "FredDefaultHost") as? String)
    }()

    let appVersion: String = {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
    }()

    let appBuild: String = {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "—"
    }()

    func syncFromConfig(_ config: FredConfig) {
        if hostDraft.isEmpty {
            hostDraft = config.hostURL.absoluteString
        }
    }

    func save(via config: FredConfig) async {
        let trimmed = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        savedMessage = nil
        do {
            try config.setHost(trimmed)
            savedMessage = "Saved. Pull to refresh any tab to reconnect."
        } catch {
            savedMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func resetToBuildDefault(via config: FredConfig) async {
        guard let fallback = buildTimeDefault else { return }
        hostDraft = fallback
        await save(via: config)
    }
}
