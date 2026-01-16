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
import UserNotifications
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // MARK: - Dependencies
    @Dependency(\.alarmService) var alarmService

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebaseの設定（Analyticsのみ使用）
        FirebaseApp.configure()

        // Google AdMobの初期化
        print("AppDelegate: AdMobの初期化を開始")
        MobileAds.shared.start { status in
            print("AppDelegate: AdMobの初期化完了 - ステータス: \(status)")
        }

        // アプリ起動イベントを送信
        Analytics.logEvent("app_launched", parameters: [
            "timestamp": Date().timeIntervalSince1970,
            "os_version": UIDevice.current.systemVersion
        ])

        // 通知デリゲートの設定
        UNUserNotificationCenter.current().delegate = self

        // 通知の権限をリクエスト
        Task {
            let granted = await alarmService.requestAuthorization()

            // 通知設定の状態をログに記録
            let status = await alarmService.getNotificationStatus()
            Analytics.logEvent("notification_status", parameters: [
                "status": String(describing: status),
                "granted": granted,
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
                print("トラッキング許可が承認されました")
                Analytics.logEvent("tracking_authorized", parameters: nil)

            case .denied:
                print("トラッキング許可が拒否されました")
                Analytics.logEvent("tracking_denied", parameters: nil)

            case .restricted:
                print("トラッキングが制限されています")
                Analytics.logEvent("tracking_restricted", parameters: nil)

            case .notDetermined:
                print("トラッキング許可が未決定です")
                Analytics.logEvent("tracking_notdetermined", parameters: nil)

            @unknown default:
                print("不明なトラッキング許可状態です")
                Analytics.logEvent("tracking_unknown", parameters: nil)
            }
        }
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
