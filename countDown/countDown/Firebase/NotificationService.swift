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
    var saveDeviceToken: @Sendable (Data) async -> Void
    var updateFCMToken: @Sendable (String) async -> Void
    var scheduleLocalNotification: @Sendable (String, String, Date) async -> Void
    var getNotificationStatus: @Sendable () async -> NotificationAuthorizationStatus
    var openNotificationSettings: @Sendable () -> Void
    var getTokenStatus: @Sendable () -> TokenStatus
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
    var apnsToken: String?
    var fcmToken: String?
    var isRegistered: Bool {
        return apnsToken != nil && fcmToken != nil
    }
}

class NotificationServiceLive: NSObject, MessagingDelegate {
    let eventStorage: EventStorageClient
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
            await updateFCMToken(fcmToken)
        } else {
            print("FCMトークンがありません。アプリ起動後しばらくしてから再試行してください。")
        }
    }
    
    func saveDeviceToken(_ tokenData: Data) async {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(tokenString)")
        
        // デバイストークンをローカルに保存
        UserDefaults.standard.set(tokenString, forKey: "APNSDeviceToken")
        
        // 通知が成功したことをAnalyticsに記録
        Task {
            await MainActor.run {
                Analytics.logEvent("apns_token_received", parameters: [
                    "success": true,
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        }
    }
    
    func updateFCMToken(_ fcmToken: String) async {
        print("FCM Token: \(fcmToken)")
        
        // FCMトークンをローカルに保存
        UserDefaults.standard.set(fcmToken, forKey: "FCMToken")
        
        // デバイスIDを取得
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // FCMトークンをFirestoreに保存
        do {
            try await eventStorage.saveUserToken(deviceId, fcmToken)
            print("FCM Token saved to Firestore")
            
            // 成功したことをAnalyticsに記録
            Task {
                await MainActor.run {
                    Analytics.logEvent("fcm_token_saved", parameters: [
                        "success": true,
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
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            }
            
            // リトライロジック
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒待機
                await retryUpdateFCMToken(fcmToken, deviceId, retryCount: 1)
            }
        }
    }
    
    // リトライロジック（最大3回）
    private func retryUpdateFCMToken(_ fcmToken: String, _ deviceId: String, retryCount: Int) async {
        guard retryCount <= 3 else {
            print("FCMトークンの保存に3回失敗しました。次回アプリ起動時に再試行します。")
            return
        }
        
        print("FCMトークンの保存をリトライします。試行回数: \(retryCount)")
        
        do {
            try await eventStorage.saveUserToken(deviceId, fcmToken)
            print("FCM Token successfully saved to Firestore on retry #\(retryCount)")
        } catch {
            print("Error saving FCM token to Firestore on retry #\(retryCount): \(error)")
            
            // さらにリトライ
            Task {
                try? await Task.sleep(nanoseconds: UInt64(retryCount * 5_000_000_000)) // 待機時間を増やす
                await retryUpdateFCMToken(fcmToken, deviceId, retryCount: retryCount + 1)
            }
        }
    }
    
    func scheduleLocalNotification(title: String, body: String, triggerDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Local notification scheduled for \(triggerDate)")
            
            // 通知のスケジュールをAnalyticsに記録
            Task {
                await MainActor.run {
                    Analytics.logEvent("notification_scheduled", parameters: [
                        "title": title,
                        "date": triggerDate.timeIntervalSince1970
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
    
    // トークンステータスの取得
    func getTokens() -> TokenStatus {
        let apnsToken = UserDefaults.standard.string(forKey: "APNSDeviceToken")
        let fcmToken = Messaging.messaging().fcmToken ?? UserDefaults.standard.string(forKey: "FCMToken")
        
        return TokenStatus(
            apnsToken: apnsToken,
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
            await updateFCMToken(token)
        }
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
            saveDeviceToken: { tokenData in
                await service.saveDeviceToken(tokenData)
            },
            updateFCMToken: { token in
                await service.updateFCMToken(token)
            },
            scheduleLocalNotification: { title, body, date in
                await service.scheduleLocalNotification(title: title, body: body, triggerDate: date)
            },
            getNotificationStatus: {
                await service.checkNotificationStatus()
            },
            openNotificationSettings: {
                service.openSettings()
            },
            getTokenStatus: {
                service.getTokens()
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