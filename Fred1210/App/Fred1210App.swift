import SwiftUI

@main
struct Fred1210App: App {
    @StateObject private var connectivity = Connectivity()
    @StateObject private var fredConfig: FredConfig
    @StateObject private var clientHolder: ClientHolder

    init() {
        let config = FredConfig()
        _fredConfig = StateObject(wrappedValue: config)
        _clientHolder = StateObject(wrappedValue: ClientHolder(config: config))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectivity)
                .environmentObject(fredConfig)
                .environmentObject(clientHolder)
                .preferredColorScheme(.dark)
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
