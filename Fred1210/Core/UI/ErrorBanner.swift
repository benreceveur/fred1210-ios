import SwiftUI

/// Inline error card shown at the top of a screen when a fetch fails. Shows
/// the failing endpoint, an HTTP status when available, and a one-tap retry
/// button. Replaces the previous `.alert("Error", isPresented:)` pattern
/// that surfaced nothing but `"error"` and left the user with no recourse.
///
/// Pair with ``FredDisplayError`` + a view model's `displayError: FredDisplayError?`
/// and mount via ``.safeAreaInset(edge:)`` or inline in the view body.
struct ErrorBanner: View {
    let error: FredDisplayError
    var onDismiss: () -> Void = {}

    @State private var isRetrying = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Theme.Font.lg))
                .foregroundStyle(Theme.error)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(error.title)
                    .font(.system(size: Theme.Font.sm, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(error.body)
                    .font(.system(size: Theme.Font.xs))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)

                HStack(spacing: Theme.Spacing.md) {
                    if let retry = error.retry {
                        Button {
                            Task {
                                isRetrying = true
                                await retry()
                                isRetrying = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isRetrying {
                                    ProgressView().controlSize(.small).tint(Theme.primary)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Retry")
                            }
                            .font(.system(size: Theme.Font.xs, weight: .semibold))
                        }
                        .disabled(isRetrying)
                        .tint(Theme.primary)
                    }

                    Button("Dismiss", action: onDismiss)
                        .font(.system(size: Theme.Font.xs))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.error.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }
}

#Preview {
    VStack {
        ErrorBanner(
            error: FredDisplayError(
                endpoint: "Dashboard",
                primaryMessage: "Server error",
                detailMessage: "The request timed out after 120 seconds. Check Tailscale is connected.",
                httpStatus: 504,
                retry: {}
            )
        )
        Spacer()
    }
    .background(Theme.bgDark)
}
