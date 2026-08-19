import SwiftUI

/// Consistent empty/first-run render. Used by the dashboard cards and
/// any list that can be empty.
struct EmptyState: View {
    let systemImage: String
    let title: String
    let detail: String?

    init(systemImage: String, title: String, detail: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(Theme.textMuted)
            Text(title)
                .font(Theme.TextStyle.subheadlineSemibold)
                .foregroundStyle(Theme.textPrimary)
            if let detail {
                Text(detail)
                    .font(Theme.TextStyle.footnote)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.lg)
    }
}
