import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Components.Schemas.ChatMessage] = []
    @Published private(set) var isLoadingHistory = false
    @Published private(set) var isSending = false
    @Published var displayError: FredDisplayError?
    @Published var draft: String = ""

    private let client: FredClient

    init(client: FredClient) {
        self.client = client
    }

    func loadHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            let response = try await client.fetchHistory()
            messages = response.messages
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(
                error, endpoint: "Chat history",
                retry: { [weak self] in await self?.loadHistory() }
            )
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        draft = ""
        isSending = true
        defer { isSending = false }

        // Optimistic: append the user message immediately so the UI
        // reflects intent without waiting for the server round trip.
        let userMessage = Components.Schemas.ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        do {
            let response = try await client.sendChatMessage(text)
            let assistantMessage = Components.Schemas.ChatMessage(
                role: .assistant,
                content: response.response
            )
            messages.append(assistantMessage)
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(error, endpoint: "Send message", retry: nil)
            // Remove the optimistic user message since the send failed — user
            // can edit and retry.
            if messages.last?.role == .user, messages.last?.content == text {
                messages.removeLast()
            }
            draft = text
        }
    }

    func clearError() {
        displayError = nil
    }
}
