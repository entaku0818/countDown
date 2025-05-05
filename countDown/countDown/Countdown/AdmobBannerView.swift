import GoogleMobileAds
import UIKit
import SwiftUI

// MARK: - バナー広告View
struct AdmobBannerView: UIViewRepresentable {
    @EnvironmentObject private var adConfig: AdConfig
    
    func makeUIView(context: Context) -> BannerView {
        let adSize = adSizeFor(cgSize: CGSize(width: 300, height: 50))
        let view = BannerView(adSize: adSize)

        // AdConfigから広告IDを取得
        view.adUnitID = adConfig.bannerAdUnitID
        view.rootViewController = UIApplication.shared.windows.first?.rootViewController
        view.delegate = context.coordinator
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
    }

    // Adding the Coordinator for delegate handling
     func makeCoordinator() -> Coordinator {
         Coordinator()
     }

    class Coordinator: NSObject, BannerViewDelegate {
        // 広告受信時
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("Banner Ad received successfully.")
        }

        // 広告受信失敗時
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Failed to load banner ad with error: \(error.localizedDescription)")
        }

        // インプレッションが記録された時
        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            print("Banner impression has been recorded")
        }

        // 広告がクリックされた時
        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            print("Banner ad was clicked")
        }
    }
} 
