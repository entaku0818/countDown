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