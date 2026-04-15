import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Dashboard")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Phase 2 scaffold — status + usage + tasks + transport cards land in task #19")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgDark)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
