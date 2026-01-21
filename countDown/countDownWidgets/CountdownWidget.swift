import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry
struct CountdownEntry: TimelineEntry {
    let date: Date
    let events: [WidgetEvent]
    let configuration: ConfigurationAppIntent
}

// MARK: - Configuration Intent
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "カウントダウン設定"
    static var description = IntentDescription("表示するイベントを選択します")

    @Parameter(title: "特定のイベントを表示")
    var selectedEvent: EventEntity?

    @Parameter(title: "表示件数", default: 3)
    var displayCount: Int
}

// MARK: - Timeline Provider
struct CountdownTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = CountdownEntry
    typealias Intent = ConfigurationAppIntent

    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(
            date: Date(),
            events: [
                WidgetEvent(id: UUID(), title: "サンプルイベント", date: Date().addingTimeInterval(86400 * 7), color: "blue")
            ],
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CountdownEntry {
        let events = getEventsForConfiguration(configuration)
        return CountdownEntry(date: Date(), events: events, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let displayEvents = getEventsForConfiguration(configuration)

        let entry = CountdownEntry(date: Date(), events: displayEvents, configuration: configuration)

        // 1時間ごとに更新
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func getEventsForConfiguration(_ configuration: ConfigurationAppIntent) -> [WidgetEvent] {
        // 特定のイベントが選択されている場合はそれだけを表示
        if let selectedEvent = configuration.selectedEvent {
            return [selectedEvent.toWidgetEvent()]
        }

        // それ以外は全イベントから表示件数分を取得
        var events = SharedDataManager.loadEvents()
        events.sort { $0.date < $1.date }
        return Array(events.prefix(configuration.displayCount))
    }
}

// MARK: - Widget View
struct CountdownWidgetEntryView: View {
    var entry: CountdownEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(events: entry.events)
        case .systemMedium:
            MediumWidgetView(events: entry.events)
        case .systemLarge:
            LargeWidgetView(events: entry.events)
        default:
            SmallWidgetView(events: entry.events)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let events: [WidgetEvent]

    var body: some View {
        if let event = events.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(colorFromString(event.color))
                        .frame(width: 8, height: 8)
                    Text(event.title)
                        .font(.caption)
                        .lineLimit(1)
                }

                Spacer()

                if event.isPast {
                    Text("\(event.daysPassed)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("日経過")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(event.daysRemaining)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        } else {
            VStack {
                Image(systemName: "calendar")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("イベントなし")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let events: [WidgetEvent]

    var body: some View {
        if events.isEmpty {
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "calendar")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("イベントを追加してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
        } else {
            HStack(spacing: 12) {
                ForEach(events.prefix(2)) { event in
                    EventCardView(event: event)
                }
            }
            .padding()
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let events: [WidgetEvent]

    var body: some View {
        if events.isEmpty {
            VStack {
                Image(systemName: "calendar")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("イベントを追加してください")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
        } else {
            VStack(spacing: 8) {
                ForEach(events.prefix(4)) { event in
                    EventRowView(event: event)
                }
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Event Card View
struct EventCardView: View {
    let event: WidgetEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(colorFromString(event.color))
                    .frame(width: 8, height: 8)
                Text(event.title)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()

            if event.isPast {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(event.daysPassed)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("日経過")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(event.daysRemaining)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Event Row View
struct EventRowView: View {
    let event: WidgetEvent

    var body: some View {
        HStack {
            Circle()
                .fill(colorFromString(event.color))
                .frame(width: 10, height: 10)

            Text(event.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if event.isPast {
                Text("\(event.daysPassed)日経過")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } else if event.isToday {
                Text("今日")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            } else {
                Text("あと\(event.daysRemaining)日")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(event.isWithinSevenDays ? .orange : .primary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Helper
func colorFromString(_ colorString: String) -> Color {
    switch colorString.lowercased() {
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "pink": return .pink
    default: return .blue
    }
}

// MARK: - Widget Definition
struct CountdownWidget: Widget {
    let kind: String = "CountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: CountdownTimelineProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("カウントダウン")
        .description("イベントまでの残り日数を表示します")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        events: [WidgetEvent(id: UUID(), title: "誕生日", date: Date().addingTimeInterval(86400 * 30), color: "blue")],
        configuration: ConfigurationAppIntent()
    )
}

#Preview(as: .systemMedium) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        events: [
            WidgetEvent(id: UUID(), title: "誕生日", date: Date().addingTimeInterval(86400 * 30), color: "blue"),
            WidgetEvent(id: UUID(), title: "旅行", date: Date().addingTimeInterval(86400 * 7), color: "green")
        ],
        configuration: ConfigurationAppIntent()
    )
}
