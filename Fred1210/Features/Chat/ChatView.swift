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
            .task { await viewModel.loadHistory() }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
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
                        ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { idx, message in
                            ChatBubble(message: message)
                                .id(idx)
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
}

// MARK: - ChatBubble

struct ChatBubble: View {
    let message: Components.Schemas.ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(roleLabel)
                    .font(.system(size: Theme.Font.xs, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Text(message.content)
                    .font(.system(size: Theme.Font.md))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .textSelection(.enabled)
            }
            if message.role != .user { Spacer(minLength: 40) }
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "YOU"
        case .assistant: return "FRED"
        case .system: return "SYSTEM"
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: return Theme.primary.opacity(0.25)
        case .assistant: return Theme.bgCard
        case .system: return Theme.warning.opacity(0.15)
        }
    }
}
