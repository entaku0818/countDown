import Foundation

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
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: eventsKey),
              let events = try? JSONDecoder().decode([WidgetEvent].self, from: data) else {
            return []
        }
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
