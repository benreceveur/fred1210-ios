import Foundation
import AVFoundation

/// Thin wrapper around AVAudioRecorder that records m4a (AAC) to a temp
/// file. Designed for short hold-to-talk turns, not long-form capture.
@MainActor
final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    /// Requests microphone permission if needed. Returns true when granted.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fred-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000,
        ]
        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.prepareToRecord()
        rec.record()
        self.recorder = rec
        self.currentURL = url
    }

    /// Stops the recording and returns the file URL. Deactivates the audio
    /// session so playback can switch to the default output. The caller owns
    /// the returned file and is responsible for cleanup (FredClient.voiceTurn
    /// reads it into memory, then the file can be deleted).
    func stopRecording() -> URL? {
        recorder?.stop()
        let url = currentURL
        recorder = nil
        currentURL = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        return url
    }
}
