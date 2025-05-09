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
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    // MARK: - Dependencies
    @Dependency(\.notificationService) var notificationService
    @Dependency(\.authClient) var authClient
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebaseの設定
        FirebaseApp.configure()
        
        // Google AdMobの初期化
        print("AppDelegate: AdMobの初期化を開始")
        MobileAds.shared.start { status in
            print("AppDelegate: AdMobの初期化完了 - ステータス: \(status)")
        }
        
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
        
        // App Tracking Transparencyの許可リクエストは
        // アプリの起動から少し遅らせて表示（ユーザー体験向上のため）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestTrackingAuthorization()
        }
        
        return true
    }
    
    // MARK: - App Tracking Transparency
    func requestTrackingAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                // トラッキング許可が与えられた
                print("トラッキング許可が承認されました")
                Analytics.logEvent("tracking_authorized", parameters: nil)
                
            case .denied:
                // ユーザーが許可を拒否
                print("トラッキング許可が拒否されました")
                Analytics.logEvent("tracking_denied", parameters: nil)
                
            case .restricted:
                // デバイス制限により許可できない
                print("トラッキングが制限されています")
                Analytics.logEvent("tracking_restricted", parameters: nil)
                
            case .notDetermined:
                // ユーザーがまだ選択していない
                print("トラッキング許可が未決定です")
                Analytics.logEvent("tracking_notdetermined", parameters: nil)
                
            @unknown default:
                print("不明なトラッキング許可状態です")
                Analytics.logEvent("tracking_unknown", parameters: nil)
            }
        }
    }
    
    // MARK: - Remote Notifications
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        
        Task {
            // ユーザーIDを取得
            let userId = authClient.getCurrentUserId()
            
            if !userId.isEmpty {
                await notificationService.saveDeviceToken(deviceToken, userId)
                
                // Analyticsに成功を記録
                await MainActor.run {
                    Analytics.logEvent("remote_notification_register_success", parameters: [
                        "userId": userId,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            } else {
                print("ユーザーIDが空のため、デバイストークンを保存できません")
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
            // ユーザーIDを取得
            let userId = authClient.getCurrentUserId()
            
            if !userId.isEmpty {
                await notificationService.updateFCMToken(token, userId)
                
                // Analyticsに記録
                Analytics.logEvent("fcm_token_updated", parameters: [
                    "token_length": token.count,
                    "userId": userId
                ])
            } else {
                print("ユーザーIDが空のため、FCMトークンを保存できません")
            }
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
    @StateObject private var adConfig = AdConfig.shared
    
    var body: some Scene {
        WindowGroup {
            CountdownView(
                store: Store(initialState: CountdownFeature.State()) {
                    CountdownFeature()
                }
            )
            .environmentObject(adConfig)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // アプリがアクティブになったときにもトラッキング許可を確認（初回起動以外の場合）
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    delegate.requestTrackingAuthorization()
                }
            }
        }
    }
}
