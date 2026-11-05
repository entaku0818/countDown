# 引き継ぎメモ（2026-11-05）

全体の構想・ロードマップは `docs/concept-v1.md` を参照。

## ルール
- **審査提出はロードマップ全フェーズ完了後**。途中で `submit_for_review` / `fastlane ios submit_build` を実行しない（ユーザー指示）
- テスト: `xcodebuild test -project countDown/countDown.xcodeproj -scheme countDown -destination 'id=73F587F5-0305-460B-8014-4718944DE336' -only-testing:countDownTests`（iPhone 17 Pro シミュレーター。iPhone 18 Pro はアプリ起動失敗が出た）
- ASC 認証情報は `countDown/fastlane/.env`。メタデータだけ送るときは `fastlane ios metadata version:x.y.z`

## 完了
| フェーズ | 内容 | コミット |
|---|---|---|
| ASO | 名前「CountDown - 楽しみまであと何日」/ 英「CountDownList - Days Until」、サブタイトル・キーワード・説明文・プロモテキスト刷新 | 5042127, 7e7a6e8 |
| v0.3 | ゴール/ステップ階層（`Event.parentId`, `isCompleted`、無制限ネスト）、詳細画面の「道のり」 | 05f9d12 |
| v0.4 | ウィジェット刷新（進捗リング・次のステップ・写真背景・`ToggleStepIntent` で完了チェック → App Group の `PendingStepToggles` 経由でアプリに反映） | 4be8bc4 |
| v0.5 コード | RevenueCat 導入、`Premium/`（PurchaseClient, PaywallFeature/View, RevenueCatConfig）、無料枠ゲート、広告非表示 | 15b6ba6, cb64e0f |

## App Store Connect の状態
- バージョン 0.2.2 / build 30 アップロード済み、**PREPARE_FOR_SUBMISSION（未提出）**。※このビルドは v0.3 時点。最終リリース時は新ビルドに差し替え
- 課金アイテム作成済み（175地域に価格・販売設定済み）
  - サブスクグループ `CountDown Premium` (22549157)
  - 月額 `com.entaku.countDown.premium.monthly` ¥300 (6831175536)
  - 年額 `com.entaku.countDown.premium.annual` ¥1,800、1週間無料トライアル (6831175623)
  - 買い切り `com.entaku.countDown.premium.lifetime` ¥3,600 非消耗型 (6831183175)
  - **未対応: 各アイテムの審査用スクリーンショット**（初回提出時に必要）

## 残タスク
1. **RevenueCat 設定**（ダッシュボード操作が必要。ブラウザ未接続で止まっている）
   - プロジェクト「CountDown」作成 → App Store アプリ `com.entaku.countDown` 追加（In-App Purchase キーは Festory と同じ `7QCTX63356` を再利用可）
   - 3商品をインポート → entitlement `premium` に3つ紐付け → offering `default` に Monthly / Annual / Lifetime パッケージ
   - 公開SDKキー `appl_...` を `countDown/countDown/Premium/RevenueCatConfig.swift` の `apiKey` に投入（公開キーなのでコミット可）
   - 投入するとゲートが有効化される（空の間は全機能開放・広告は従来どおり）
2. **ウィジェットの見た目確認**（v0.4/v0.5 は未目視。Xcode Preview がタイムアウトした）
3. **v0.6**: テンプレート（結婚式・海外旅行・出産・推しライブで定番ステップ自動投入）、節目のお祝い（100日前・半分経過・ステップ完了で紙吹雪＋通知）、ワクワクメモ（1日1行）
4. **v1.0**: 振り返りカード共有、スクショ全面刷新（ウィジェット・道のりを前面に）、説明文・リリースノートを新機能に合わせて更新
5. 全部終わったら: ユーザー確認 → バージョン/ビルド番号更新 → アーカイブ・アップロード → 課金アイテムと一緒に審査提出

## 補足
- `countDown/fastlane/README.md` は fastlane 実行で自動変更されたもの（未コミットのまま）
