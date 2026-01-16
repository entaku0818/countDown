import Foundation
import UIKit
import UserNotifications
import ComposableArchitecture
import FirebaseAnalytics

// MARK: - Alarm Service
struct AlarmService {
    var requestAuthorization: @Sendable () async -> Bool
    var scheduleEventNotifications: @Sendable (Event) async -> Bool
    var cancelEventNotifications: @Sendable (UUID) async -> Bool
    var updateEventNotifications: @Sendable (Event) async -> Bool
    var getNotificationStatus: @Sendable () async -> NotificationAuthorizationStatus
    var openNotificationSettings: @Sendable () -> Void
}

// MARK: - Notification Models
enum NotificationAuthorizationStatus: Equatable {
    case authorized
    case denied
    case notDetermined
    case provisional
    case ephemeral
    case unknown
}

// MARK: - Live Implementation
extension AlarmService: DependencyKey {
    static var liveValue: AlarmService {
        return AlarmService(
            requestAuthorization: {
                let center = UNUserNotificationCenter.current()

                do {
                    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
                    let granted = try await center.requestAuthorization(options: options)

                    if granted {
                        print("通知の権限が許可されました")
                    } else {
                        print("通知の権限が拒否されました")
                    }

                    return granted
                } catch {
                    print("通知の権限リクエストでエラー: \(error)")
                    return false
                }
            },

            scheduleEventNotifications: { event in
                let center = UNUserNotificationCenter.current()

                // 有効な通知設定を取得
                let enabledSettings = event.notificationSettings.filter { $0.isEnabled }

                // 有効な通知設定がなければ成功として終了
                if enabledSettings.isEmpty {
                    return true
                }

                var success = true

                // 各通知設定について処理
                for setting in enabledSettings {
                    for timing in setting.allTimings {
                        guard let notificationDate = timing.notificationDate(for: event.date) else {
                            continue
                        }

                        // 過去の日付の場合はスキップ
                        if notificationDate < Date() {
                            continue
                        }

                        // 通知コンテンツを作成
                        let content = UNMutableNotificationContent()
                        content.title = "イベント通知"
                        content.body = "\(event.title)まで\(timing.description)です"
                        content.sound = .default
                        content.userInfo = ["eventId": event.id.uuidString]

                        // トリガーを設定
                        let calendar = Calendar.current
                        let components = calendar.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: notificationDate
                        )
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                        // 通知ID（イベントIDとタイミングで一意）
                        let identifier = "event_\(event.id.uuidString)_\(timing.identifier)"
                        let request = UNNotificationRequest(
                            identifier: identifier,
                            content: content,
                            trigger: trigger
                        )

                        do {
                            try await center.add(request)
                            print("通知をスケジュール: \(event.title) - \(notificationDate)")

                            // Analytics に記録
                            await MainActor.run {
                                Analytics.logEvent("notification_scheduled", parameters: [
                                    "event_title": event.title,
                                    "notification_date": notificationDate.timeIntervalSince1970
                                ])
                            }
                        } catch {
                            print("通知のスケジュールに失敗: \(error)")
                            success = false

                            // エラーを Analytics に記録
                            await MainActor.run {
                                Analytics.logEvent("notification_schedule_error", parameters: [
                                    "error": error.localizedDescription
                                ])
                            }
                        }
                    }
                }

                return success
            },

            cancelEventNotifications: { eventId in
                let center = UNUserNotificationCenter.current()
                let pendingRequests = await center.pendingNotificationRequests()

                // イベントIDを含む通知IDをフィルタリング
                let eventNotificationIds = pendingRequests
                    .filter { $0.identifier.contains("event_\(eventId.uuidString)") }
                    .map { $0.identifier }

                if !eventNotificationIds.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: eventNotificationIds)
                    print("\(eventNotificationIds.count)件の通知をキャンセル（イベントID: \(eventId)）")
                }

                return true
            },

            updateEventNotifications: { event in
                let center = UNUserNotificationCenter.current()
                let pendingRequests = await center.pendingNotificationRequests()

                // 既存の通知をキャンセル
                let eventNotificationIds = pendingRequests
                    .filter { $0.identifier.contains("event_\(event.id.uuidString)") }
                    .map { $0.identifier }

                if !eventNotificationIds.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: eventNotificationIds)
                }

                // 新しい通知をスケジュール
                return await AlarmService.liveValue.scheduleEventNotifications(event)
            },

            getNotificationStatus: {
                let center = UNUserNotificationCenter.current()
                let settings = await center.notificationSettings()

                switch settings.authorizationStatus {
                case .authorized:
                    return .authorized
                case .denied:
                    return .denied
                case .notDetermined:
                    return .notDetermined
                case .provisional:
                    return .provisional
                case .ephemeral:
                    return .ephemeral
                @unknown default:
                    return .unknown
                }
            },

            openNotificationSettings: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Task {
                        await MainActor.run {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Test Implementation
extension AlarmService {
    static var testValue: AlarmService {
        return AlarmService(
            requestAuthorization: { true },
            scheduleEventNotifications: { _ in true },
            cancelEventNotifications: { _ in true },
            updateEventNotifications: { _ in true },
            getNotificationStatus: { .authorized },
            openNotificationSettings: { }
        )
    }
}

// MARK: - Dependency Registration
extension DependencyValues {
    var alarmService: AlarmService {
        get { self[AlarmService.self] }
        set { self[AlarmService.self] = newValue
        }
    }
}
