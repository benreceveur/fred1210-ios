import SwiftUI

struct ChatView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        ChatContentView(client: clientHolder.client)
    }
}

/// PreferenceKey reporting the vertical distance between the last message and
/// the bottom of the visible scroll viewport. Negative or near-zero means the
/// user is parked at the bottom; large positive means they've scrolled up to
/// read history and we must not yank them back.
private struct ChatBottomOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ChatContentView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var inputFocused: Bool
    /// True when the bottom of the conversation is inside (or very close to)
    /// the viewport. Drives the auto-scroll decision and the "new messages"
    /// pill visibility.
    @State private var isAtBottom: Bool = true
    /// Number of new messages that landed while the user was scrolled up.
    /// Drives the badge on the "new messages" pill.
    @State private var unreadWhileScrolledUp: Int = 0
    /// Last observed message count — kept so the iOS 16 single-argument
    /// `onChange` closure can compute the delta.
    @State private var lastObservedMessageCount: Int = 0

    /// Distance (in points) within which we consider the user "at the
    /// bottom." Bigger than 0 so a tiny rubber-band offset doesn't make us
    /// stop auto-scrolling.
    private static let bottomStickThreshold: CGFloat = 120

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hidden keyboard-shortcut hook: ⌘K focuses the input from
                // anywhere on the screen. Zero-sized so it doesn't take
                // layout space; iOS still resolves the shortcut.
                Button {
                    inputFocused = true
                } label: {
                    EmptyView()
                }
                .keyboardShortcut("k", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)

                if viewModel.isSending {
                    TurnProgressBanner(
                        phase: viewModel.turnPhase,
                        toolCount: viewModel.activeTools.count,
                        startedAt: viewModel.turnStartedAt
                    )
                }
                messagesList
                Divider().background(Theme.border)
                inputBar
            }
            .background(Theme.bgDark)
            .navigationTitle("Fred")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        router.isShowingQuickCapture = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .accessibilityLabel("Quick capture task")
                    }
                    Button {
                        router.isShowingVoiceSheet = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .accessibilityLabel("Ask Fred by voice")
                            .accessibilityHint("Long-press to start recording immediately")
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            router.voiceAutoStart = true
                            router.isShowingVoiceSheet = true
                        }
                    )
                }
            }
            // Toolbar search field — collapses to the magnifier when
            // empty, expands when tapped. Filters the loaded history
            // on-device; server pagination will come when /history gains
            // a since cursor.
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search chat"
            )
            .task { await viewModel.loadHistory() }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = viewModel.displayError {
                    ErrorBanner(error: error, onDismiss: viewModel.clearError)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if viewModel.isLoadingHistory && viewModel.messages.isEmpty {
                        ProgressView()
                            .tint(Theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xxl)
                    } else if viewModel.messages.isEmpty {
                        Text("Say hi to Fred.")
                            .font(Theme.TextStyle.subheadline)
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xxl)
                    } else {
                        let groups = groupedByRole(viewModel.visibleMessages)
                        if groups.isEmpty && !viewModel.searchQuery.isEmpty {
                            Text("No messages match '\(viewModel.searchQuery)'.")
                                .font(Theme.TextStyle.footnote)
                                .foregroundStyle(Theme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.top, Theme.Spacing.xxl)
                        }
                        ForEach(Array(groups.enumerated()), id: \.offset) { groupIdx, group in
                            ChatGroupView(
                                role: group.role,
                                messages: group.messages,
                                query: viewModel.searchQuery
                            )
                            .id(groupIdx)
                        }
                        // In-flight tool chips: visible only while the
                        // current turn is streaming. They vanish as soon as
                        // the final assistant message lands.
                        if !viewModel.activeTools.isEmpty {
                            ToolActivityStack(activities: viewModel.activeTools)
                                .id("tool-activity")
                        }
                        // Invisible probe pinned to the very end of the
                        // content. Its frame minY relative to the scroll
                        // view's bottom tells us whether the user is parked
                        // at the bottom or has scrolled up to read history.
                        Color.clear
                            .frame(height: 1)
                            .id("chat-bottom-anchor")
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: ChatBottomOffsetKey.self,
                                        value: proxy.frame(in: .named("chatScroll")).maxY
                                    )
                                }
                            )
                    }
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xs)
            }
            .coordinateSpace(name: "chatScroll")
            .overlay(alignment: .bottomTrailing) {
                if !isAtBottom && unreadWhileScrolledUp > 0 {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
                        }
                        unreadWhileScrolledUp = 0
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "arrow.down")
                            Text("\(unreadWhileScrolledUp) new")
                                .font(Theme.TextStyle.footnoteSemibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                        .shadow(color: Theme.primary.opacity(0.4), radius: 8, y: 3)
                    }
                    .padding(Theme.Spacing.md)
                    .accessibilityLabel("Scroll to \(unreadWhileScrolledUp) new messages")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onPreferenceChange(ChatBottomOffsetKey.self) { maxY in
                // Read the bottom anchor's maxY in the scroll-view coordinate
                // space. We don't know the viewport height here, but the key
                // signal is "is the anchor on-screen?" — when it is, maxY
                // becomes finite and small relative to the typical scroll
                // height. Use a generous threshold instead of an exact
                // viewport intersect.
                let nowAtBottom = maxY > 0 && maxY < UIScreen.main.bounds.height + Self.bottomStickThreshold
                if nowAtBottom != isAtBottom {
                    isAtBottom = nowAtBottom
                    if nowAtBottom { unreadWhileScrolledUp = 0 }
                }
            }
            .onChange(of: viewModel.messages.count) { newCount in
                let oldCount = lastObservedMessageCount
                lastObservedMessageCount = newCount
                guard newCount > 0 else { return }
                let lastMessageIsUser = viewModel.messages.last?.role == .user
                if isAtBottom || lastMessageIsUser {
                    // Standard case: user is parked at the bottom or just sent
                    // a message — follow along.
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
                    }
                    unreadWhileScrolledUp = 0
                } else if newCount > oldCount {
                    // User is reading history. Don't yank them away — surface
                    // the new messages via the bottom pill instead.
                    unreadWhileScrolledUp += (newCount - oldCount)
                }
            }
            .refreshable { await viewModel.loadHistory() }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            TextField("Message", text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(Theme.Spacing.md)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.bgInput)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { Task { await viewModel.send() } }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { inputFocused = false }
                    }
                }

            Button {
                Haptics.tap()
                Task { await viewModel.send() }
            } label: {
                if viewModel.isSending {
                    ProgressView()
                        .tint(isSendDisabled ? Theme.textMuted : .white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        // P2: contrast-safe disabled state. White paperplane
                        // on translucent purple failed WCAG non-text contrast;
                        // muted glyph on neutral input surface is well above
                        // 3:1.
                        .foregroundStyle(isSendDisabled ? Theme.textMuted : .white)
                        .frame(width: 24, height: 24)
                }
            }
            // ⌘↩ sends, even when focus is elsewhere on the chat view (e.g.
            // user just tapped a tool chip). Pairs with ⌘K below to refocus
            // the input from anywhere on iPad with a hardware keyboard.
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityHint("Send message. Keyboard shortcut: Command Return.")
            .frame(width: 44, height: 44)
            .background(isSendDisabled ? Theme.bgInput : Theme.primary)
            .clipShape(Circle())
            .accessibilityLabel("Send message")
            .disabled(isSendDisabled)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.bgCard)
    }

    private var isSendDisabled: Bool {
        viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
    }

    // MARK: -

    private struct Group {
        let role: Components.Schemas.ChatMessage.RolePayload
        let messages: [Components.Schemas.ChatMessage]
    }

    /// Collapses runs of same-role messages into a single group so only
    /// one "YOU" / "FRED" label shows per turn — reduces visual noise in
    /// long tool-rich conversations.
    private func groupedByRole(_ messages: [Components.Schemas.ChatMessage]) -> [Group] {
        var groups: [Group] = []
        var current: [Components.Schemas.ChatMessage] = []
        var currentRole: Components.Schemas.ChatMessage.RolePayload?
        for message in messages {
            if message.role == currentRole {
                current.append(message)
            } else {
                if let role = currentRole, !current.isEmpty {
                    groups.append(Group(role: role, messages: current))
                }
                current = [message]
                currentRole = message.role
            }
        }
        if let role = currentRole, !current.isEmpty {
            groups.append(Group(role: role, messages: current))
        }
        return groups
    }
}

private struct TurnProgressBanner: View {
    let phase: String
    let toolCount: Int
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView()
                    .tint(Theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase)
                        .font(Theme.TextStyle.footnoteSemibold)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(toolCount) tool\(toolCount == 1 ? "" : "s") used\(elapsedText(now: context.date))")
                        .font(Theme.TextStyle.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "livephoto")
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.bgInput)
        }
    }

    private func elapsedText(now: Date) -> String {
        guard let startedAt else { return "" }
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        return " · \(seconds)s"
    }
}

// MARK: - Role group view

private struct ChatGroupView: View {
    let role: Components.Schemas.ChatMessage.RolePayload
    let messages: [Components.Schemas.ChatMessage]
    let query: String

    var body: some View {
        HStack(alignment: .top) {
            if role == .user { Spacer(minLength: 40) }
            VStack(alignment: role == .user ? .trailing : .leading, spacing: 4) {
                Text(label)
                    .font(Theme.TextStyle.captionSemibold)
                    .foregroundStyle(Theme.textMuted)
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    HighlightedText(message.content, query: query)
                        .font(Theme.TextStyle.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Theme.Spacing.md)
                        .background(bubbleColor)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
                }
            }
            if role != .user { Spacer(minLength: 40) }
        }
    }

    private var label: String {
        switch role {
        case .user: return "YOU"
        case .assistant: return "FRED"
        case .system: return "SYSTEM"
        }
    }

    private var bubbleColor: Color {
        switch role {
        case .user: return Theme.primary.opacity(0.25)
        case .assistant: return Theme.bgCard
        case .system: return Theme.warning.opacity(0.15)
        }
    }
}

/// Renders the message text, highlighting any substring that matches the
/// current search query. Falls back to plain text when query is empty.
private struct HighlightedText: View {
    let text: String
    let query: String

    init(_ text: String, query: String) {
        self.text = text
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        guard !query.isEmpty else { return Text(text) }
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var searchStart = lowerText.startIndex
        while searchStart < lowerText.endIndex,
              let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            // Convert String.Index range to AttributedString range.
            let startOffset = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
            let endOffset = lowerText.distance(from: lowerText.startIndex, to: range.upperBound)
            if let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: startOffset),
               let attrEnd = attributed.index(attributed.startIndex, offsetByCharacters: endOffset) {
                let attrRange = attrStart..<attrEnd
                // P1: bumped from 0.4 → 0.65 so the highlight passes WCAG
                // non-text 3:1 contrast against both light and dark bubble
                // surfaces. Foreground stays textPrimary so contrast against
                // the highlight is driven by the highlight's own opacity.
                attributed[attrRange].backgroundColor = Theme.primary.opacity(0.65)
                attributed[attrRange].foregroundColor = Theme.textPrimary
            }
            searchStart = range.upperBound
        }
        return Text(attributed)
    }
}

private extension AttributedString {
    func index(_ start: AttributedString.Index, offsetByCharacters n: Int) -> AttributedString.Index? {
        self.characters.index(start, offsetBy: n, limitedBy: self.characters.endIndex)
    }
}

// MARK: - Tool activity chips

/// Inline progress indicator showing each tool the agent invokes during
/// the current turn. Each chip flips from spinner → checkmark/x as the
/// pipeline emits tool_result SSE events.
private struct ToolActivityStack: View {
    let activities: [ChatViewModel.ToolActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(activities) { activity in
                HStack(spacing: Theme.Spacing.sm) {
                    stateIcon(for: activity.state)
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.name)
                            .font(Theme.TextStyle.footnoteSemibold)
                            .foregroundStyle(Theme.textPrimary)
                        if !activity.argsPreview.isEmpty {
                            Text(activity.argsPreview)
                                .font(Theme.TextStyle.caption)
                                .foregroundStyle(Theme.textMuted)
                                .lineLimit(1)
                        }
                        if case let .failed(_, errorPreview) = activity.state,
                           let preview = errorPreview, !preview.isEmpty {
                            Text(preview)
                                .font(Theme.TextStyle.caption)
                                .foregroundStyle(Theme.error)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    stateTrailing(for: activity.state)
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func stateIcon(for state: ChatViewModel.ToolActivity.State) -> some View {
        switch state {
        case .running:
            ProgressView().tint(Theme.primary).controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
        case .failed:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(Theme.error)
        }
    }

    @ViewBuilder
    private func stateTrailing(for state: ChatViewModel.ToolActivity.State) -> some View {
        switch state {
        case .running:
            EmptyView()
        case .completed(let ms), .failed(let ms, _):
            Text("\(ms)ms")
                .font(Theme.TextStyle.captionSemibold)
                .foregroundStyle(Theme.textMuted)
        }
    }
}
