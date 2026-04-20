import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    /// Tool-call progress chip for the in-flight turn. Rendered between the
    /// optimistic user message and the assistant reply so users see what
    /// Fred is doing instead of staring at a spinner.
    struct ToolActivity: Identifiable, Equatable {
        let id: UUID = UUID()
        let name: String
        var argsPreview: String
        var state: State

        enum State: Equatable {
            case running
            case completed(latencyMs: Int)
            case failed(latencyMs: Int, errorPreview: String?)
        }
    }

    @Published private(set) var messages: [Components.Schemas.ChatMessage] = []
    @Published private(set) var isLoadingHistory = false
    @Published private(set) var isSending = false
    @Published private(set) var activeTools: [ToolActivity] = []
    @Published var displayError: FredDisplayError?
    @Published var draft: String = ""
    @Published var searchQuery: String = ""

    /// Filtered view of ``messages`` based on the current search query.
    /// Case-insensitive substring match on message content.
    var visibleMessages: [Components.Schemas.ChatMessage] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return messages }
        return messages.filter { $0.content.lowercased().contains(query) }
    }

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
        activeTools = []
        defer {
            isSending = false
            activeTools = []
        }

        // Optimistic: append the user message immediately so the UI
        // reflects intent without waiting for the server round trip.
        let userMessage = Components.Schemas.ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        do {
            var finalContent: String?
            for try await event in client.sendChatMessageStreaming(text) {
                switch event {
                case .toolCall(let name, let argsPreview):
                    activeTools.append(ToolActivity(
                        name: name, argsPreview: argsPreview, state: .running
                    ))
                case .toolResult(let name, let ok, let latencyMs, let errorPreview):
                    // Mark the most-recent running invocation of this tool as
                    // done. We walk backwards because the pipeline can queue
                    // the same tool twice in one turn.
                    if let idx = activeTools.lastIndex(where: {
                        $0.name == name && $0.state == .running
                    }) {
                        activeTools[idx].state = ok
                            ? .completed(latencyMs: latencyMs)
                            : .failed(latencyMs: latencyMs, errorPreview: errorPreview)
                    }
                case .done(let content, _, _):
                    finalContent = content
                case .error(let message):
                    throw FredError.server(status: 500, message: message)
                }
            }
            let assistant = Components.Schemas.ChatMessage(
                role: .assistant,
                content: finalContent ?? ""
            )
            messages.append(assistant)
            displayError = nil
        } catch {
            displayError = FredDisplayError.from(
                error, endpoint: "Send message",
                retry: { [weak self] in
                    // Re-fetch history in case the server actually
                    // completed the send and we just lost the reply to
                    // a timeout. Cheaper and safer than re-sending.
                    await self?.loadHistory()
                }
            )
            // Keep the optimistic user message visible so the user can
            // see what they tried to send. The retry button pulls history
            // in case the server did finish processing.
            draft = ""
            // Opportunistic history refresh: if the send timed out on
            // the client but the server kept working, the assistant
            // reply may land in history shortly after.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await self?.loadHistory()
            }
        }
    }

    func clearError() {
        displayError = nil
    }
}
