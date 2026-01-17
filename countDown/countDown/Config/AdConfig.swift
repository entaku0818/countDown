import Foundation
import SwiftUI

// 広告設定を管理するクラス
class AdConfig: ObservableObject {
    static let shared = AdConfig()
    let bannerAdUnitID: String
    
    private init() {
        self.bannerAdUnitID = AdConfig.getBannerAdUnitID()
    }
    
    // Info.plistからxcconfig設定値を取得する
    private static func getConfigValue(for key: String) -> String? {
        return Bundle.main.object(forInfoKey: key) as? String
    }
    
    // バナー広告ユニットIDを取得するメソッド
    private static func getBannerAdUnitID() -> String {
        // 1. 環境変数から取得を試みる
        if let envAdUnitID = ProcessInfo.processInfo.environment["ADMOB_BANNER_ID"],
           !envAdUnitID.isEmpty {
            print("Using AdMob banner ID from environment variable: \(envAdUnitID)")
            return envAdUnitID
        }
        
        // 2. Info.plistに追加されたxcconfig値を取得
        if let adUnitID = getConfigValue(for: "ADMOB_BANNER_ID"),
           !adUnitID.isEmpty {
            print("Using AdMob banner ID from xcconfig: \(adUnitID)")
            return adUnitID
        }
        
        // 3. デフォルト値を使用
        #if DEBUG
        // デバッグ用のデフォルト値を使用
        print("Using default debug AdMob banner ID")
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        // フォールバック用テストID（通常はRelease.xcconfigの値が使用される）
        print("Using default release AdMob banner ID")
        return "ca-app-pub-3940256099942544/2435281174"
        #endif
    }
}

// Bundleの拡張
extension Bundle {
    func object(forInfoKey key: String) -> Any? {
        return infoDictionary?[key]
    }
} 