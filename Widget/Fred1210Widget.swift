import WidgetKit
import SwiftUI

/// Home-screen widget for Fred1210. Two sizes:
///
///   - **Small**: open-task count + the single next-due item
///   - **Medium**: up to 3 urgent tasks + status breakdown
///
/// Both render the same headline-first hierarchy to stay readable at a
/// glance. Refreshes every ~15 minutes via ``TimelineProvider`` —
/// WidgetKit will honour it best-effort based on battery and usage.
///
/// The widget reads Fred's host URL from the shared Keychain group set
/// up in Phase 1. If the user hasn't launched the main app yet, the
/// widget shows a placeholder prompting them to open it.
@main
struct Fred1210WidgetBundle: WidgetBundle {
    var body: some Widget {
        TasksWidget()
    }
}

struct TasksWidget: Widget {
    let kind = "com.relayforgelabs.fred1210.widget.tasks"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            if #available(iOS 17.0, *) {
                TasksWidgetView(entry: entry)
                    .containerBackground(for: .widget) { Color.black }
            } else {
                TasksWidgetView(entry: entry)
                    .padding()
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Fred Tasks")
        .description("Your open tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
