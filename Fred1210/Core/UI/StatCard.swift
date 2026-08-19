import SwiftUI

/// Dashboard tile that shows one headline number and a short label. Kept
/// minimal so multiple side-by-side in a grid still read cleanly.
struct StatCard: View {
    let icon: String
    let iconTint: Color
    let stat: String
    let label: String
    let hint: String?
    let onTap: (() -> Void)?

    init(
        icon: String,
        iconTint: Color = Theme.primary,
        stat: String,
        label: String,
        hint: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.stat = stat
        self.label = label
        self.hint = hint
        self.onTap = onTap
    }

    var body: some View {
        Card(onTap: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconTint)
                Text(stat)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label.uppercased())
                    .font(Theme.TextStyle.captionSemibold)
                    .foregroundStyle(Theme.textMuted)
                    .tracking(0.5)
                if let hint {
                    Text(hint)
                        .font(Theme.TextStyle.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stat) \(label)\(hint.map { ", \($0)" } ?? "")")
    }
}
