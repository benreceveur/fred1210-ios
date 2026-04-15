import SwiftUI

struct ConnectionBanner: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(Theme.warning)
            Text("Offline — reconnect to Tailscale")
                .font(.system(size: Theme.Font.sm, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.lg)
        .background(Theme.warning.opacity(0.15))
        .overlay(alignment: .bottom) {
            Divider().background(Theme.warning.opacity(0.4))
        }
    }
}
