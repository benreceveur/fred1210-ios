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
        NeedsBobWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            FredTurnLiveActivityWidget()
        }
    }
}

struct NeedsBobWidget: Widget {
    let kind = "com.relayforgelabs.fred1210.widget.needs-bob"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            if #available(iOS 17.0, *) {
                NeedsBobWidgetView(entry: entry)
                    .containerBackground(for: .widget) { Color.black }
            } else {
                NeedsBobWidgetView(entry: entry)
                    .padding()
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Fred Needs Bob")
        .description("Approvals, urgent tasks, and review work.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
        // iOS 16+ Lock Screen + StandBy — accessoryRectangular lives below
        // the clock; accessoryCircular/accessoryInline fit the complications
        // row on iOS and the tiny slots on watchOS-style StandBy mode.
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryCircular, .accessoryInline,
        ])
    }
}
