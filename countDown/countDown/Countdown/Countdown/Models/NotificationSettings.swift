import Foundation
import ComposableArchitecture

/// イベント通知の設定を管理するモデル
struct NotificationSettings: Equatable, Identifiable, Codable {
    /// 設定の一意識別子
    var id: UUID
    
    /// 通知が有効かどうか
    var isEnabled: Bool
    
    /// 通知タイミングの種類
    var timing: NotificationTiming
    
    /// 複数通知が設定されている場合の通知タイミングのリスト
    var customTimings: [NotificationTiming]
    
    /// イベントID（関連するイベントを識別するため）
    var eventId: UUID
    
    /// デフォルトコンストラクタ
    init(
        id: UUID = UUID(), 
        isEnabled: Bool = true, 
        timing: NotificationTiming = .dayBefore, 
        customTimings: [NotificationTiming] = [], 
        eventId: UUID
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.timing = timing
        self.customTimings = customTimings
        self.eventId = eventId
    }
    
    /// 通知が設定されているかどうかを確認
    var hasNotification: Bool {
        return isEnabled && (timing != .none || !customTimings.isEmpty)
    }
    
    /// 通知のタイミングをテキストで表示
    var timingText: String {
        return timing.description
    }
    
    /// すべての通知タイミング（メインの通知とカスタム通知）を取得
    var allTimings: [NotificationTiming] {
        var result = [timing]
        if case .custom = timing {
            result.append(contentsOf: customTimings)
        }
        return result.filter { $0 != .none }
    }
}

/// 通知のタイミングを表す列挙型
enum NotificationTiming: Equatable, Codable, CaseIterable {
    /// 通知なし
    case none
    
    /// イベント当日
    case sameDay
    
    /// イベント前日
    case dayBefore
    
    /// イベント1週間前
    case weekBefore
    
    /// イベント1ヶ月前
    case monthBefore
    
    /// カスタム時間（指定した日数前）
    case custom(days: Int)
    
    /// すべての基本的なケース（カスタムを除く）
    static var allCases: [NotificationTiming] {
        return [.none, .sameDay, .dayBefore, .weekBefore, .monthBefore]
    }
    
    /// 通知タイミングの人間が読める説明
    var description: String {
        switch self {
        case .none:
            return "通知なし"
        case .sameDay:
            return "当日"
        case .dayBefore:
            return "1日前"
        case .weekBefore:
            return "1週間前"
        case .monthBefore:
            return "1ヶ月前"
        case .custom(let days):
            return "\(days)日前"
        }
    }
    
    /// 指定された日付から通知するタイミングの日付を計算
    func notificationDate(for eventDate: Date) -> Date? {
        guard self != .none else { return nil }
        
        let calendar = Calendar.current
        
        switch self {
        case .sameDay:
            // 当日の朝9時に設定
            var components = calendar.dateComponents([.year, .month, .day], from: eventDate)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components)
            
        case .dayBefore:
            // 前日の朝9時に設定
            guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: eventDate) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: dayBefore)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components)
            
        case .weekBefore:
            // 1週間前の朝9時に設定
            guard let weekBefore = calendar.date(byAdding: .day, value: -7, to: eventDate) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: weekBefore)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components)
            
        case .monthBefore:
            // 1ヶ月前の朝9時に設定
            guard let monthBefore = calendar.date(byAdding: .month, value: -1, to: eventDate) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: monthBefore)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components)
            
        case .custom(let days):
            // 指定日数前の朝9時に設定
            guard let customDate = calendar.date(byAdding: .day, value: -days, to: eventDate) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: customDate)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components)
            
        case .none:
            // この行は実行されることはない（guardステートメントですでに処理されているため）
            return nil
        }
    }
}

/// Codable準拠のための拡張
extension NotificationTiming {
    private enum CodingKeys: String, CodingKey {
        case type, days
    }
    
    private enum TimingType: String, Codable {
        case none, sameDay, dayBefore, weekBefore, monthBefore, custom
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TimingType.self, forKey: .type)
        
        switch type {
        case .none:
            self = .none
        case .sameDay:
            self = .sameDay
        case .dayBefore:
            self = .dayBefore
        case .weekBefore:
            self = .weekBefore
        case .monthBefore:
            self = .monthBefore
        case .custom:
            let days = try container.decode(Int.self, forKey: .days)
            self = .custom(days: days)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .none:
            try container.encode(TimingType.none, forKey: .type)
        case .sameDay:
            try container.encode(TimingType.sameDay, forKey: .type)
        case .dayBefore:
            try container.encode(TimingType.dayBefore, forKey: .type)
        case .weekBefore:
            try container.encode(TimingType.weekBefore, forKey: .type)
        case .monthBefore:
            try container.encode(TimingType.monthBefore, forKey: .type)
        case .custom(let days):
            try container.encode(TimingType.custom, forKey: .type)
            try container.encode(days, forKey: .days)
        }
    }
} 
