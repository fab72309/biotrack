#if canImport(ActivityKit)
import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct ProtocolLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProtocolTimerAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.protocolName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(.teal)
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(UIColor.secondarySystemBackground))
            .activitySystemActionForegroundColor(.teal)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "target")
                        .foregroundStyle(.teal)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.protocolName)
                        .lineLimit(1)
                        .font(.subheadline.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .font(.subheadline.weight(.bold))
                }
            } compactLeading: {
                Image(systemName: "target")
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
            .widgetURL(URL(string: "biotrack://protocols"))
            .keylineTint(.teal)
        }
    }
}
#endif
