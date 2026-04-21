import SwiftUI

/// Primary surface container. Replaces ad-hoc `VStack { ... }
/// .background(Theme.bgCard)` scattered across screens. Supports an
/// optional tap action — when provided the card highlights on press and
/// announces as a button to VoiceOver.
struct Card<Content: View>: View {
    let onTap: (() -> Void)?
    let content: () -> Content

    @State private var isPressed = false

    init(onTap: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(isPressed ? Theme.bgCardHover : Theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard let onTap else { return }
                withAnimation(.easeOut(duration: 0.12)) { isPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.12)) { isPressed = false }
                    onTap()
                }
            }
            .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }
}
