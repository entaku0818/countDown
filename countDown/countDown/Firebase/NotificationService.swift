import Foundation
import UIKit
import FirebaseMessaging
import ComposableArchitecture
import UserNotifications

// MARK: - Notification Service
struct NotificationService {
    var registerForRemoteNotifications: @Sendable () async -> Void
    var setupMessaging: @Sendable () async -> Void
    var saveDeviceToken: @Sendable (Data) async -> Void
    var updateFCMToken: @Sendable (String) async -> Void
    var scheduleLocalNotification: @Sendable (String, String, Date) async -> Void
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
    }
    
    func saveDeviceToken(_ tokenData: Data) async {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(tokenString)")
        
        // デバイストークンをローカルに保存
        UserDefaults.standard.set(tokenString, forKey: "APNSDeviceToken")
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
        } catch {
            print("Error saving FCM token to Firestore: \(error)")
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
        } catch {
            print("Error scheduling notification: \(error)")
        }
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