import Foundation
import ComposableArchitecture

@Reducer
struct PaywallFeature {
    /// ペイウォールを開いたきっかけ（見出しの文言を変える）
    enum Reason: Equatable {
        case goalLimit
        case stepLimit
        case nestedStep
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var reason: Reason
        var packages: [PaywallPackage] = []
        var selectedId: String?
        var isLoading = false
        var isPurchasing = false
        var errorMessage: String?
    }

    enum Action {
        case onAppear
        case packagesLoaded(Result<[PaywallPackage], Error>)
        case selectPackage(String)
        case purchaseTapped
        case restoreTapped
        case purchaseFinished(Result<Bool, Error>)
        case closeTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case premiumActivated
            case close
        }
    }

    @Dependency(\.purchaseClient) var purchaseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.packages.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    await send(.packagesLoaded(Result { try await purchaseClient.loadPackages() }))
                }

            case let .packagesLoaded(.success(packages)):
                state.isLoading = false
                // 年額 → 買い切り → 月額 の順に並べ、年額をおすすめとして初期選択
                let order: [PaywallPackage.Kind] = [.annual, .lifetime, .monthly, .other]
                state.packages = packages.sorted {
                    (order.firstIndex(of: $0.kind) ?? 9) < (order.firstIndex(of: $1.kind) ?? 9)
                }
                state.selectedId = state.packages.first?.id
                if packages.isEmpty {
                    state.errorMessage = "プランを読み込めませんでした。時間をおいてお試しください。"
                }
                return .none

            case .packagesLoaded(.failure):
                state.isLoading = false
                state.errorMessage = "プランを読み込めませんでした。通信環境をご確認ください。"
                return .none

            case let .selectPackage(id):
                state.selectedId = id
                return .none

            case .purchaseTapped:
                guard let id = state.selectedId, !state.isPurchasing else { return .none }
                state.isPurchasing = true
                state.errorMessage = nil
                return .run { send in
                    await send(.purchaseFinished(Result { try await purchaseClient.purchase(id) }))
                }

            case .restoreTapped:
                guard !state.isPurchasing else { return .none }
                state.isPurchasing = true
                state.errorMessage = nil
                return .run { send in
                    await send(.purchaseFinished(Result { try await purchaseClient.restore() }))
                }

            case let .purchaseFinished(.success(isPremium)):
                state.isPurchasing = false
                return isPremium ? .send(.delegate(.premiumActivated)) : .none

            case .purchaseFinished(.failure):
                state.isPurchasing = false
                state.errorMessage = "購入を完了できませんでした。もう一度お試しください。"
                return .none

            case .closeTapped:
                return .send(.delegate(.close))

            case .delegate:
                return .none
            }
        }
    }
}
