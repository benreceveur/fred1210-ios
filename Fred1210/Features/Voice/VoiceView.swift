import SwiftUI

struct VoiceView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "mic.circle")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(Theme.primary)
                Text("Voice")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, Theme.Spacing.lg)
                Text("Phase 2 scaffold — AVAudioRecorder + multipart upload + playback land in task #19")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgDark)
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
