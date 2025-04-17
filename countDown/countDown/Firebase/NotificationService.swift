import Foundation
import UIKit
import FirebaseMessaging
import FirebaseAnalytics
import ComposableArchitecture
import UserNotifications

// MARK: - Notification Service
struct NotificationService {
    var registerForRemoteNotifications: @Sendable () async -> Void
    var setupMessaging: @Sendable () async -> Void
    var saveDeviceToken: @Sendable (Data, String) async -> Void
    var updateFCMToken: @Sendable (String, String) async -> Void
    var scheduleLocalNotification: @Sendable (String, String, Date, String) async -> Void
    var getNotificationStatus: @Sendable () async -> NotificationAuthorizationStatus
    var openNotificationSettings: @Sendable () -> Void
    var getTokenStatus: @Sendable (String) -> TokenStatus
    
    // 通知設定関連の新機能
    var scheduleEventNotifications: @Sendable (Event, String) async -> Bool
    var cancelEventNotifications: @Sendable (UUID, String) async -> Bool
    var updateEventNotifications: @Sendable (Event, String) async -> Bool
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

struct TokenStatus: Equatable {
    var fcmToken: String?
    var isRegistered: Bool {
        return fcmToken != nil
    }
}

class NotificationServiceLive: NSObject, MessagingDelegate {
    let eventStorage: EventStorageClient
    @Dependency(\.authClient) var authClient
    private var saveFCMTokenTask: Task<Void, Error>?
    
    init(eventStorage: EventStorageClient) {
        self.eventStorage = eventStorage
        super.init()
    }
    
    func registerForNotifications() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await center.requestAuthorization(options: options)
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("プッシュ通知の権限が許可されました")
            } else {
                print("プッシュ通知の権限が拒否されました")
            }
        } catch {
            print("Error requesting notification authorization: \(error)")
        }
    }
    
    func setupMessaging() async {
        await MainActor.run {
            Messaging.messaging().delegate = self
        }
        print("Firebase Messagingのセットアップが完了しました")
        
        // FCMトークンの取得と保存を試みる
        if let fcmToken = Messaging.messaging().fcmToken {
            let userId = authClient.getCurrentUserId()
            if !userId.isEmpty {
                await updateFCMToken(fcmToken, userId)
            } else {
                print("ユーザーIDが取得できないため、FCMトークンを保存できません")
            }
        } else {
            print("FCMトークンがありません。アプリ起動後しばらくしてから再試行してください。")
        }
    }
    
    func saveDeviceToken(_ tokenData: Data, _ userId: String) async {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(tokenString) for userId: \(userId)")
        
        guard !userId.isEmpty else {
            print("ユーザーIDが空のため、デバイストークンを保存できません")
            return
        }
        
        // ユーザーごとのデバイストークンをUserDefaultsに保存
        let key = "APNSToken_\(userId)"
        UserDefaults.standard.set(tokenString, forKey: key)
        
        // 通知が成功したことをAnalyticsに記録
        Task {
            await MainActor.run {
                Analytics.logEvent("apns_token_received", parameters: [
                    "success": true,
                    "userId": userId,
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        }
    }
    
    func updateFCMToken(_ fcmToken: String, _ userId: String) async {
        print("FCM Token: \(fcmToken) for userId: \(userId)")
        
        guard !userId.isEmpty else {
            print("ユーザーIDが空のため、FCMトークンを保存できません")
            return
        }
        
        // ユーザーごとのFCMトークンをUserDefaultsに保存
        let key = "FCMToken_\(userId)"
        UserDefaults.standard.set(fcmToken, forKey: key)
        
        // FCMトークンをFirestoreに保存（デバイスIDではなくユーザーIDを使用）
        do {
            try await eventStorage.saveUserToken(userId, fcmToken)
            print("FCM Token saved to Firestore for userId: \(userId)")
            
            // 成功したことをAnalyticsに記録
            Task {
                await MainActor.run {
                    Analytics.logEvent("fcm_token_saved", parameters: [
                        "success": true,
                        "userId": userId,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            }
        } catch {
            print("Error saving FCM token to Firestore: \(error)")
            
            // エラーをAnalyticsに記録
            Task {
                await MainActor.run {
                    Analytics.logEvent("fcm_token_error", parameters: [
                        "error": error.localizedDescription,
                        "userId": userId,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            }
            
            // リトライロジック
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒待機
                await retryUpdateFCMToken(fcmToken, userId, retryCount: 1)
            }
        }
    }
    
    // リトライロジック（最大3回）
    private func retryUpdateFCMToken(_ fcmToken: String, _ userId: String, retryCount: Int) async {
        guard retryCount <= 3 else {
            print("FCMトークンの保存に3回失敗しました。次回アプリ起動時に再試行します。")
            return
        }
        
        print("FCMトークンの保存をリトライします。試行回数: \(retryCount) userId: \(userId)")
        
        do {
            try await eventStorage.saveUserToken(userId, fcmToken)
            print("FCM Token successfully saved to Firestore on retry #\(retryCount)")
        } catch {
            print("Error saving FCM token to Firestore on retry #\(retryCount): \(error)")
            
            // さらにリトライ
            Task {
                try? await Task.sleep(nanoseconds: UInt64(retryCount * 5_000_000_000)) // 待機時間を増やす
                await retryUpdateFCMToken(fcmToken, userId, retryCount: retryCount + 1)
            }
        }
    }
    
    func scheduleLocalNotification(title: String, body: String, triggerDate: Date, userId: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        // ユーザーIDを通知のユーザー情報に追加
        content.userInfo = ["userId": userId]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // 通知IDにユーザーIDを含める
        let identifier = "notification_\(userId)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Local notification scheduled for \(triggerDate) userId: \(userId)")
            
            // 通知のスケジュールをAnalyticsに記録
            Task {
                await MainActor.run {
                    Analytics.logEvent("notification_scheduled", parameters: [
                        "title": title,
                        "date": triggerDate.timeIntervalSince1970,
                        "userId": userId
                    ])
                }
            }
        } catch {
            print("Error scheduling notification: \(error)")
            
            // エラーをAnalyticsに記録
            Task {
                await MainActor.run {
                    Analytics.logEvent("notification_schedule_error", parameters: [
                        "error": error.localizedDescription,
                        "userId": userId,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            }
        }
    }
    
    // 通知許可ステータスの取得
    func checkNotificationStatus() async -> NotificationAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        
        do {
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
        } catch {
            print("通知設定の取得に失敗しました: \(error)")
            return .unknown
        }
    }
    
    // 設定アプリの通知設定画面を開く
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Task {
                await MainActor.run {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
    }
    
    // ユーザーごとのトークンステータスの取得
    func getTokens(userId: String) -> TokenStatus {
        let fcmTokenKey = "FCMToken_\(userId)"
        let fcmToken = Messaging.messaging().fcmToken ?? UserDefaults.standard.string(forKey: fcmTokenKey)
        
        return TokenStatus(
            fcmToken: fcmToken
        )
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { 
            print("FCMトークンがnilです")
            return
        }
        
        print("FCMトークンを受信しました: \(token)")
        
        // 前回のタスクをキャンセル
        saveFCMTokenTask?.cancel()
        
        // 新しいタスクを作成
        saveFCMTokenTask = Task {
            let userId = authClient.getCurrentUserId()
            if !userId.isEmpty {
                await updateFCMToken(token, userId)
            } else {
                print("ユーザーIDが取得できないため、FCMトークンを保存できません")
            }
        }
    }
    
    // イベントの通知をスケジュールする
    func scheduleEventNotifications(event: Event, userId: String) async -> Bool {
        guard !userId.isEmpty else {
            print("ユーザーIDが空のため、通知をスケジュールできません")
            return false
        }
        
        // まず既存の通知をキャンセル
        await cancelEventNotifications(eventId: event.id, userId: userId)
        
        var success = true
        let enabledSettings = event.notificationSettings.filter { $0.isEnabled }
        
        // 有効な通知設定がなければ終了
        if enabledSettings.isEmpty {
            return true
        }
        
        // 各通知設定について処理
        for setting in enabledSettings {
            for timing in setting.allTimings {
                if let notificationDate = timing.notificationDate(for: event.date) {
                    // 過去の日付の場合はスキップ
                    if notificationDate < Date() {
                        continue
                    }
                    
                    // 通知タイトルと本文を設定
                    let title = "イベント通知"
                    let body = "\(event.title)まで\(timing.description)です"
                    
                    do {
                        // 通知をスケジュール
                        await scheduleLocalNotification(title: title, body: body, triggerDate: notificationDate, userId: userId)
                    } catch {
                        print("通知のスケジュールに失敗しました: \(error)")
                        success = false
                    }
                }
            }
        }
        
        return success
    }
    
    // イベントの通知をキャンセル
    func cancelEventNotifications(eventId: UUID, userId: String) async -> Bool {
        guard !userId.isEmpty else {
            print("ユーザーIDが空のため、通知をキャンセルできません")
            return false
        }
        
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        // イベントIDを含む通知IDをフィルタリング
        let eventNotificationIds = pendingRequests
            .filter { $0.identifier.contains("notification_\(userId)") && $0.identifier.contains(eventId.uuidString) }
            .map { $0.identifier }
        
        if !eventNotificationIds.isEmpty {
            await center.removePendingNotificationRequests(withIdentifiers: eventNotificationIds)
            print("\(eventNotificationIds.count)件の通知をキャンセルしました（イベントID: \(eventId)）")
        }
        
        return true
    }
    
    // イベントの通知を更新（既存の通知をキャンセルして再スケジュール）
    func updateEventNotifications(event: Event, userId: String) async -> Bool {
        guard !userId.isEmpty else {
            print("ユーザーIDが空のため、通知を更新できません")
            return false
        }
        
        // 既存の通知をキャンセル
        let cancelSuccess = await cancelEventNotifications(eventId: event.id, userId: userId)
        if !cancelSuccess {
            return false
        }
        
        // 新しい通知をスケジュール
        return await scheduleEventNotifications(event: event, userId: userId)
    }
}

extension NotificationService: DependencyKey {
    static var liveValue: NotificationService {
        let eventStorage = EventStorageClient.liveValue
        let service = NotificationServiceLive(eventStorage: eventStorage)
        
        return NotificationService(
            registerForRemoteNotifications: {
                await service.registerForNotifications()
            },
            setupMessaging: {
                await service.setupMessaging()
            },
            saveDeviceToken: { tokenData, userId in
                await service.saveDeviceToken(tokenData, userId)
            },
            updateFCMToken: { token, userId in
                await service.updateFCMToken(token, userId)
            },
            scheduleLocalNotification: { title, body, date, userId in
                await service.scheduleLocalNotification(title: title, body: body, triggerDate: date, userId: userId)
            },
            getNotificationStatus: {
                await service.checkNotificationStatus()
            },
            openNotificationSettings: {
                service.openSettings()
            },
            getTokenStatus: { userId in
                service.getTokens(userId: userId)
            },
            // 新しい機能を追加
            scheduleEventNotifications: { event, userId in
                await service.scheduleEventNotifications(event: event, userId: userId)
            },
            cancelEventNotifications: { eventId, userId in
                await service.cancelEventNotifications(eventId: eventId, userId: userId)
            },
            updateEventNotifications: { event, userId in
                await service.updateEventNotifications(event: event, userId: userId)
            }
        )
    }
}

extension DependencyValues {
    var notificationService: NotificationService {
        get { self[NotificationService.self] }
        set { self[NotificationService.self] = newValue }
    }
} 
