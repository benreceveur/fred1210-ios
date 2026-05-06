import SwiftUI

struct TaskTimelineView: View {
    let task: Components.Schemas.Task

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            timelineRow(
                icon: "plus.circle",
                color: Theme.info,
                title: "Created",
                detail: task.createdAt.formatted(.dateTime)
            )
            if (task.assignee ?? "").lowercased().contains("fred") || (task.assignee ?? "").isEmpty {
                timelineRow(
                    icon: "bolt.horizontal.circle",
                    color: Theme.primary,
                    title: "Fred owned",
                    detail: "This work is assigned to Fred unless another assignee is shown."
                )
            }
            if let tags = task.tags, !tags.isEmpty {
                timelineRow(
                    icon: "tag",
                    color: Theme.textMuted,
                    title: "Context",
                    detail: tags.joined(separator: ", ")
                )
            }
            if task.status == .done {
                timelineRow(
                    icon: "checkmark.seal",
                    color: Theme.success,
                    title: "Done receipt",
                    detail: "Completed \(task.updatedAt.formatted(.relative(presentation: .numeric))). Review description, tags, attachments, and GitHub links for evidence."
                )
            } else if task.status == .review {
                timelineRow(
                    icon: "eye",
                    color: Theme.warning,
                    title: "Waiting for review",
                    detail: "Fred needs a decision before this should be considered complete."
                )
            } else if task.status == .inProgress {
                timelineRow(
                    icon: "timer",
                    color: Theme.info,
                    title: "In progress",
                    detail: "Last updated \(task.updatedAt.formatted(.relative(presentation: .numeric)))."
                )
            } else {
                timelineRow(
                    icon: "circle",
                    color: Theme.textMuted,
                    title: "Queued",
                    detail: "Status is \(task.status.rawValue)."
                )
            }
        }
    }

    private func timelineRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: Theme.Font.sm, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: Theme.Font.xs))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }
}
