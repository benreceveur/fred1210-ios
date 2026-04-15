import SwiftUI

struct ChatView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Chat")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Phase 2 scaffold — view model + send flow lands in task #19")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, Theme.Spacing.sm)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgDark)
            .navigationTitle("Fred")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
