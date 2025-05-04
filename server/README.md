# CountDown アプリ Firebase Cloud Functions - 定期通知処理

このディレクトリには、CountDownアプリの定期的な通知処理を実装するFirebase Cloud Functionsが含まれています。

## 環境構成情報

- **Node.js**: v22.15.0 (LTS)
- **Firebase CLI**: v11.14.1
- **Firebase Functions**: v3.24.1
- **Firebase Admin**: v10.0.2

## 実装機能

**定期的な通知チェック・送信** (`sendEventNotifications`)
- 1時間ごとに実行され、通知が必要なイベントを確認して送信します
- Firestoreの `events` コレクションを監視し、通知日時が現在から1時間以内のイベントを検索
- 通知の送信状態を `notificationHistory` コレクションに記録

**テスト用通知送信エンドポイント** (`sendTestNotification`)
- HTTP呼び出し可能な通知テスト用エンドポイント
- 指定したFCMトークンに直接テスト通知を送信可能
- URL: `https://us-central1-countdown-336cf.cloudfunctions.net/sendTestNotification`

## 処理の流れ

1. 1時間ごとに定期実行されるCloud Function
2. 今後1時間以内に通知が必要なイベントをFirestoreから検索
3. 各イベントについて:
   - 通知が有効かチェック
   - ユーザーIDからFCMトークンを取得
   - FirebaseCloudMessagingを使用して通知を送信
   - 送信結果を履歴として保存

## 制約条件

- **Firebase Blazeプラン（従量課金制）が必要**: 無料のSparkプランではCloud Functionsが使用できません
- **定期実行の最小間隔**: 1時間（Firebase Schedulerの制限）
- **FCMトークン有効期限**: FCMトークンは不定期に更新される可能性があるため、常に最新のトークンを使用する必要あり
- **CloudFunctions実行時間**: 関数の実行は最大540秒（9分）まで
- **Firestore読み書き制限**: Blazeプランでも大量の読み書きは課金対象
- **通知サイズ制限**: FCM通知のペイロードサイズは最大4KBまで
- **テスト通知機能の利用制限**: 開発・テスト目的のみに使用し、大量送信は避ける

## Firestoreデータモデル

### コレクション: events
イベントのデータを格納します。通知処理に必要なフィールド:
- `title`: イベントのタイトル
- `date`: イベントの日時（Timestamp）
- `userId`: ユーザーID
- `notificationDate`: 通知予定日時（Timestamp）
- `notificationEnabled`: 通知の有効/無効状態
- `daysRemaining`: イベントまでの残り日数

### コレクション: notificationHistory
通知の送信履歴を格納します:
- `eventId`: イベントID
- `eventTitle`: イベントのタイトル
- `userId`: ユーザーID
- `sentAt`: 送信日時（Timestamp）
- `status`: 通知ステータス（sent, failed）
- `errorMessage`: エラーメッセージ（失敗時）

## 開発環境のセットアップ

### 前提条件
- Node.js（バージョン22以上推奨）
- npm（最新版推奨）
- Firebase CLIツール（v11以上）

### インストール

1. Node.js v22をインストール:
```
nvm install v22.15.0
nvm use v22.15.0
```

2. Firebase CLIをインストール:
```
npm install -g firebase-tools
```

3. 依存関係をインストール:
```
cd functions
npm install
```

## ローカルでのテスト

エミュレータを起動:
```
firebase emulators:start
```

## デプロイ

Cloud Functionsをデプロイ:
```
firebase deploy --only functions
```

## セキュリティ

- Firestoreルールにより、ユーザーは自分のデータのみにアクセス可能
- 通知履歴の書き込みはCloud Functionsからのみ可能

## トラブルシューティング

- デプロイ時のエラーは `firebase deploy --debug` で詳細情報を確認
- 関数のログは Firebase コンソールの「Functions」>「ログ」で確認可能
- Node.jsのバージョン不一致エラーが出る場合は `nvm use v22.15.0` を実行 