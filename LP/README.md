# CountDown アプリ ランディングページ

このディレクトリには CountDown アプリのランディングページが含まれています。

## Firebase Hosting へのアップロード方法

ランディングページを Firebase Hosting にアップロードするには、以下の手順を実行してください。

### 前提条件

- Firebase CLI がインストールされていること
- Firebase プロジェクト `countdown-336cf` へのアクセス権があること

### 初期設定（初回のみ）

1. Firebase CLI をインストールする（まだインストールしていない場合）
   ```
   npm install -g firebase-tools
   ```

2. Firebase にログインする
   ```
   firebase login
   ```

3. プロジェクトを初期化する（このディレクトリではすでに完了しています）
   ```
   firebase init hosting
   ```
   - 既存のプロジェクト `countdown-336cf` を選択
   - 公開ディレクトリは `.` (カレントディレクトリ) を指定
   - 単一ページアプリケーションの場合は「Yes」を選択

### デプロイ方法

1. LP ディレクトリに移動
   ```
   cd /path/to/countDown/LP
   ```

2. Firebase Hosting にデプロイする
   ```
   firebase deploy --only hosting
   ```

3. デプロイが成功すると、以下のような出力が表示されます
   ```
   ✔  Deploy complete!

   Project Console: https://console.firebase.google.com/project/countdown-336cf/overview
   Hosting URL: https://countdown-336cf.web.app
   ```

4. デプロイされたウェブサイトには `https://countdown-336cf.web.app` でアクセスできます

### ファイル更新後のデプロイ

ファイルを変更したら、再度 `firebase deploy --only hosting` コマンドを実行してウェブサイトを更新してください。

## ディレクトリ構成

- `index.html` - メインのランディングページ
- `privacy_policy.html` - プライバシーポリシーページ
- `terms_of_service.html` - 利用規約ページ
- `css/` - スタイルシート
- `js/` - JavaScript ファイル
- `images/` - 画像ファイル

## 注意事項

- `.firebaserc` と `firebase.json` はプロジェクト設定ファイルなので編集しないでください
- `.firebase/` ディレクトリはデプロイ情報が含まれるため、gitignore に追加されています 