import Foundation
import ComposableArchitecture
import RevenueCat

/// ペイウォールに表示する商品（RevenueCat の型を State に持ち込まないための軽量版）
struct PaywallPackage: Equatable, Identifiable {
    enum Kind: Equatable { case monthly, annual, lifetime, other }

    var id: String
    var kind: Kind
    var price: String
    /// 例: 「7日間無料」
    var trial: String?
}

/// RevenueCat の副作用を包むクライアント
struct PurchaseClient {
    var configure: @Sendable () -> Void
    var premiumStream: @Sendable () -> AsyncStream<Bool>
    var loadPackages: @Sendable () async throws -> [PaywallPackage]
    var purchase: @Sendable (_ packageId: String) async throws -> Bool
    var restore: @Sendable () async throws -> Bool
}

private actor PackageCache {
    var packages: [String: Package] = [:]
    func set(_ list: [Package]) { packages = Dictionary(uniqueKeysWithValues: list.map { ($0.identifier, $0) }) }
    func get(_ id: String) -> Package? { packages[id] }
}

extension PurchaseClient: DependencyKey {
    static let liveValue: PurchaseClient = {
        let cache = PackageCache()

        func isPremium(_ info: CustomerInfo) -> Bool {
            info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        }

        return PurchaseClient(
            configure: {
                guard RevenueCatConfig.isConfigured, !Purchases.isConfigured else { return }
                #if DEBUG
                Purchases.logLevel = .debug
                #endif
                Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
            },
            premiumStream: {
                AsyncStream { continuation in
                    guard RevenueCatConfig.isConfigured, Purchases.isConfigured else {
                        continuation.finish()
                        return
                    }
                    let task = Task {
                        for await info in Purchases.shared.customerInfoStream {
                            continuation.yield(isPremium(info))
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            loadPackages: {
                guard RevenueCatConfig.isConfigured else { return [] }
                let offerings = try await Purchases.shared.offerings()
                guard let offering = offerings.offering(identifier: RevenueCatConfig.offeringID) ?? offerings.current else { return [] }
                await cache.set(offering.availablePackages)
                return offering.availablePackages.map { package in
                    let kind: PaywallPackage.Kind
                    switch package.packageType {
                    case .monthly: kind = .monthly
                    case .annual: kind = .annual
                    case .lifetime: kind = .lifetime
                    default: kind = .other
                    }
                    var trial: String?
                    if let intro = package.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
                        let period = intro.subscriptionPeriod
                        switch period.unit {
                        case .day: trial = "\(period.value)日間無料"
                        case .week: trial = "\(period.value * 7)日間無料"
                        case .month: trial = "\(period.value)ヶ月無料"
                        case .year: trial = "\(period.value)年間無料"
                        @unknown default: trial = "無料トライアルあり"
                        }
                    }
                    return PaywallPackage(id: package.identifier, kind: kind, price: package.localizedPriceString, trial: trial)
                }
            },
            purchase: { packageId in
                guard let package = await cache.get(packageId) else { return false }
                let result = try await Purchases.shared.purchase(package: package)
                if result.userCancelled { return false }
                return isPremium(result.customerInfo)
            },
            restore: {
                isPremium(try await Purchases.shared.restorePurchases())
            }
        )
    }()

    static let testValue = PurchaseClient(
        configure: {},
        premiumStream: { AsyncStream { $0.finish() } },
        loadPackages: { [] },
        purchase: { _ in false },
        restore: { false }
    )
}

extension DependencyValues {
    var purchaseClient: PurchaseClient {
        get { self[PurchaseClient.self] }
        set { self[PurchaseClient.self] = newValue }
    }
}
