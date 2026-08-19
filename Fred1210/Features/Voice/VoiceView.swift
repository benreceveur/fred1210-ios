import SwiftUI

struct VoiceView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        VoiceContentView(client: clientHolder.client)
    }
}

private struct VoiceContentView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: VoiceViewModel

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: VoiceViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                resultsPane
                if viewModel.state == .recording {
                    WaveformView(levels: viewModel.audioLevels)
                        .frame(height: 60)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .transition(.opacity)
                }
                latencyOverlay
                buttonArea
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.state)
            .background(Theme.bgDark)
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = viewModel.displayError {
                    ErrorBanner(error: error, onDismiss: viewModel.clearError)
                }
            }
            .task {
                // Long-press path: caller opened the sheet via gesture with
                // voiceAutoStart=true. Fire recording immediately and clear
                // the flag so future "tap to open" presentations stay idle.
                if router.voiceAutoStart {
                    router.voiceAutoStart = false
                    Haptics.confirm()
                    await viewModel.startHoldToTalk()
                }
            }
        }
    }

    @ViewBuilder
    private var resultsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if !viewModel.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOU")
                            .font(Theme.TextStyle.captionBold)
                            .foregroundStyle(Theme.textMuted)
                        Text(viewModel.transcript)
                            .font(Theme.TextStyle.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .textSelection(.enabled)
                    }
                }
                if !viewModel.responseText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FRED")
                            .font(Theme.TextStyle.captionBold)
                            .foregroundStyle(Theme.primary)
                        Text(viewModel.responseText)
                            .font(Theme.TextStyle.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                    }
                }
                if viewModel.transcript.isEmpty && viewModel.responseText.isEmpty {
                    quickCommands
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(maxHeight: .infinity)
    }

    private var quickCommands: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach([
                "What needs my attention?",
                "Run a Fred health check",
                "Summarize open security work",
                "What did Fred finish today?"
            ], id: \.self) { command in
                Button {
                    Task { await viewModel.runQuickCommand(command) }
                } label: {
                    HStack {
                        Image(systemName: "bolt.circle")
                            .foregroundStyle(Theme.primary)
                        Text(command)
                            .font(Theme.TextStyle.footnoteSemibold)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var latencyOverlay: some View {
        if let latency = viewModel.latency {
            HStack(spacing: Theme.Spacing.lg) {
                latencyChip(label: "STT", ms: latency.sttMs)
                latencyChip(label: "Pipeline", ms: latency.pipelineMs)
                latencyChip(label: "TTS", ms: latency.ttsMs)
                latencyChip(label: "Total", ms: latency.totalMs, highlight: true)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private func latencyChip(label: String, ms: Int, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Text(ms < 1000 ? "\(ms)ms" : String(format: "%.1fs", Double(ms) / 1000))
                .font(Theme.TextStyle.captionBold)
                .foregroundStyle(highlight ? Theme.primary : Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var buttonArea: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {} label: {
                ZStack {
                    Circle()
                        .fill(recordButtonColor)
                        .frame(width: 120, height: 120)
                        .overlay(Circle().stroke(Theme.primary, lineWidth: 3))
                    if viewModel.state == .processing {
                        ProgressView().tint(.white).scaleEffect(1.5)
                    } else {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 48))
                            .foregroundStyle(viewModel.state == .recording ? .white : Theme.textPrimary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.state == .processing || viewModel.state == .playing)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0)
                    .onEnded { _ in
                        Task { await viewModel.startHoldToTalk() }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        Task { await viewModel.stopHoldToTalk() }
                    }
            )

            Text(stateText)
                .font(Theme.TextStyle.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 60)
    }

    private var recordButtonColor: Color {
        switch viewModel.state {
        case .recording: return Theme.error
        case .processing, .playing: return Theme.bgCard.opacity(0.6)
        case .idle: return Theme.bgCard
        }
    }

    private var buttonIcon: String {
        switch viewModel.state {
        case .recording: return "mic.fill"
        case .playing: return "speaker.wave.3.fill"
        case .processing, .idle: return "mic"
        }
    }

    private var stateText: String {
        switch viewModel.state {
        case .idle: return "Hold to talk"
        case .recording: return "Listening..."
        case .processing: return "Processing..."
        case .playing: return "Speaking..."
        }
    }
}
