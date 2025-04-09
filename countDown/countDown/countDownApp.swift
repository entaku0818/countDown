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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // テストイベントを送信
        Analytics.logEvent("app_launched", parameters: nil)
        
        return true
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
