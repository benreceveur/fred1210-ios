import SwiftUI

struct RootView: View {
    @EnvironmentObject var connectivity: Connectivity
    @EnvironmentObject var config: FredConfig
    @State private var showingVoiceSheet = false

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }

            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }

            ApprovalsView()
                .tabItem { Label("Review", systemImage: "checkmark.seal") }

            TaskListView()
                .tabItem { Label("Tasks", systemImage: "checklist") }

            VoiceView()
                .tabItem { Label("Voice", systemImage: "mic") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(Theme.primary)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingVoiceSheet = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.primary)
                    .clipShape(Circle())
                    .shadow(color: Theme.primary.opacity(0.35), radius: 12, y: 6)
            }
            .padding(.trailing, Theme.Spacing.lg)
            .padding(.bottom, 74)
            .accessibilityLabel("Ask Fred by voice")
        }
        .sheet(isPresented: $showingVoiceSheet) {
            VoiceView()
                .presentationDetents([.large])
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !connectivity.isOnline {
                ConnectionBanner()
            }
        }
    }
}
