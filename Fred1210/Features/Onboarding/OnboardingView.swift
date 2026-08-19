import SwiftUI

/// First-run onboarding: 3 steps — welcome, host URL + connection test,
/// notifications. Presented as a fullScreenCover from RootView so it
/// renders above tabs but isn't dismissable by swipe.
struct OnboardingView: View {
    @EnvironmentObject var fredConfig: FredConfig
    @EnvironmentObject var pushManager: PushManager
    @EnvironmentObject var clientHolder: ClientHolder
    @EnvironmentObject var onboarding: OnboardingStore

    @State private var step: Step = .welcome
    @State private var hostDraft: String = ""
    @State private var hostError: String?
    @State private var probing: Bool = false
    @State private var probeResult: ProbeResult?

    enum Step: Int, CaseIterable {
        case welcome
        case connect
        case notifications
    }

    enum ProbeResult: Equatable {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                Spacer(minLength: 0)
                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .connect: connectStep
                    case .notifications: notificationsStep
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer(minLength: 0)
                actionRow
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.bgDark)
            .navigationBarHidden(true)
            .onAppear {
                hostDraft = fredConfig.hostURL.absoluteString
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Theme.primary : Theme.border)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.lg)
    }

    // MARK: - Steps

    @ViewBuilder
    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            Text("Welcome to Fred")
                .font(Theme.TextStyle.titleBold)
                .foregroundStyle(Theme.textPrimary)
            Text("Your personal AI assistant. Fred runs on your Mac Mini at home; this app is the remote you carry with you.")
                .font(Theme.TextStyle.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                bulletRow(
                    icon: "tray.full",
                    title: "Inbox & approvals",
                    detail: "See what Fred wants you to decide."
                )
                bulletRow(
                    icon: "message",
                    title: "Chat anywhere",
                    detail: "Long-running research, code review, planning."
                )
                bulletRow(
                    icon: "mic",
                    title: "Voice when you can't type",
                    detail: "Walking the dog? Just ask out loud."
                )
            }
            .padding(.top, Theme.Spacing.md)
            Text("Heads up: you'll need to be on Tailscale to reach Fred. He lives behind your home VPN.")
                .font(Theme.TextStyle.footnote)
                .foregroundStyle(Theme.textMuted)
                .padding(.top, Theme.Spacing.md)
        }
    }

    @ViewBuilder
    private var connectStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Image(systemName: "network")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            Text("Connect to your Mac")
                .font(Theme.TextStyle.titleBold)
                .foregroundStyle(Theme.textPrimary)
            Text("Paste the Tailscale URL of the machine running Fred. It looks like https://your-mac.tail-xyz.ts.net.")
                .font(Theme.TextStyle.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Host URL")
                    .font(Theme.TextStyle.captionSemibold)
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                TextField("https://your-mac.tail-xyz.ts.net", text: $hostDraft)
                    .textFieldStyle(.plain)
                    .padding(Theme.Spacing.md)
                    .background(Theme.bgInput)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityLabel("Fred host URL")
                if let hostError {
                    Text(hostError)
                        .font(Theme.TextStyle.footnote)
                        .foregroundStyle(Theme.error)
                }
            }

            // Probe result panel
            if let result = probeResult {
                resultBanner(result)
            }

            Button {
                Task { await testConnection() }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    if probing {
                        ProgressView().tint(Theme.primary)
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
                    Text(probing ? "Testing…" : "Test connection")
                }
                .font(Theme.TextStyle.bodySemibold)
                .foregroundStyle(Theme.primary)
                .padding(.vertical, Theme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(Theme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            .disabled(probing)
            .accessibilityHint("Verify Fred is reachable at the URL above.")
        }
    }

    @ViewBuilder
    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            Text("Stay in the loop")
                .font(Theme.TextStyle.titleBold)
                .foregroundStyle(Theme.textPrimary)
            Text("Fred sends a push when something needs your decision, when long research finishes, or when a transport degrades. You can tune each channel later in Settings.")
                .font(Theme.TextStyle.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                channelRow(icon: "person.crop.circle.badge.exclamationmark", title: "Approvals", color: Theme.warning)
                channelRow(icon: "doc.text.magnifyingglass", title: "Research findings", color: Theme.info)
                channelRow(icon: "waveform.path.ecg", title: "Transport alerts", color: Theme.error)
                channelRow(icon: "sun.max", title: "Morning digests", color: Theme.primary)
            }
            .padding(.top, Theme.Spacing.md)
        }
    }

    // MARK: - Action row

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            if step != .welcome {
                Button("Back") {
                    advance(by: -1)
                }
                .font(Theme.TextStyle.bodySemibold)
                .foregroundStyle(Theme.textSecondary)
                .padding(.vertical, Theme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(Theme.bgInput)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
            Button(primaryButtonTitle) {
                Task { await primaryAction() }
            }
            .font(Theme.TextStyle.bodySemibold)
            .foregroundStyle(.white)
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(primaryButtonEnabled ? Theme.primary : Theme.primary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .disabled(!primaryButtonEnabled)
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: return "Get started"
        case .connect:
            if probeResult == .success { return "Continue" }
            return "Save & continue"
        case .notifications: return "Enable notifications"
        }
    }

    private var primaryButtonEnabled: Bool {
        switch step {
        case .welcome: return true
        case .connect: return !hostDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !probing
        case .notifications: return true
        }
    }

    private func primaryAction() async {
        switch step {
        case .welcome:
            advance(by: 1)
        case .connect:
            if probeResult == .success {
                // Already saved during the probe; just move on.
                advance(by: 1)
            } else {
                // Save the host then probe — if probe fails the user can
                // still continue (some users want to set up offline first).
                if await saveHost(skipProbeOnSuccess: false) {
                    advance(by: 1)
                }
            }
        case .notifications:
            await pushManager.requestAuthorizationIfNeeded()
            onboarding.isCompleted = true
        }
    }

    // MARK: - Helpers

    private func advance(by delta: Int) {
        let next = step.rawValue + delta
        guard let target = Step(rawValue: next) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            step = target
        }
    }

    private func testConnection() async {
        await saveHost(skipProbeOnSuccess: false)
    }

    /// Save the host URL and ping `/status`. Returns true if the host saved
    /// (probe result is reported via state, not return value). If the URL is
    /// malformed we keep the user on this step with an inline error.
    @discardableResult
    private func saveHost(skipProbeOnSuccess: Bool) async -> Bool {
        hostError = nil
        probeResult = nil
        do {
            try fredConfig.setHost(hostDraft)
        } catch {
            // setHost only throws for a genuinely malformed URL now (keychain
            // persistence is best-effort and never throws here). Surface the
            // real reason rather than a blanket "Invalid URL".
            hostError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
        probing = true
        defer { probing = false }
        do {
            _ = try await clientHolder.client.fetchAgentStatus()
            probeResult = .success
        } catch {
            // Saved the URL but couldn't reach Fred — the user might be off
            // Tailscale right now. Allow continuing.
            let message = (error as NSError).localizedDescription
            probeResult = .failure(message)
        }
        return true
    }

    // MARK: - View builders

    private func bulletRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.TextStyle.bodySemibold)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.TextStyle.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func channelRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.TextStyle.body)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private func resultBanner(_ result: ProbeResult) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected")
                        .font(Theme.TextStyle.subheadlineSemibold)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Fred answered. You're good to go.")
                        .font(Theme.TextStyle.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            case .failure(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn't reach Fred")
                        .font(Theme.TextStyle.subheadlineSemibold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(message)
                        .font(Theme.TextStyle.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.bgInput)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}
