import Foundation

/// RevenueCat の設定値。
/// `apiKey` が空の間は課金を無効化し、全機能を開放する（=従来どおり無料で使える）。
/// App Store Connect / RevenueCat のセットアップ後に公開SDKキー(appl_...)を入れる。
enum RevenueCatConfig {
    static let apiKey = ""
    static let entitlementID = "premium"
    static let offeringID = "default"

    static var isConfigured: Bool { !apiKey.isEmpty }
}

/// 無料版の上限
enum FreePlanLimit {
    /// ゴール（トップレベルのイベント）の数
    static let goals = 3
    /// 1つのゴール（またはステップ）の直下に作れるステップ数
    static let stepsPerParent = 3
    /// ステップを作れる階層の深さ（1 = ゴール直下のみ）
    static let stepDepth = 1
}

/// プレミアム状態をアプリ全体（広告・ウィジェット）から参照するための共有フラグ
enum PremiumStatus {
    private static let key = "IsPremiumUser"

    static var isActive: Bool {
        !RevenueCatConfig.isConfigured || (SharedDataManager.sharedDefaults?.bool(forKey: key) ?? false)
    }

    /// 広告を消すか。課金未設定の間は従来どおり広告を出す
    static var removesAds: Bool {
        RevenueCatConfig.isConfigured && (SharedDataManager.sharedDefaults?.bool(forKey: key) ?? false)
    }

    static func update(_ isPremium: Bool) {
        SharedDataManager.sharedDefaults?.set(isPremium, forKey: key)
    }
}
