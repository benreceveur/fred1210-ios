import SwiftUI

@main
struct Fred1210App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var connectivity = Connectivity()
    @StateObject private var fredConfig: FredConfig
    @StateObject private var clientHolder: ClientHolder
    @StateObject private var pushManager: PushManager
    @StateObject private var router = AppRouter()

    init() {
        let config = FredConfig()
        _fredConfig = StateObject(wrappedValue: config)
        let holder = ClientHolder(config: config)
        _clientHolder = StateObject(wrappedValue: holder)
        let push = PushManager(config: config)
        _pushManager = StateObject(wrappedValue: push)
        AppDelegate.pushManager = push

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
                .preferredColorScheme(.dark)
                .task {
                    // Ask once per install; iOS remembers the answer so
                    // subsequent launches are no-ops unless the user
                    // changes it in system Settings.
                    await pushManager.requestAuthorizationIfNeeded()
                    BackgroundRefresh.scheduleNext()
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
