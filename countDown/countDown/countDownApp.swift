//
//  countDownApp.swift
//  countDown
//
//  Created by 遠藤拓弥 on 2025/04/06.
//

import SwiftUI
import ComposableArchitecture
import FirebaseCore
import FirebaseAnalytics
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    // MARK: - Dependencies
    @Dependency(\.notificationService) var notificationService
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebaseの設定
        FirebaseApp.configure()
        
        // テストイベントを送信
        Analytics.logEvent("app_launched", parameters: [
            "timestamp": Date().timeIntervalSince1970,
            "os_version": UIDevice.current.systemVersion
        ])
        
        // 通知デリゲートの設定
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // プッシュ通知の初期設定
        Task {
            await notificationService.registerForRemoteNotifications()
            await notificationService.setupMessaging()
            
            // 通知設定の状態を取得してログに記録
            let status = await notificationService.getNotificationStatus()
            Analytics.logEvent("notification_status", parameters: [
                "status": String(describing: status),
                "timestamp": Date().timeIntervalSince1970
            ])
        }
        
        return true
    }
    
    // MARK: - Remote Notifications
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        
        Task {
            await notificationService.saveDeviceToken(deviceToken)
            
            // Analyticsに成功を記録
            await MainActor.run {
                Analytics.logEvent("remote_notification_register_success", parameters: [
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
        
        // Analyticsにエラーを記録
        Analytics.logEvent("remote_notification_register_error", parameters: [
            "error": error.localizedDescription,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // 3秒後にリトライ
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            application.registerForRemoteNotifications()
        }
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("FCM registration token is nil")
            return
        }
        
        print("======================= FCM TOKEN =======================")
        print("\(token)")
        print("=========================================================")
        
        // トークンを保存
        Task {
            await notificationService.updateFCMToken(token)
            
            // Analyticsに記録
            Analytics.logEvent("fcm_token_updated", parameters: [
                "token_length": token.count
            ])
        }
    }

    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("バックグラウンドで通知を受信しました: \(userInfo)")

        // Analyticsに記録
        Analytics.logEvent("notification_received_background", parameters: [
            "has_userInfo": !userInfo.isEmpty,
            "timestamp": Date().timeIntervalSince1970
        ])

        completionHandler(.newData)
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
        
        // Analyticsに記録
        let userInfo = notification.request.content.userInfo
        Analytics.logEvent("notification_received_foreground", parameters: [
            "title": notification.request.content.title,
            "has_userInfo": !userInfo.isEmpty,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // 通知がタップされた時の処理
        let userInfo = response.notification.request.content.userInfo
        print("通知がタップされました: \(userInfo)")
        
        // Analyticsに記録
        Analytics.logEvent("notification_tapped", parameters: [
            "title": response.notification.request.content.title,
            "action": response.actionIdentifier,
            "has_userInfo": !userInfo.isEmpty,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        completionHandler()
    }
}

@main
struct countDownApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            CountdownView(
                store: Store(initialState: CountdownFeature.State()) {
                    CountdownFeature()
                }
            )
        }
    }
}
