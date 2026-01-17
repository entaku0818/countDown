//
//  AppOpenAdManager.swift
//  countDown
//
//  Created by Claude on 2026/01/17.
//

import GoogleMobileAds
import FirebaseAnalytics

/// アプリ起動時広告（App Open Ads）を管理するクラス
class AppOpenAdManager: NSObject {
    static let shared = AppOpenAdManager()

    /// 広告の有効期限（4時間）
    private let adExpirationHours: TimeInterval = 4

    /// 読み込み済みの広告
    private var appOpenAd: AppOpenAd?

    /// 広告が読み込まれた時刻
    private var loadTime: Date?

    /// 広告を読み込み中かどうか
    private var isLoadingAd = false

    /// 広告を表示中かどうか
    private var isShowingAd = false

    /// アプリの起動回数
    private var launchCount: Int {
        get { UserDefaults.standard.integer(forKey: "appLaunchCount") }
        set { UserDefaults.standard.set(newValue, forKey: "appLaunchCount") }
    }

    /// 広告を表示するまでの起動回数
    private let minimumLaunchCountForAd = 3

    /// 最後に広告を表示した時刻
    private var lastAdShowTime: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastAppOpenAdShowTime") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastAppOpenAdShowTime")
        }
    }

    /// 広告表示の最小間隔（分）
    private let minimumIntervalMinutes: TimeInterval = 5

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// アプリ起動時に呼び出す
    func appDidLaunch() {
        launchCount += 1
        loadAdIfNeeded()
    }

    /// フォアグラウンドに戻った時に広告を表示
    func showAdIfAvailable(from viewController: UIViewController) {
        // 起動回数が少ない場合はスキップ
        guard launchCount >= minimumLaunchCountForAd else {
            print("AppOpenAd: 起動回数が少ないためスキップ (\(launchCount)/\(minimumLaunchCountForAd))")
            loadAdIfNeeded()
            return
        }

        // 最小間隔チェック
        if let lastShow = lastAdShowTime,
           Date().timeIntervalSince(lastShow) < minimumIntervalMinutes * 60 {
            print("AppOpenAd: 最小間隔未経過のためスキップ")
            loadAdIfNeeded()
            return
        }

        // 広告表示中の場合はスキップ
        guard !isShowingAd else {
            print("AppOpenAd: 既に表示中のためスキップ")
            return
        }

        // 広告が有効かチェック
        guard let ad = appOpenAd, !isAdExpired() else {
            print("AppOpenAd: 広告が無効または期限切れ")
            loadAdIfNeeded()
            return
        }

        // 広告を表示
        print("AppOpenAd: 広告を表示")
        isShowingAd = true
        ad.fullScreenContentDelegate = self
        ad.present(from: viewController)

        Analytics.logEvent("app_open_ad_show_attempt", parameters: [
            "launch_count": launchCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    // MARK: - Private Methods

    /// 必要に応じて広告を読み込む
    private func loadAdIfNeeded() {
        // 既に読み込み中または有効な広告がある場合はスキップ
        guard !isLoadingAd, appOpenAd == nil || isAdExpired() else {
            return
        }

        isLoadingAd = true
        print("AppOpenAd: 広告の読み込みを開始")

        let adUnitID = getAdUnitID()

        AppOpenAd.load(with: adUnitID) { [weak self] ad, error in
            self?.isLoadingAd = false

            if let error = error {
                print("AppOpenAd: 読み込みエラー - \(error.localizedDescription)")
                Analytics.logEvent("app_open_ad_load_failed", parameters: [
                    "error": error.localizedDescription
                ])
                return
            }

            self?.appOpenAd = ad
            self?.loadTime = Date()
            print("AppOpenAd: 広告の読み込み完了")

            Analytics.logEvent("app_open_ad_loaded", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }

    /// 広告が期限切れかどうか
    private func isAdExpired() -> Bool {
        guard let loadTime = loadTime else { return true }
        let expireTime = loadTime.addingTimeInterval(adExpirationHours * 60 * 60)
        return Date() > expireTime
    }

    /// 広告ユニットIDを取得
    private func getAdUnitID() -> String {
        #if DEBUG
        // テスト用広告ID
        return "ca-app-pub-3940256099942544/9257395921"
        #else
        // 本番用広告ID（Release.xcconfigから取得するか、デフォルト値を使用）
        if let adUnitID = Bundle.main.object(forInfoKey: "ADMOB_APP_OPEN_ID") as? String,
           !adUnitID.isEmpty {
            return adUnitID
        }
        // フォールバック: テスト用ID
        return "ca-app-pub-3940256099942544/9257395921"
        #endif
    }
}

// MARK: - FullScreenContentDelegate
extension AppOpenAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("AppOpenAd: 広告が閉じられました")
        isShowingAd = false
        appOpenAd = nil
        lastAdShowTime = Date()

        Analytics.logEvent("app_open_ad_dismissed", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])

        // 次の広告を読み込む
        loadAdIfNeeded()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AppOpenAd: 広告の表示に失敗 - \(error.localizedDescription)")
        isShowingAd = false
        appOpenAd = nil

        Analytics.logEvent("app_open_ad_show_failed", parameters: [
            "error": error.localizedDescription
        ])

        // 次の広告を読み込む
        loadAdIfNeeded()
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("AppOpenAd: 広告を表示します")

        Analytics.logEvent("app_open_ad_shown", parameters: [
            "launch_count": launchCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}
