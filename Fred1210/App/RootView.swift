import SwiftUI

struct RootView: View {
    @EnvironmentObject var connectivity: Connectivity
    @EnvironmentObject var config: FredConfig
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        TabView(selection: $router.selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "rectangle.3.group.bubble.left") }
                .tag(AppRouter.Tab.dashboard)

            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }
                .tag(AppRouter.Tab.chat)

            ApprovalsView()
                .tabItem { Label("Approvals", systemImage: "checkmark.seal") }
                .tag(AppRouter.Tab.review)

            TaskListView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(AppRouter.Tab.tasks)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppRouter.Tab.settings)
        }
        .tint(Theme.primary)
        .sheet(isPresented: $router.isShowingVoiceSheet) {
            VoiceView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $router.isShowingQuickCapture) {
            QuickCaptureSheet()
                .environmentObject(clientHolder)
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
        case .inbox:
            NavigationStack {
                FredInboxView()
                    .environmentObject(clientHolder)
            }
        }
    }
}
