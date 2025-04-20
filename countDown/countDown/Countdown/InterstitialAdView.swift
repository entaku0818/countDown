import GoogleMobileAds
import UIKit
import SwiftUI

// MARK: - インタースティシャル広告View
struct InterstitialAdView: View {
    // 広告表示のトリガーとなるボディプロパティ
    @State private var showAd: Bool = false
    
    var body: some View {
        // 実際には何も表示しない（広告はViewの上に表示される）
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: showAd) { _, shouldShow in
                if shouldShow {
                    AdManager.shared.showInterstitial()
                    showAd = false
                }
            }
    }
    
    // 広告表示のトリガーメソッド
    func triggerAd() {
        showAd = true
    }
    
    // MARK: - 広告管理クラス (InterstitialAdViewの内部クラス)
    class AdManager {
        static let shared = AdManager()
        
        private var interstitialAd: InterstitialAd?
        private var lastAdShownTime: Date?
        
        private init() {
            loadInterstitialAd()
        }
        
        func loadInterstitialAd() {
            let request = Request()
            #if DEBUG
            let adUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用ID
            #else
            let adUnitID = "ca-app-pub-3940256099942544/4411468910" // 本番環境では実際の広告IDに変更
            #endif
            
            InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                    return
                }
                self?.interstitialAd = ad
                print("Interstitial ad loaded successfully")
            }
        }
        
        func showInterstitial() {
            guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
                print("No view controller available to show interstitial ad")
                return
            }
            
            // 50%の確率で広告を表示
            let showAd = Bool.random()
            guard showAd else {
                print("Random check decided not to show ad this time")
                return
            }
            
            // 前回の表示から1分以上経過していることを確認
            if let lastShown = lastAdShownTime, Date().timeIntervalSince(lastShown) < 60 {
                print("Too soon to show another interstitial ad")
                return
            }
            
            guard let interstitialAd = interstitialAd else {
                print("Interstitial ad not loaded yet")
                return
            }
            
            interstitialAd.present(from: viewController)
            lastAdShownTime = Date()
            
            // 次回のために新しい広告を読み込む
            loadInterstitialAd()
        }
    }
} 
