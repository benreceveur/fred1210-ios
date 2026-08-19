import SwiftUI

/// 5-second undo toast — pinned to the bottom of the screen above the tab
/// bar. Fires `onUndo` when the user taps the "Undo" button, `onDismiss`
/// when they tap the "✕" close. The view model is responsible for the
/// 5-second auto-expiry; this view only renders.
struct UndoSnackbar: View {
    let title: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "trash")
                .foregroundStyle(Theme.textPrimary)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.TextStyle.footnoteSemibold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            Button {
                onUndo()
            } label: {
                Text("Undo")
                    .font(Theme.TextStyle.footnoteBold)
                    .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo delete")
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}
