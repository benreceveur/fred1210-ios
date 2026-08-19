import SwiftUI
import UIKit

/// Design tokens for the iOS surface.
///
/// Canonical reference: `Fred1210/docs/design/tokens.md`. When changing a token,
/// update the doc first, then propagate to `fred1210-mobile/src/theme.ts` and
/// `src/client/styles.css` in the same change. Note that web uses GitHub
/// Primer's `#58a6ff` for operator chrome alongside the brand purple — this is
/// intentional and documented in tokens.md.
///
/// Colors are adaptive (light + dark). Text uses SwiftUI text styles via
/// `Theme.TextStyle` so Dynamic Type works — never use raw point sizes for
/// user-visible text.
enum Theme {
    // MARK: - Brand (static across modes)

    static let primary = Color(red: 108/255, green: 92/255, blue: 231/255)        // #6c5ce7
    static let primaryLight = Color(red: 162/255, green: 155/255, blue: 254/255)  // #a29bfe
    static let primaryDark = Color(red: 74/255, green: 63/255, blue: 181/255)     // #4a3fb5

    // MARK: - Surfaces (adaptive)
    //
    // Each token has both a `_UI` form (the underlying dynamic UIColor —
    // canonical source of truth, also used by tests to verify dual-mode
    // resolution) and a `Color` form that views consume.

    static let bgDarkUI = dynamicUI(
        dark: rgb(10, 15, 28),          // #0a0f1c
        light: rgb(255, 255, 255)       // #ffffff
    )
    static let bgDark = Color(uiColor: bgDarkUI)

    static let bgCardUI = dynamicUI(
        dark: rgb(17, 24, 39),          // #111827
        light: rgb(246, 248, 250)       // #f6f8fa
    )
    static let bgCard = Color(uiColor: bgCardUI)

    static let bgCardHoverUI = dynamicUI(
        dark: rgb(26, 34, 54),          // #1a2236
        light: rgb(238, 241, 244)       // #eef1f4
    )
    static let bgCardHover = Color(uiColor: bgCardHoverUI)

    static let bgInputUI = dynamicUI(
        dark: rgb(30, 41, 59),          // #1e293b
        light: rgb(240, 242, 245)       // #f0f2f5
    )
    static let bgInput = Color(uiColor: bgInputUI)

    // MARK: - Text (adaptive)

    static let textPrimaryUI = dynamicUI(
        dark: rgb(226, 232, 240),       // #e2e8f0
        light: rgb(31, 35, 40)          // #1f2328
    )
    static let textPrimary = Color(uiColor: textPrimaryUI)

    static let textSecondaryUI = dynamicUI(
        dark: rgb(148, 163, 184),       // #94a3b8
        light: rgb(50, 56, 63)          // #32383f
    )
    static let textSecondary = Color(uiColor: textSecondaryUI)

    static let textMutedUI = dynamicUI(
        dark: rgb(100, 116, 139),       // #64748b
        light: rgb(101, 109, 118)       // #656d76
    )
    static let textMuted = Color(uiColor: textMutedUI)

    // MARK: - Semantic (static across modes — these read well on both)

    static let success = Color(red: 34/255, green: 197/255, blue: 94/255)   // #22c55e
    static let warning = Color(red: 245/255, green: 158/255, blue: 11/255)  // #f59e0b
    static let error = Color(red: 239/255, green: 68/255, blue: 68/255)     // #ef4444
    static let info = Color(red: 59/255, green: 130/255, blue: 246/255)     // #3b82f6

    // MARK: - Borders (adaptive)

    static let borderUI = dynamicUI(
        dark: rgb(30, 41, 59),          // #1e293b
        light: rgb(208, 215, 222)       // #d0d7de (Primer light border)
    )
    static let border = Color(uiColor: borderUI)

    static let borderLightUI = dynamicUI(
        dark: rgb(51, 65, 85),          // #334155
        light: rgb(216, 222, 228)       // #d8dee4
    )
    static let borderLight = Color(uiColor: borderLightUI)

    // MARK: - Spacing scale

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Font point sizes
    //
    // Kept as raw points for icon sizing and chrome only — e.g.
    // `Image(systemName:).font(.system(size: Theme.Font.lg, weight: .semibold))`.
    // Never use these for user-visible *text* — use `Theme.TextStyle` instead so
    // Dynamic Type works.

    enum Font {
        static let xs: CGFloat = 11
        static let sm: CGFloat = 13
        static let md: CGFloat = 15
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
    }

    // MARK: - Text styles (Dynamic-Type-aware)
    //
    // Map of approximate former point sizes → SwiftUI text styles:
    //   xs  (11)  → .caption    (12 default)
    //   sm  (13)  → .footnote   (13 default)
    //   md  (15)  → .subheadline(15 default)
    //   lg  (18)  → .body       (17 default)
    //   xl  (22)  → .title3     (20 default)
    //   xxl (28)  → .title      (28 default)
    //
    // All scale with Settings → Display & Brightness → Text Size and with
    // Larger Accessibility Sizes.

    enum TextStyle {
        static let caption: SwiftUI.Font = .caption
        static let footnote: SwiftUI.Font = .footnote
        static let subheadline: SwiftUI.Font = .subheadline
        static let body: SwiftUI.Font = .body
        static let headline: SwiftUI.Font = .headline
        static let title3: SwiftUI.Font = .title3
        static let title2: SwiftUI.Font = .title2
        static let title: SwiftUI.Font = .title

        // Common weighted variants
        static let captionSemibold: SwiftUI.Font = .caption.weight(.semibold)
        static let captionBold: SwiftUI.Font = .caption.weight(.bold)
        static let footnoteSemibold: SwiftUI.Font = .footnote.weight(.semibold)
        static let footnoteBold: SwiftUI.Font = .footnote.weight(.bold)
        static let subheadlineSemibold: SwiftUI.Font = .subheadline.weight(.semibold)
        static let subheadlineBold: SwiftUI.Font = .subheadline.weight(.bold)
        static let bodySemibold: SwiftUI.Font = .body.weight(.semibold)
        static let title3Bold: SwiftUI.Font = .title3.weight(.bold)
        static let titleBold: SwiftUI.Font = .title.weight(.bold)
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // MARK: - Helpers

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    /// Returns a dynamic `UIColor` that resolves at render time based on
    /// `UITraitCollection.userInterfaceStyle`. Kept as `UIColor` (not wrapped
    /// in `Color`) so callers and tests can resolve against arbitrary trait
    /// collections — wrapping into `Color` and back loses the dynamic
    /// provider on iOS 17+.
    private static func dynamicUI(dark: UIColor, light: UIColor) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        }
    }
}
