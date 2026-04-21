import Foundation
import LocalAuthentication

/// Thin wrapper around LocalAuthentication for gating destructive actions
/// (task delete, memory browsing) behind Face ID / Touch ID. Falls through
/// gracefully on simulators or devices without biometrics.
enum Biometrics {
    /// Prompt the user to authenticate. Returns true on success, false on
    /// cancel/failure. Never throws — callers can proceed on `false` by
    /// showing an error instead of crashing.
    @MainActor
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        // `.deviceOwnerAuthentication` accepts passcode as a fallback so the
        // flow still works on devices/simulators without Face ID enrolled.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics configured at all — treat as auto-pass so we don't
            // permanently lock the user out of their own app.
            return true
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
