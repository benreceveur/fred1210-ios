import SwiftUI

@main
struct Fred1210App: App {
    @StateObject private var connectivity = Connectivity()
    @StateObject private var fredConfig = FredConfig()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectivity)
                .environmentObject(fredConfig)
                .preferredColorScheme(.dark)
        }
    }
}
