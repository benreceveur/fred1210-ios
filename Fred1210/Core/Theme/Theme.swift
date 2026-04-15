import SwiftUI

/// Design tokens mirroring the React Native theme in fred1210-mobile/src/theme.ts
/// and the admin UI palette in src/client. Keep these values in sync so all
/// Fred clients share one visual identity.
enum Theme {
    // Brand
    static let primary = Color(red: 108/255, green: 92/255, blue: 231/255)   // #6c5ce7
    static let primaryLight = Color(red: 162/255, green: 155/255, blue: 254/255) // #a29bfe
    static let primaryDark = Color(red: 74/255, green: 63/255, blue: 181/255)  // #4a3fb5

    // Backgrounds
    static let bgDark = Color(red: 10/255, green: 15/255, blue: 28/255)       // #0a0f1c
    static let bgCard = Color(red: 17/255, green: 24/255, blue: 39/255)       // #111827
    static let bgCardHover = Color(red: 26/255, green: 34/255, blue: 54/255)  // #1a2236
    static let bgInput = Color(red: 30/255, green: 41/255, blue: 59/255)      // #1e293b

    // Text
    static let textPrimary = Color(red: 226/255, green: 232/255, blue: 240/255) // #e2e8f0
    static let textSecondary = Color(red: 148/255, green: 163/255, blue: 184/255) // #94a3b8
    static let textMuted = Color(red: 100/255, green: 116/255, blue: 139/255)    // #64748b

    // Semantic
    static let success = Color(red: 34/255, green: 197/255, blue: 94/255)   // #22c55e
    static let warning = Color(red: 245/255, green: 158/255, blue: 11/255)  // #f59e0b
    static let error = Color(red: 239/255, green: 68/255, blue: 68/255)     // #ef4444
    static let info = Color(red: 59/255, green: 130/255, blue: 246/255)     // #3b82f6

    // Borders
    static let border = Color(red: 30/255, green: 41/255, blue: 59/255)         // #1e293b
    static let borderLight = Color(red: 51/255, green: 65/255, blue: 85/255)    // #334155

    // Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // Font sizes
    enum Font {
        static let xs: CGFloat = 11
        static let sm: CGFloat = 13
        static let md: CGFloat = 15
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
    }

    // Border radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }
}
