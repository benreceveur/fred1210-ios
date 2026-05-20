import UIKit

/// Tiny wrapper around UIFeedbackGenerator so feature code reads as
/// `Haptics.send()` instead of allocating + preparing + firing on every site.
/// Each call is fire-and-forget — no need to retain a generator.
///
/// Honors Reduce Motion: when the system has reduce-motion enabled we still
/// fire haptics (they're a separate accessibility setting in iOS — many users
/// rely on them precisely because they reduce visual motion). Users who want
/// haptics off can disable system haptics in Settings → Sounds & Haptics.
enum Haptics {
    /// Confirm a small action — pressing send, opening a sheet, toggling.
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Confirm a meaningful action — completing a task, approving a
    /// recommendation. Heavier than `tap` to feel like a "click."
    static func confirm() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Notify success after an async action lands.
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Notify a destructive action lands (delete, dismiss).
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Notify failure — couldn't reach Fred, validation error.
    static func failure() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
