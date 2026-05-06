import SwiftUI

struct RootView: View {
    @EnvironmentObject var connectivity: Connectivity
    @EnvironmentObject var config: FredConfig
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var clientHolder: ClientHolder
    @State private var showingVoiceSheet = false

    var body: some View {
        TabView(selection: $router.selectedTab) {
            FredInboxView()
                .tabItem { Label("Inbox", systemImage: "tray.full") }
                .tag(AppRouter.Tab.inbox)

            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }
                .tag(AppRouter.Tab.chat)

            ApprovalsView()
                .tabItem { Label("Review", systemImage: "checkmark.seal") }
                .tag(AppRouter.Tab.review)

            TaskListView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(AppRouter.Tab.tasks)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppRouter.Tab.settings)
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
        .sheet(item: $router.activeSheet) { sheet in
            routedSheet(sheet)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fredRouteRequested)) { notification in
            router.route(from: notification.userInfo ?? [:])
        }
        .onOpenURL { url in
            router.route(url: url)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !connectivity.isOnline {
                ConnectionBanner()
            }
        }
    }

    @ViewBuilder
    private func routedSheet(_ sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .task(let id):
            StandaloneTaskDetailView(taskId: id)
                .environmentObject(clientHolder)
        case .recommendation(let id):
            RecommendationDetailSheet(recommendationId: id)
                .environmentObject(clientHolder)
        case .research(let id, let title):
            NavigationStack {
                ResearchDetailView(itemId: id, fallbackTitle: title)
                    .environmentObject(clientHolder)
            }
        case .health:
            NavigationStack {
                ConnectivityView()
                    .environmentObject(clientHolder)
            }
        }
    }
}
