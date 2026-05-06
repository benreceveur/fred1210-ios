import Foundation
import AVFoundation

enum VoiceState: Equatable {
    case idle
    case recording
    case processing
    case playing
}

@MainActor
final class VoiceViewModel: NSObject, ObservableObject {
    @Published var state: VoiceState = .idle
    @Published var transcript: String = ""
    @Published var responseText: String = ""
    @Published var latency: LatencyBreakdown?
    @Published var displayError: FredDisplayError?
    /// Rolling buffer of recent input levels (newest last), 0..1. Drives
    /// the waveform view while recording.
    @Published private(set) var audioLevels: [Float] = Array(repeating: 0, count: 40)

    private var levelTimer: Timer?

    struct LatencyBreakdown: Equatable {
        let sttMs: Int
        let pipelineMs: Int
        let ttsMs: Int
        let totalMs: Int
    }

    private let client: FredClient
    private let recorder = AudioRecorder()
    private var player: AVAudioPlayer?

    init(client: FredClient) {
        self.client = client
    }

    func startHoldToTalk() async {
        guard state == .idle else { return }
        displayError = nil

        let granted = await recorder.requestPermission()
        guard granted else {
            displayError = FredDisplayError(
                endpoint: "Voice",
                primaryMessage: "Microphone permission denied",
                detailMessage: "Enable microphone access for Fred1210 in Settings → Privacy & Security → Microphone.",
                httpStatus: nil,
                retry: nil
            )
            return
        }

        do {
            try recorder.startRecording()
            state = .recording
            startLevelTimer()
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Start recording", retry: nil)
            state = .idle
        }
    }

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state == .recording else { return }
                let level = self.recorder.currentLevel()
                var next = self.audioLevels
                next.removeFirst()
                next.append(level)
                self.audioLevels = next
            }
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevels = Array(repeating: 0, count: audioLevels.count)
    }

    func stopHoldToTalk() async {
        guard state == .recording else { return }
        stopLevelTimer()
        guard let audioURL = recorder.stopRecording() else {
            state = .idle
            return
        }

        state = .processing
        do {
            let result = try await client.voiceTurn(audioFileURL: audioURL)
            transcript = result.transcript
            responseText = result.responseText
            latency = LatencyBreakdown(
                sttMs: result.sttMs,
                pipelineMs: result.pipelineMs,
                ttsMs: result.ttsMs,
                totalMs: result.totalMs
            )
            displayError = nil

            // Delete the recorded file now that the server has transcribed it.
            try? FileManager.default.removeItem(at: audioURL)

            // Play the synthesized response audio.
            await playResponse(result.audioData, mimeType: result.mimeType)
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Voice turn", retry: nil)
            state = .idle
            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    func runQuickCommand(_ command: String) async {
        guard state == .idle else { return }
        transcript = command
        responseText = ""
        latency = nil
        state = .processing
        do {
            let started = Date()
            let response = try await client.sendChatMessage(command)
            responseText = response.response
            latency = LatencyBreakdown(
                sttMs: 0,
                pipelineMs: Int(Date().timeIntervalSince(started) * 1000),
                ttsMs: 0,
                totalMs: Int(Date().timeIntervalSince(started) * 1000)
            )
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Voice command", retry: nil)
        }
        state = .idle
    }

    func clearError() { displayError = nil }

    private func playResponse(_ data: Data, mimeType: String) async {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            state = .playing
        } catch {
            displayError = FredDisplayError(
                endpoint: "Voice playback",
                primaryMessage: "Playback failed",
                detailMessage: error.localizedDescription,
                httpStatus: nil,
                retry: nil
            )
            state = .idle
        }
    }
}

// MARK: - Playback delegate

extension VoiceViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.player = nil
            self?.state = .idle
        }
    }
}
