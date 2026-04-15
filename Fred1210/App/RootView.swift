import SwiftUI

struct RootView: View {
    @EnvironmentObject var connectivity: Connectivity
    @EnvironmentObject var config: FredConfig

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }

            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }

            TaskListView()
                .tabItem { Label("Tasks", systemImage: "checklist") }

            VoiceView()
                .tabItem { Label("Voice", systemImage: "mic") }
        }
        .tint(Theme.primary)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !connectivity.isOnline {
                ConnectionBanner()
            }
        }
    }
}
