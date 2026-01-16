import WidgetKit
import SwiftUI

// MARK: - Lock Screen Widget (iOS 16+)
@available(iOSApplicationExtension 16.0, *)
struct CountdownLockScreenWidget: Widget {
    let kind: String = "CountdownLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: CountdownTimelineProvider()
        ) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("カウントダウン")
        .description("ロック画面にイベントまでの残り日数を表示")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Lock Screen Widget View
@available(iOSApplicationExtension 16.0, *)
struct LockScreenWidgetView: View {
    var entry: CountdownEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView(event: entry.events.first)
        case .accessoryRectangular:
            RectangularView(event: entry.events.first)
        case .accessoryInline:
            InlineView(event: entry.events.first)
        default:
            CircularView(event: entry.events.first)
        }
    }
}

// MARK: - Circular View
@available(iOSApplicationExtension 16.0, *)
struct CircularView: View {
    let event: WidgetEvent?

    var body: some View {
        if let event = event {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    if event.isPast {
                        Text("\(event.daysPassed)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("日経過")
                            .font(.system(size: 8))
                    } else {
                        Text("\(event.daysRemaining)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("日")
                            .font(.system(size: 10))
                    }
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "calendar")
                    .font(.title2)
            }
        }
    }
}

// MARK: - Rectangular View
@available(iOSApplicationExtension 16.0, *)
struct RectangularView: View {
    let event: WidgetEvent?

    var body: some View {
        if let event = event {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)

                    if event.isPast {
                        Text("\(event.daysPassed)日経過")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if event.isToday {
                        Text("今日")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("あと\(event.daysRemaining)日")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if event.isPast {
                    Text("\(event.daysPassed)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                } else {
                    Text("\(event.daysRemaining)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
            }
        } else {
            HStack {
                Image(systemName: "calendar")
                Text("イベントなし")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Inline View
@available(iOSApplicationExtension 16.0, *)
struct InlineView: View {
    let event: WidgetEvent?

    var body: some View {
        if let event = event {
            if event.isPast {
                Text("\(event.title): \(event.daysPassed)日経過")
            } else if event.isToday {
                Text("\(event.title): 今日")
            } else {
                Text("\(event.title): あと\(event.daysRemaining)日")
            }
        } else {
            Text("イベントなし")
        }
    }
}

// MARK: - Preview
@available(iOSApplicationExtension 16.0, *)
#Preview(as: .accessoryCircular) {
    CountdownLockScreenWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        events: [WidgetEvent(id: UUID(), title: "誕生日", date: Date().addingTimeInterval(86400 * 30), color: "blue")],
        configuration: ConfigurationAppIntent()
    )
}

@available(iOSApplicationExtension 16.0, *)
#Preview(as: .accessoryRectangular) {
    CountdownLockScreenWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        events: [WidgetEvent(id: UUID(), title: "誕生日", date: Date().addingTimeInterval(86400 * 30), color: "blue")],
        configuration: ConfigurationAppIntent()
    )
}
