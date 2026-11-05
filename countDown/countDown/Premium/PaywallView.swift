import SwiftUI
import ComposableArchitecture

struct PaywallView: View {
    let store: StoreOf<PaywallFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                benefits
                plans
                purchaseButton
                footer
            }
            .padding()
        }
        .overlay {
            if store.isPurchasing {
                ProgressView().controlSize(.large)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { store.send(.closeTapped) }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    private var headline: String {
        switch store.reason {
        case .goalLimit: return "楽しみを、いくつでも"
        case .stepLimit: return "道のりを、もっと細かく"
        case .nestedStep: return "ステップの中にもステップを"
        case .settings: return "CountDown プレミアム"
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.pink, .orange)
            Text(headline)
                .font(.title2).bold()
            Text("大切な日までの道のりを、制限なく楽しもう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("infinity", "ゴールもステップも無制限", "結婚式・旅行・記念日をいくつでも")
            benefit("list.bullet.indent", "ステップを何階層でも", "前撮り → 衣装合わせ → 小物選び…")
            benefit("photo", "写真ウィジェット", "ホーム画面に思い出の写真とカウントダウン")
            benefit("checkmark.circle", "ウィジェットから完了チェック", "アプリを開かずに道のりを進める")
            benefit("nosign", "広告なし", "すっきり集中できる")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.pink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var plans: some View {
        if store.isLoading {
            ProgressView().padding()
        } else {
            VStack(spacing: 10) {
                ForEach(store.packages) { package in
                    planRow(package)
                }
            }
        }
        if let message = store.errorMessage {
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    private func planRow(_ package: PaywallPackage) -> some View {
        let selected = store.selectedId == package.id
        return Button {
            store.send(.selectPackage(package.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title(for: package.kind)).bold()
                        if package.kind == .annual {
                            Text("おすすめ")
                                .font(.caption2).bold()
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.pink)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    if let trial = package.trial {
                        Text(trial).font(.caption).foregroundColor(.pink)
                    } else if package.kind == .lifetime {
                        Text("一度の購入でずっと使える").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(package.price + suffix(for: package.kind)).bold()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.pink : Color(.systemGray4), lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func title(for kind: PaywallPackage.Kind) -> String {
        switch kind {
        case .annual: return "年額プラン"
        case .monthly: return "月額プラン"
        case .lifetime: return "買い切り"
        case .other: return "プラン"
        }
    }

    private func suffix(for kind: PaywallPackage.Kind) -> String {
        switch kind {
        case .annual: return " / 年"
        case .monthly: return " / 月"
        default: return ""
        }
    }

    private var purchaseButton: some View {
        Button {
            store.send(.purchaseTapped)
        } label: {
            Text(store.packages.first { $0.id == store.selectedId }?.trial != nil ? "無料で試してみる" : "プレミアムにする")
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(store.selectedId == nil || store.isPurchasing)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button("購入を復元") { store.send(.restoreTapped) }
                .font(.footnote)
            Text("サブスクリプションは期間終了の24時間前までに解約しない限り自動更新されます。解約は「設定」アプリのApple IDから行えます。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("利用規約", destination: URL(string: "https://countdown-336cf.web.app/terms_of_service.html")!)
                Link("プライバシーポリシー", destination: URL(string: "https://countdown-336cf.web.app/privacy_policy.html")!)
            }
            .font(.caption2)
        }
    }
}
