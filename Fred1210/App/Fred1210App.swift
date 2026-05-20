import SwiftUI

@main
struct Fred1210App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var connectivity = Connectivity()
    @StateObject private var fredConfig: FredConfig
    @StateObject private var clientHolder: ClientHolder
    @StateObject private var pushManager: PushManager
    @StateObject private var router = AppRouter()
    @StateObject private var reachability: FredReachability
    @StateObject private var onboarding = OnboardingStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let config = FredConfig()
        _fredConfig = StateObject(wrappedValue: config)
        let holder = ClientHolder(config: config)
        _clientHolder = StateObject(wrappedValue: holder)
        let push = PushManager(config: config)
        _pushManager = StateObject(wrappedValue: push)
        _reachability = StateObject(wrappedValue: FredReachability(client: holder.client))
        AppDelegate.pushManager = push
        AppDelegate.clientHolder = holder

        // Wire background refresh — iOS calls the handler every ~30 min
        // (at its discretion) to pre-fetch dashboard + tasks so the next
        // launch opens to live data.
        BackgroundRefresh.register { [weak holder] in
            guard let holder else { return }
            _ = try? await holder.client.fetchDashboard()
            _ = try? await holder.client.listTasks()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectivity)
                .environmentObject(fredConfig)
                .environmentObject(clientHolder)
                .environmentObject(pushManager)
                .environmentObject(router)
                .environmentObject(reachability)
                .environmentObject(onboarding)
                // No `.preferredColorScheme(.dark)` — Theme.bg* / Theme.text*
                // tokens adapt at the UIColor layer so the app follows the
                // user's system Appearance choice. See docs/design/tokens.md.
                .fullScreenCover(isPresented: .constant(!onboarding.isCompleted)) {
                    OnboardingView()
                        .environmentObject(fredConfig)
                        .environmentObject(pushManager)
                        .environmentObject(clientHolder)
                        .environmentObject(onboarding)
                }
                .task {
                    // First-launch push prompt only fires inside the
                    // onboarding flow now — but keep the BackgroundRefresh
                    // scheduling here so it runs on every cold start.
                    BackgroundRefresh.scheduleNext()
                }
                .onAppear { reachability.start() }
                .onChange(of: scenePhase) { phase in
                    // Pause polling when backgrounded so we don't churn
                    // battery on cellular. Resume on foreground.
                    switch phase {
                    case .active: reachability.start()
                    case .background, .inactive: reachability.stop()
                    @unknown default: break
                    }
                }
        }
    }
}

/// Holds the FredClient as an ObservableObject so SwiftUI can inject it into
/// views via @EnvironmentObject. Views read `holder.client` to make requests.
@MainActor
final class ClientHolder: ObservableObject {
    let client: FredClient

    init(config: FredConfig) {
        self.client = FredClient(config: config)
    }
}
