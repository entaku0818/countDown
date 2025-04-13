# CountDown App

## プロジェクトルール

### アーキテクチャ
- The Composable Architecture (TCA) を使用
- 状態管理は `@ObservableState` と `@Bindable` を活用
- データ構造は `IdentifiedArrayOf` ではなく通常の配列を使用

### コード規約
1. モデル定義
   - モデルは `CountdownFeature.swift` に集約
   - 重複する型定義を避ける
   - イベント関連の型は `Event` 名前空間内に定義

2. ビュー実装
   - `WithViewStore` の使用を避け、`@Bindable` を活用
   - 状態のバインディングは `BindableState` を使用
   - ビューは可能な限りシンプルに保つ

3. 機能実装
   - 新機能は Issue として管理
   - 実装前に要件とタスクを明確化
   - プレミアム版と無料版の機能差を考慮

### バージョン管理
- 機能単位で Issue を作成
- 実装完了後は Issue をクローズ
- 変更内容は Issue 番号を参照して記録

## 開発環境
- SwiftUI
- The Composable Architecture
- iOS 17.0+ 

## 開発タスク管理

### GitHub Issues
- 全ての残タスクは GitHub Issues で管理しています
- 開発を始める前に必ず Issues を確認してください
- 新しい機能や修正は Issue を作成してから取り組んでください
- Issue の URL: https://github.com/entaku0818/countDown/issues

### Issue 確認方法
1. GitHub リポジトリにアクセス: https://github.com/entaku0818/countDown
2. 「Issues」タブを選択
3. 開いている Issue を確認

### コマンドラインから Issue を確認する場合
```
# すべての Issue を表示
gh issue list

# オープン状態の Issue のみ表示
gh issue list --state open

# 特定の Issue の詳細を表示
gh issue view <ISSUE_NUMBER>

# 新しい Issue を作成
gh issue create --title "タイトル" --body "詳細説明"
```

### Issue 管理のルール
- 着手前に Issue に自分をアサインする
- 作業内容はコミットメッセージに Issue 番号を含める (例: "#12 通知機能を実装")
- 完了したら Pull Request を作成し、Issue をクローズする 