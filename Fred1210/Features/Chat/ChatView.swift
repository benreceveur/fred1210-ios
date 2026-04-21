import SwiftUI

struct ChatView: View {
    @EnvironmentObject var clientHolder: ClientHolder

    var body: some View {
        ChatContentView(client: clientHolder.client)
    }
}

private struct ChatContentView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var inputFocused: Bool

    init(client: FredClient) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesList
                Divider().background(Theme.border)
                inputBar
            }
            .background(Theme.bgDark)
            .navigationTitle("Fred")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                            .font(.system(size: Theme.Font.md))
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xxl)
                    } else {
                        let groups = groupedByRole(viewModel.visibleMessages)
                        if groups.isEmpty && !viewModel.searchQuery.isEmpty {
                            Text("No messages match '\(viewModel.searchQuery)'.")
                                .font(.system(size: Theme.Font.sm))
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
                    }
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xs)
            }
            .onChange(of: viewModel.messages.count) { count in
                guard count > 0 else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(count - 1, anchor: .bottom)
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
                Task { await viewModel.send() }
            } label: {
                if viewModel.isSending {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 44, height: 44)
            .background(isSendDisabled ? Theme.primary.opacity(0.4) : Theme.primary)
            .clipShape(Circle())
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
                    .font(.system(size: Theme.Font.xs, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    HighlightedText(message.content, query: query)
                        .font(.system(size: Theme.Font.md))
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
                attributed[attrRange].backgroundColor = Theme.primary.opacity(0.4)
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
                            .font(.system(size: Theme.Font.sm, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if !activity.argsPreview.isEmpty {
                            Text(activity.argsPreview)
                                .font(.system(size: Theme.Font.xs))
                                .foregroundStyle(Theme.textMuted)
                                .lineLimit(1)
                        }
                        if case let .failed(_, errorPreview) = activity.state,
                           let preview = errorPreview, !preview.isEmpty {
                            Text(preview)
                                .font(.system(size: Theme.Font.xs))
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
                .font(.system(size: Theme.Font.xs, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
    }
}
