import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

/// Share-extension entry point. Activates from the iOS share sheet when
/// the user shares a URL, plain text, or selected text from any app.
///
/// UX: a single-field sheet that pre-fills a message mentioning the
/// shared URL, which the user can edit before tapping Send. Tap posts
/// to Fred's ``/api/agent/chat`` endpoint so Fred can do whatever it
/// normally does with a URL (research, repo review, summarize, etc.).
///
/// Kept intentionally dependency-light — no OpenAPIRuntime, no
/// KeychainAccess here. iOS share extensions run with a tight memory
/// ceiling (~120MB); pulling in the full networking stack risks OOM.
final class ShareViewController: SLComposeServiceViewController {
    private var sharedText: String = ""

    /// Keychain service + access group must match the main app's
    /// ``FredConfig`` constants so we read the same host URL.
    private let keychainService = "com.relayforgelabs.fred1210"
    private let keychainAccessGroup = "$(AppIdentifierPrefix)com.relayforgelabs.fred1210.shared"
    private let keychainKey = "fred-host"

    override func isContentValid() -> Bool {
        !(contentText?.isEmpty ?? true)
    }

    override func presentationAnimationDidFinish() {
        super.presentationAnimationDidFinish()
        loadSharedContent()
    }

    override func didSelectPost() {
        let message = [contentText ?? "", sharedText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !message.isEmpty, let host = readHostURL() else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        Task {
            await postToFred(host: host, message: message)
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        [] // no extra configuration rows
    }

    // MARK: -

    private func loadSharedContent() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        Task { @MainActor in
                            if let url = data as? URL {
                                self?.sharedText = url.absoluteString
                                self?.placeholder = "Ask Fred about this link…"
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        Task { @MainActor in
                            if let text = data as? String {
                                self?.sharedText = text
                            }
                        }
                    }
                }
            }
        }
    }

    private func readHostURL() -> URL? {
        // Minimal Keychain query — avoids pulling KeychainAccess into
        // the extension binary. The kSecAttrAccessGroup value is
        // Xcode-expanded at build time via the entitlement.
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainKey,
            kSecAttrAccessGroup: keychainAccessGroup,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let text = String(data: data, encoding: .utf8),
              let url = URL(string: text) else {
            // Fallback: read without access group. Older installs may
            // have the token outside the shared group.
            query.removeValue(forKey: kSecAttrAccessGroup)
            result = nil
            let fallback = SecItemCopyMatching(query as CFDictionary, &result)
            if fallback == errSecSuccess, let data = result as? Data,
               let text = String(data: data, encoding: .utf8),
               let url = URL(string: text) {
                return url
            }
            return nil
        }
        return url
    }

    private func postToFred(host: URL, message: String) async {
        var request = URLRequest(url: host.appendingPathComponent("/api/agent/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["message": message],
            options: []
        )
        request.timeoutInterval = 30
        _ = try? await URLSession.shared.data(for: request)
    }
}
