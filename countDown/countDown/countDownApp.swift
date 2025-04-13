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

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // MARK: - Dependencies
    @Dependency(\.notificationService) var notificationService
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebaseの設定
        FirebaseApp.configure()
        

        // テストイベントを送信
        Analytics.logEvent("app_launched", parameters: nil)
        
        // 通知デリゲートの設定
        UNUserNotificationCenter.current().delegate = self
        
        // プッシュ通知の初期設定
        Task {
            await notificationService.registerForRemoteNotifications()
            await notificationService.setupMessaging()
        }
        
        return true
    }
    
    // MARK: - Remote Notifications
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        
        Task {
            await notificationService.saveDeviceToken(deviceToken)
        }
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // 通知がタップされた時の処理
        let userInfo = response.notification.request.content.userInfo
        print("通知がタップされました: \(userInfo)")
        
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
