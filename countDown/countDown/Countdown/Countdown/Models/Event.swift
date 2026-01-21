import Foundation

struct Event: Equatable, Identifiable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var color: String
    var note: String
    var displayFormat: DisplayFormat
    var imageName: String?  // テンプレート画像名
    var customImageData: Data?  // カスタム画像データ

    // 通知設定を追加
    var notificationSettings: [NotificationSettings]

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        color: String = "blue",
        note: String = "",
        displayFormat: DisplayFormat = DisplayFormat(),
        imageName: String? = nil,
        customImageData: Data? = nil,
        notificationSettings: [NotificationSettings] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.color = color
        self.note = note
        self.displayFormat = displayFormat
        self.imageName = imageName
        self.customImageData = customImageData

        // 通知設定が空の場合は、デフォルトの通知設定を作成
        if notificationSettings.isEmpty {
            self.notificationSettings = [NotificationSettings(eventId: id)]
        } else {
            self.notificationSettings = notificationSettings
        }
    }

    /// 画像があるかどうか
    var hasImage: Bool {
        imageName != nil || customImageData != nil
    }

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

    /// 詳細表示用の日数（実際の時間差から計算）
    var daysRemainingDetailed: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return components.day ?? 0
    }

    var hoursRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: Date(), to: date)
        return (components.hour ?? 0) % 24
    }

    var minutesRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: Date(), to: date)
        return (components.minute ?? 0) % 60
    }

    var secondsRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second], from: Date(), to: date)
        return (components.second ?? 0) % 60
    }
    
    var isWithinSevenDays: Bool {
        return 0 <= daysRemaining && daysRemaining < 7
    }

    var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }

    var isPast: Bool {
        return Date() > date
    }
    
    // 主要な通知設定（最初の設定）を取得
    var primaryNotificationSetting: NotificationSettings? {
        return notificationSettings.first
    }
    
    // 通知が有効かどうかを確認
    var hasEnabledNotifications: Bool {
        return notificationSettings.contains { $0.isEnabled }
    }
    
    // 通知タイミングのテキスト表現（複数ある場合はカンマ区切り）
    var notificationTimingText: String {
        guard hasEnabledNotifications else { return "通知なし" }
        
        let enabledSettings = notificationSettings.filter { $0.isEnabled }
        let timingTexts = enabledSettings.flatMap { setting in
            setting.allTimings.map { $0.description }
        }
        
        return timingTexts.isEmpty ? "通知なし" : timingTexts.joined(separator: ", ")
    }
    
    // すべての通知日時を計算
    func allNotificationDates() -> [Date] {
        let enabledSettings = notificationSettings.filter { $0.isEnabled }
        var dates: [Date] = []
        
        for setting in enabledSettings {
            for timing in setting.allTimings {
                if let notificationDate = timing.notificationDate(for: date) {
                    dates.append(notificationDate)
                }
            }
        }
        
        return dates.sorted()
    }
    
    // デコーダのための初期化処理（旧バージョンとの互換性のため）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        color = try container.decode(String.self, forKey: .color)
        note = try container.decode(String.self, forKey: .note)

        // displayFormatが存在しない古いデータの場合はデフォルト値を使用
        displayFormat = try container.decodeIfPresent(DisplayFormat.self, forKey: .displayFormat) ?? DisplayFormat()

        // imageNameが存在しない古いデータの場合はnil
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)

        // customImageDataが存在しない古いデータの場合はnil
        customImageData = try container.decodeIfPresent(Data.self, forKey: .customImageData)

        // notificationSettingsが存在しない古いデータの場合は空の配列を使用し、後でデフォルト設定を追加
        let decodedSettings = try container.decodeIfPresent([NotificationSettings].self, forKey: .notificationSettings) ?? []

        if decodedSettings.isEmpty {
            notificationSettings = [NotificationSettings(eventId: id)]
        } else {
            notificationSettings = decodedSettings
        }
    }
}

struct DisplayFormat: Equatable, Codable {
    var timeDisplayMode: TimeDisplayMode = .daysOnly
    var style: CountdownStyle = .days

    enum TimeDisplayMode: String, CaseIterable, Codable {
        case daysOnly = "日数のみ"
        case daysAndHours = "日+時間"
        case daysHoursMinutes = "日+時+分"
        case full = "全部表示"
    }

    enum CountdownStyle: String, CaseIterable, Codable {
        case days = "日数"
        case progress = "進捗バー"
        case circle = "サークル"
    }

    // 後方互換性のためのデコード
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeDisplayMode = try container.decodeIfPresent(TimeDisplayMode.self, forKey: .timeDisplayMode) ?? .daysOnly
        style = try container.decodeIfPresent(CountdownStyle.self, forKey: .style) ?? .days
    }

    init(timeDisplayMode: TimeDisplayMode = .daysOnly, style: CountdownStyle = .days) {
        self.timeDisplayMode = timeDisplayMode
        self.style = style
    }
}
