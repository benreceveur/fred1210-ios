import SwiftUI

/// Last 50 HTTP requests the app made. Read-only; refreshes every time
/// the screen appears. Useful for answering "what URL did my phone hit
/// and what did the server say?" without Xcode attached.
struct DiagnosticsView: View {
    @State private var entries: [RequestLog.Entry] = []
    @State private var isLoading = false

    var body: some View {
        List {
            if entries.isEmpty && !isLoading {
                Text("No requests recorded yet. Open a tab to populate.")
                    .foregroundStyle(Theme.textMuted)
            }
            ForEach(entries) { entry in
                DiagnosticsRow(entry: entry)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task { await reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await RequestLog.shared.clear()
                        await reload()
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        entries = await RequestLog.shared.snapshot()
    }
}

private struct DiagnosticsRow: View {
    let entry: RequestLog.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(entry.method)
                    .font(Theme.TextStyle.captionBold)
                    .foregroundStyle(Theme.primary)
                Text(statusText)
                    .font(Theme.TextStyle.captionSemibold)
                    .foregroundStyle(statusColor)
                Spacer()
                Text("\(entry.latencyMs) ms")
                    .font(Theme.TextStyle.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            Text(entry.url)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            if let err = entry.error {
                Text(err)
                    .font(Theme.TextStyle.caption)
                    .foregroundStyle(Theme.error)
                    .lineLimit(2)
            }
            Text(entry.timestamp.relativeAge())
                .font(Theme.TextStyle.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.bgCard)
    }

    private var statusText: String {
        if let s = entry.status { return "\(s)" }
        if entry.error != nil { return "ERR" }
        return "—"
    }

    private var statusColor: Color {
        guard let s = entry.status else { return Theme.error }
        switch s {
        case 200..<300: return Theme.success
        case 300..<400: return Theme.info
        case 400..<500: return Theme.warning
        default: return Theme.error
        }
    }
}
