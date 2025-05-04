# CountDown アプリ Firebase Cloud Functions - 定期通知処理

このディレクトリには、CountDownアプリの定期的な通知処理を実装するFirebase Cloud Functionsが含まれています。

## 実装機能

**定期的な通知チェック・送信** (`sendEventNotifications`)
- 1時間ごとに実行され、通知が必要なイベントを確認して送信します
- Firestoreの `events` コレクションを監視し、通知日時が現在から1時間以内のイベントを検索
- 通知の送信状態を `notificationHistory` コレクションに記録

## 処理の流れ

1. 1時間ごとに定期実行されるCloud Function
2. 今後1時間以内に通知が必要なイベントをFirestoreから検索
3. 各イベントについて:
   - 通知が有効かチェック
   - ユーザーIDからFCMトークンを取得
   - FirebaseCloudMessagingを使用して通知を送信
   - 送信結果を履歴として保存

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
- Node.js（バージョン18以上）
- npm（最新版推奨）
- Firebase CLIツール

### インストール

1. Firebase CLIをインストール（まだの場合）:
```
npm install -g firebase-tools
```

2. Firebaseにログイン:
```
firebase login
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