//
//  LiveActivityManager.swift
//  countDown
//
//  Created by Claude on 2026/01/17.
//

import ActivityKit
import Foundation

// MARK: - Live Activity Attributes（メインアプリ用定義）
struct CountdownActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var daysRemaining: Int
        var hoursRemaining: Int
        var minutesRemaining: Int
        var isPast: Bool
        var daysPassed: Int
    }

    var eventId: String
    var eventTitle: String
    var eventColor: String
    var targetDate: Date
}

/// Live Activityを管理するマネージャー
@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    // MARK: - Public Methods

    /// Live Activityを開始
    func startActivity(for event: Event) async -> Bool {
        // Live Activityがサポートされているか確認
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("LiveActivity: Live Activityはサポートされていません")
            return false
        }

        // 既存のActivityがあれば終了
        await endActivity(for: event.id)

        let attributes = CountdownActivityAttributes(
            eventId: event.id.uuidString,
            eventTitle: event.title,
            eventColor: event.color,
            targetDate: event.date
        )

        let contentState = createContentState(for: event)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("LiveActivity: 開始成功 - \(activity.id)")
            return true
        } catch {
            print("LiveActivity: 開始失敗 - \(error.localizedDescription)")
            return false
        }
    }

    /// Live Activityを更新
    func updateActivity(for event: Event) async {
        let contentState = createContentState(for: event)

        for activity in Activity<CountdownActivityAttributes>.activities {
            if activity.attributes.eventId == event.id.uuidString {
                await activity.update(
                    ActivityContent(state: contentState, staleDate: nil)
                )
                print("LiveActivity: 更新成功 - \(activity.id)")
            }
        }
    }

    /// Live Activityを終了
    func endActivity(for eventId: UUID) async {
        for activity in Activity<CountdownActivityAttributes>.activities {
            if activity.attributes.eventId == eventId.uuidString {
                await activity.end(nil, dismissalPolicy: .immediate)
                print("LiveActivity: 終了成功 - \(activity.id)")
            }
        }
    }

    /// 全てのLive Activityを終了
    func endAllActivities() async {
        for activity in Activity<CountdownActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        print("LiveActivity: 全て終了")
    }

    /// 指定イベントのLive Activityが実行中かどうか
    func isActivityRunning(for eventId: UUID) -> Bool {
        return Activity<CountdownActivityAttributes>.activities.contains {
            $0.attributes.eventId == eventId.uuidString
        }
    }

    /// 実行中のLive Activity数を取得
    var runningActivitiesCount: Int {
        Activity<CountdownActivityAttributes>.activities.count
    }

    // MARK: - Private Methods

    private func createContentState(for event: Event) -> CountdownActivityAttributes.ContentState {
        let calendar = Calendar.current
        let now = Date()

        let isPast = event.date < now
        let daysRemaining = event.daysRemaining
        let daysPassed = event.daysPassed

        // 時間と分を計算
        let components = calendar.dateComponents([.hour, .minute], from: now, to: event.date)
        let hoursRemaining = max(0, (components.hour ?? 0) % 24)
        let minutesRemaining = max(0, (components.minute ?? 0) % 60)

        return CountdownActivityAttributes.ContentState(
            daysRemaining: max(0, daysRemaining),
            hoursRemaining: hoursRemaining,
            minutesRemaining: minutesRemaining,
            isPast: isPast,
            daysPassed: daysPassed
        )
    }
}

// MARK: - Fallback for older iOS versions
class LiveActivityManagerFallback {
    static let shared = LiveActivityManagerFallback()

    private init() {}

    func startActivity(for event: Event) async -> Bool {
        print("LiveActivity: iOS 16.1未満ではサポートされていません")
        return false
    }

    func updateActivity(for event: Event) async {}
    func endActivity(for eventId: UUID) async {}
    func endAllActivities() async {}
    func isActivityRunning(for eventId: UUID) -> Bool { false }
    var runningActivitiesCount: Int { 0 }
}
