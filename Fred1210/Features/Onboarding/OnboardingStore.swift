import Foundation
import SwiftUI

/// Tracks whether the user has completed first-run onboarding. Persisted to
/// UserDefaults — onboarding is a one-time flow, so the in-app screenshot env
/// var skips it for clean captures.
@MainActor
final class OnboardingStore: ObservableObject {
    private static let key = "fred.onboarding.completed.v1"

    @Published var isCompleted: Bool {
        didSet { UserDefaults.standard.set(isCompleted, forKey: Self.key) }
    }

    init() {
        if ProcessInfo.processInfo.environment["FRED_SCREENSHOT_MODE"] == "1" {
            // Treat onboarding as complete in screenshot mode so the dialog
            // never occludes captured pages. Doesn't touch persisted state.
            self.isCompleted = true
            return
        }
        self.isCompleted = UserDefaults.standard.bool(forKey: Self.key)
    }

    /// Reset to first-run state — only used by Settings → Diagnostics for
    /// re-running the onboarding manually.
    func reset() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        isCompleted = false
    }
}
