import Foundation
import AppIntents

/// App Groups を使用してメインアプリとウィジェット間でデータを共有するマネージャー
struct SharedDataManager {
    static let appGroupIdentifier = "group.com.entaku.countDown"
    static let eventsKey = "SharedEvents"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// イベントを保存
    static func saveEvents(_ events: [WidgetEvent]) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(events) {
            defaults.set(encoded, forKey: eventsKey)
        }
    }

    /// イベントを読み込み
    static func loadEvents() -> [WidgetEvent] {
        guard let defaults = sharedDefaults else {
            print("Widget: App Groups UserDefaults が取得できません")
            return []
        }

        guard let data = defaults.data(forKey: eventsKey) else {
            print("Widget: データが見つかりません (key: \(eventsKey))")
            return []
        }

        guard let events = try? JSONDecoder().decode([WidgetEvent].self, from: data) else {
            print("Widget: デコードに失敗しました")
            return []
        }

        print("Widget: \(events.count)件のイベントを読み込みました")
        return events
    }
}

/// ウィジェット用のイベントモデル（軽量版）
struct WidgetEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var color: String

    /// 残り日数
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date))
        return components.day ?? 0
    }

    /// 経過日数（カウントアップ用）
    var daysPassed: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date()))
        return components.day ?? 0
    }

    /// 残り時間
    var hoursRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: Date(), to: date)
        return max(0, components.hour ?? 0) % 24
    }

    /// 残り分
    var minutesRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: Date(), to: date)
        return max(0, components.minute ?? 0) % 60
    }

    /// イベントが過去かどうか
    var isPast: Bool {
        return date < Date()
    }

    /// 今日かどうか
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// 7日以内かどうか
    var isWithinSevenDays: Bool {
        return daysRemaining >= 0 && daysRemaining < 7
    }
}

// MARK: - AppIntents Entity
/// AppIntentsで使用するイベントエンティティ
struct EventEntity: AppEntity {
    var id: UUID
    var title: String
    var date: Date
    var color: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "イベント"

    var displayRepresentation: DisplayRepresentation {
        let daysRemaining = self.daysRemaining
        let subtitle: String
        if daysRemaining < 0 {
            subtitle = "\(-daysRemaining)日経過"
        } else if daysRemaining == 0 {
            subtitle = "今日"
        } else {
            subtitle = "あと\(daysRemaining)日"
        }
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date))
        return components.day ?? 0
    }

    static var defaultQuery = EventEntityQuery()

    init(id: UUID, title: String, date: Date, color: String) {
        self.id = id
        self.title = title
        self.date = date
        self.color = color
    }

    init(from event: WidgetEvent) {
        self.id = event.id
        self.title = event.title
        self.date = event.date
        self.color = event.color
    }

    func toWidgetEvent() -> WidgetEvent {
        WidgetEvent(id: id, title: title, date: date, color: color)
    }
}

/// イベント検索クエリ
struct EventEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [EventEntity] {
        let allEvents = SharedDataManager.loadEvents()
        return allEvents
            .filter { identifiers.contains($0.id) }
            .map { EventEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [EventEntity] {
        let allEvents = SharedDataManager.loadEvents()
        return allEvents
            .sorted { $0.date < $1.date }
            .map { EventEntity(from: $0) }
    }

    func defaultResult() async -> EventEntity? {
        let allEvents = SharedDataManager.loadEvents()
        // 最も近い未来のイベントをデフォルトに
        return allEvents
            .filter { $0.date >= Date() }
            .sorted { $0.date < $1.date }
            .first
            .map { EventEntity(from: $0) }
    }
}
