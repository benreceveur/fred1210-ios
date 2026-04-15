import SwiftUI

struct TaskListView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Tasks")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Phase 2 scaffold — list + create + swipe-to-delete lands in task #19")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgDark)
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
