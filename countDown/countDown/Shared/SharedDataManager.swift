import Foundation
import WidgetKit
import UIKit

/// App Groups を使用してメインアプリとウィジェット間でデータを共有するマネージャー
struct SharedDataManager {
    static let appGroupIdentifier = "group.com.entaku.countDown"
    static let eventsKey = "SharedEvents"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static let pendingStepTogglesKey = "PendingStepToggles"

    /// イベントを保存（メインアプリから呼び出し）
    static func saveEventsForWidget(_ events: [Event]) {
        guard let defaults = sharedDefaults else {
            print("App Groups の UserDefaults が取得できません")
            return
        }

        // ウィジェットにはトップレベルのゴールのみ。ステップの進捗と次のステップを添える
        let goals = events.filter(\.isGoal)
        let widgetEvents = goals.map { event in
            let steps = events.children(of: event.id)
            let upcoming = steps.filter { !$0.isCompleted }.prefix(4).map {
                WidgetStep(id: $0.id, title: $0.title, date: $0.displayDate, isCompleted: false)
            }
            return WidgetEvent(
                id: event.id,
                title: event.title,
                date: event.displayDate,
                color: event.color,
                completedSteps: steps.isEmpty ? nil : steps.filter(\.isCompleted).count,
                totalSteps: steps.isEmpty ? nil : steps.count,
                upcomingSteps: steps.isEmpty ? nil : Array(upcoming),
                hasImage: saveWidgetImage(for: event)
            )
        }
        removeStaleImages(keeping: Set(goals.map(\.id)))

        if let encoded = try? JSONEncoder().encode(widgetEvents) {
            defaults.set(encoded, forKey: eventsKey)
            print("ウィジェット用にイベントを保存: \(widgetEvents.count)件")

            // ウィジェットを更新
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// ウィジェットで完了チェックされたステップIDを取り出してクリアする
    static func consumePendingStepToggles() -> [UUID] {
        guard let defaults = sharedDefaults,
              let ids = defaults.stringArray(forKey: pendingStepTogglesKey) else { return [] }
        defaults.removeObject(forKey: pendingStepTogglesKey)
        return ids.compactMap(UUID.init(uuidString:))
    }

    // MARK: - ウィジェット用画像

    static var imagesDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("WidgetImages", isDirectory: true)
    }

    static func imageURL(for id: UUID) -> URL? {
        imagesDirectory?.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// ゴールの画像を縮小してApp Groupに書き出す。画像がなければ削除して false
    private static func saveWidgetImage(for event: Event) -> Bool {
        guard let url = imageURL(for: event.id), let dir = imagesDirectory else { return false }
        let source: UIImage?
        if let data = event.customImageData {
            source = UIImage(data: data)
        } else if let name = event.imageName {
            source = UIImage(named: "event_\(name)")
        } else {
            source = nil
        }
        guard let image = source else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        let maxSide: CGFloat = 600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return false }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (try? jpeg.write(to: url, options: .atomic)) != nil
    }

    private static func removeStaleImages(keeping ids: Set<UUID>) {
        guard let dir = imagesDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent)
            if id.map({ !ids.contains($0) }) ?? true {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// イベントを読み込み（ウィジェットから呼び出し）
    static func loadEventsForWidget() -> [WidgetEvent] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: eventsKey),
              let events = try? JSONDecoder().decode([WidgetEvent].self, from: data) else {
            return []
        }
        return events
    }
}

/// ウィジェット用のステップ
struct WidgetStep: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var isCompleted: Bool
}

/// ウィジェット用のイベントモデル（軽量版）
struct WidgetEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var color: String
    // v0.4〜 ステップ情報（古いデータでは nil）
    var completedSteps: Int?
    var totalSteps: Int?
    var upcomingSteps: [WidgetStep]?
    var hasImage: Bool?

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
