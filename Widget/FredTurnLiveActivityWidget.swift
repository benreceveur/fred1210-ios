#if canImport(ActivityKit)
import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.2, *)
struct FredTurnLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FredTurnActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text("Fred is working")
                    .font(.system(size: 14, weight: .bold))
                Text(context.attributes.prompt)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(context.state.phase)
                    Spacer()
                    Text("\(context.state.toolCount) tools · \(context.state.elapsedSec)s")
                }
                .font(.system(size: 12, weight: .semibold))
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Fred")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.toolCount)")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.prompt).lineLimit(1)
                        Text(context.state.phase)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "sparkles")
            } compactTrailing: {
                Text("\(context.state.toolCount)")
            } minimal: {
                Image(systemName: "sparkles")
            }
        }
    }
}
#endif
