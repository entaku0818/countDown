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
        let allEvents = SharedDataManager.loadEvents()
        if let selectedEvent = configuration.selectedEvent {
            // ステップ情報を含む最新データを優先
            return [allEvents.first { $0.id == selectedEvent.id } ?? selectedEvent.toWidgetEvent()]
        }

        // それ以外は今後のイベントを近い順に（終わったものは後ろへ）
        let events = allEvents.filter { !$0.isPast }.sorted { $0.date < $1.date }
            + allEvents.filter(\.isPast).sorted { $0.date > $1.date }
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
                Text(event.title)
                    .font(.caption).bold()
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    DaysRingView(event: event, size: 84)
                    Spacer()
                }

                Spacer(minLength: 0)

                if let next = event.upcomingSteps?.first(where: { !$0.isCompleted }) {
                    Text("次: \(next.title)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            EmptyWidgetView(message: "イベントなし")
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let events: [WidgetEvent]

    var body: some View {
        if let event = events.first {
            if event.hasSteps {
                // ゴールまでの道のり: 左に残り日数、右に次のステップ
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.caption).bold()
                            .lineLimit(1)
                        DaysRingView(event: event, size: 76)
                    }
                    StepListView(event: event, limit: 3)
                }
            } else {
                HStack(spacing: 12) {
                    ForEach(events.prefix(2)) { event in
                        EventCardView(event: event)
                    }
                }
            }
        } else {
            EmptyWidgetView(message: "イベントを追加してください")
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let events: [WidgetEvent]

    var body: some View {
        if let event = events.first {
            VStack(spacing: 10) {
                GoalHeaderView(event: event)
                if event.hasSteps {
                    StepListView(event: event, limit: 4)
                } else {
                    ForEach(events.dropFirst().prefix(3)) { other in
                        EventRowView(event: other)
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            EmptyWidgetView(message: "イベントを追加してください")
        }
    }
}

// MARK: - Parts

/// 残り日数＋ステップ進捗のリング
struct DaysRingView: View {
    let event: WidgetEvent
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(colorFromString(event.color).opacity(0.2), lineWidth: 7)
            Circle()
                .trim(from: 0, to: event.hasSteps ? event.stepRatio : 1)
                .stroke(colorFromString(event.color), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                if event.isToday {
                    Text("今日")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                } else {
                    Text("\(event.isPast ? event.daysPassed : event.daysRemaining)")
                        .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(event.isPast ? "日経過" : "日")
                        .font(.system(size: size * 0.12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
        }
        .frame(width: size, height: size)
    }
}

/// 次のステップ一覧。左の丸をタップすると完了チェックできる
struct StepListView: View {
    let event: WidgetEvent
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("道のり \(event.completedSteps ?? 0)/\(event.totalSteps ?? 0)")
                .font(.caption2).bold()
                .foregroundColor(.secondary)
            let steps = (event.upcomingSteps ?? []).prefix(limit)
            if steps.isEmpty {
                Text("すべてのステップを達成！")
                    .font(.caption)
            }
            ForEach(Array(steps)) { step in
                HStack(spacing: 6) {
                    Button(intent: ToggleStepIntent(stepId: step.id)) {
                        Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(step.isCompleted ? colorFromString(event.color) : .secondary)
                    }
                    .buttonStyle(.plain)
                    Text(step.title)
                        .font(.caption)
                        .strikethrough(step.isCompleted)
                        .foregroundColor(step.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(step.daysRemaining > 0 ? "あと\(step.daysRemaining)日" : (step.daysRemaining == 0 ? "今日" : "期限切れ"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 大サイズ用：写真を背景にしたゴール見出し
struct GoalHeaderView: View {
    let event: WidgetEvent

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if event.hasImage == true, let image = SharedDataManager.loadImage(for: event.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                colorFromString(event.color).opacity(0.8)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if event.isToday {
                    Text("今日！").font(.title).bold()
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(event.isPast ? "" : "あと")
                            .font(.caption)
                        Text("\(event.isPast ? event.daysPassed : event.daysRemaining)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text(event.isPast ? "日経過" : "日")
                            .font(.caption)
                    }
                }
            }
            .foregroundColor(.white)
            .padding(12)
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct EmptyWidgetView: View {
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .description("残り日数とゴールまでの道のりを表示。ステップはウィジェットから完了チェックできます")
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

private let previewGoal = WidgetEvent(
    id: UUID(), title: "結婚式", date: Date().addingTimeInterval(86400 * 120), color: "pink",
    completedSteps: 2, totalSteps: 5,
    upcomingSteps: [
        WidgetStep(id: UUID(), title: "招待状発送", date: Date().addingTimeInterval(86400 * 20), isCompleted: false),
        WidgetStep(id: UUID(), title: "ドレス最終フィッティング", date: Date().addingTimeInterval(86400 * 60), isCompleted: false),
        WidgetStep(id: UUID(), title: "ネイル予約", date: Date().addingTimeInterval(86400 * 110), isCompleted: false)
    ]
)

#Preview("Journey", as: .systemMedium) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: Date(), events: [previewGoal], configuration: ConfigurationAppIntent())
}

#Preview("Journey Large", as: .systemLarge) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: Date(), events: [previewGoal], configuration: ConfigurationAppIntent())
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
