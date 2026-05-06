import SwiftUI
import WidgetKit

struct TasksWidgetView: View {
    let entry: TasksEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if !entry.hasHost {
            notConfigured
        } else if let err = entry.errorMessage {
            errorView(err)
        } else {
            switch family {
            case .systemSmall: smallView
            case .accessoryRectangular: rectangularAccessory
            case .accessoryCircular: circularAccessory
            case .accessoryInline: inlineAccessory
            default: mediumView
            }
        }
    }

    // MARK: -

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(entry.tasks.count)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("open tasks")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
            Spacer(minLength: 6)
            if let next = entry.tasks.first {
                Text("NEXT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Text(next.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "fred1210://tasks"))
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(entry.tasks.count)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("open")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("UPDATED \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Divider().overlay(Color.white.opacity(0.15))
            ForEach(entry.tasks.prefix(3)) { task in
                HStack(spacing: 8) {
                    Circle()
                        .fill(color(for: task.priority))
                        .frame(width: 6, height: 6)
                    Text(task.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                    Text(task.priority.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(color(for: task.priority))
                }
            }
            if entry.tasks.isEmpty {
                Text("Nothing urgent.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .widgetURL(URL(string: "fred1210://tasks"))
    }

    private var notConfigured: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundStyle(.yellow)
            Text("Open Fred1210").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            Text("to configure host")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Can't reach Fred")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func color(for priority: String) -> Color {
        switch priority {
        case "urgent": return Color(red: 239/255, green: 68/255, blue: 68/255)
        case "high": return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "medium": return Color(red: 59/255, green: 130/255, blue: 246/255)
        case "low": return Color(red: 100/255, green: 116/255, blue: 139/255)
        default: return Color(red: 100/255, green: 116/255, blue: 139/255)
        }
    }

    // MARK: - Lock Screen + StandBy accessories (iOS 16+)
    //
    // These render under the clock on the Lock Screen (rectangular) and in
    // the row above it (circular / inline). StandBy picks them up on iOS
    // 17+ automatically.

    private var rectangularAccessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                Text("\(entry.tasks.count) open")
                    .font(.system(size: 13, weight: .semibold))
            }
            if let top = entry.tasks.first {
                Text(top.title)
                    .font(.system(size: 12))
                    .lineLimit(2)
            } else {
                Text("All caught up")
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
        }
        .widgetAccentable()
    }

    private var circularAccessory: some View {
        ZStack {
            Circle().stroke(lineWidth: 2).opacity(0.3)
            VStack(spacing: 0) {
                Text("\(entry.tasks.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("tasks")
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder
    private var inlineAccessory: some View {
        if let top = entry.tasks.first {
            Text("Fred · \(entry.tasks.count) open · \(top.title)")
        } else {
            Text("Fred · all caught up")
        }
    }
}

struct NeedsBobWidgetView: View {
    let entry: TasksEntry

    private var needsBob: [WidgetTask] {
        entry.tasks.filter { $0.status == "review" || $0.priority == "urgent" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(needsBob.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(needsBob.isEmpty ? .green : .orange)
                Text("Needs Bob")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            Divider().overlay(Color.white.opacity(0.15))
            if needsBob.isEmpty {
                Text("No approvals waiting.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(needsBob.prefix(3)) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(task.priority == "urgent" ? .red : .orange)
                            .frame(width: 6, height: 6)
                        Text(task.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "fred1210://tasks"))
    }
}
