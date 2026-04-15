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
    @Published var errorMessage: String?

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
        errorMessage = nil

        let granted = await recorder.requestPermission()
        guard granted else {
            errorMessage = "Microphone permission denied"
            return
        }

        do {
            try recorder.startRecording()
            state = .recording
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            state = .idle
        }
    }

    func stopHoldToTalk() async {
        guard state == .recording else { return }
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

            // Delete the recorded file now that the server has transcribed it.
            try? FileManager.default.removeItem(at: audioURL)

            // Play the synthesized response audio.
            await playResponse(result.audioData, mimeType: result.mimeType)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .idle
            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    func clearError() { errorMessage = nil }

    private func playResponse(_ data: Data, mimeType: String) async {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            state = .playing
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
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
