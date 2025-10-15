# Rails で Event Sourcing + CQRS を実装するサンプル

このリポジトリは、Rails アプリケーションで Event Sourcing と CQRS を実装する4つの異なるパターンを提供します。
各パターンは複雑さと機能のトレードオフが異なり、プロジェクトの要件に応じて選択できます。

## 📁 プロジェクト構成

```
rails_event_sourcing/
├── pattern1_lightweight_cqrs/       # パターン1: 軽量CQRS
├── pattern2_rails_event_store/      # パターン2: Rails Event Store
├── pattern3_full_event_sourcing/    # パターン3: フルEvent Sourcing
├── pattern4_activerecord_events/    # パターン4: ActiveRecord Events
└── README.md                         # このファイル
```

## 🎯 4つの実装パターン

### Pattern 1: 軽量 CQRS (Lightweight CQRS)

**概要**: Event Sourcing を使わず、CQRS の概念のみを導入した軽量な実装

**特徴**:
- ✅ 既存の Rails アプリに導入しやすい
- ✅ ActiveRecord をそのまま使用
- ✅ 学習コストが低い
- ❌ イベント履歴が残らない
- ❌ 状態の復元ができない

**使用技術**: ActiveRecord, Service Objects

**適用シーン**:
- CQRS の概念を学びたい
- 既存アプリに段階的に導入したい
- イベント履歴が不要なシンプルなアプリ

**ディレクトリ**: [`pattern1_lightweight_cqrs/`](./pattern1_lightweight_cqrs/)

---

### Pattern 2: Rails Event Store (推奨)

**概要**: Rails Event Store を使った本格的な Event Sourcing + CQRS の実装

**特徴**:
- ✅ イベントの完全な履歴が残る
- ✅ 任意の時点の状態を復元可能
- ✅ 監査ログが自動的に構築される
- ✅ Rails との統合が容易
- ⚠️ 学習コストが中程度
- ⚠️ イベント設計が重要

**使用技術**: Rails Event Store, AggregateRoot gem

**適用シーン**:
- 完全な監査ログが必要
- 過去の状態を復元する必要がある
- 複雑なビジネスロジック
- 実務での導入を検討

**ディレクトリ**: [`pattern2_rails_event_store/`](./pattern2_rails_event_store/)

---

### Pattern 3: フル Event Sourcing

**概要**: ActiveRecord を使わない、純粋な Event Sourcing の参考実装

**特徴**:
- ✅ 完全なイベント駆動設計
- ✅ フレームワークに依存しない
- ✅ 高度なドメインモデリングが可能
- ❌ 実装の複雑さが高い
- ❌ 小規模プロジェクトには過剰

**使用技術**: Pure Ruby, 自作 Event Store

**適用シーン**:
- 超大規模システム
- イベント駆動マイクロサービス
- DDD を徹底したい
- 学習・研究目的

**ディレクトリ**: [`pattern3_full_event_sourcing/`](./pattern3_full_event_sourcing/)

---

### Pattern 4: ActiveRecord による Event Sourcing (実用的)

**概要**: Rails Event Store を使わず、ActiveRecord でイベントを永続化する実装

**特徴**:
- ✅ Rails Event Store gem が不要
- ✅ ActiveRecord の機能をフル活用
- ✅ イベントの完全な履歴が残る
- ✅ 既存の Rails 知識で実装可能
- ⚠️ 高度な機能は自前実装が必要

**使用技術**: ActiveRecord, Pure Ruby Events

**適用シーン**:
- Rails Event Store を使いたくない
- 外部 gem への依存を減らしたい
- シンプルな Event Sourcing を実現したい
- 中規模のアプリケーション

**ディレクトリ**: [`pattern4_activerecord_events/`](./pattern4_activerecord_events/)

---

## 📊 パターン比較表

| 項目 | Pattern 1 | Pattern 2 | Pattern 3 | Pattern 4 |
|-----|-----------|-----------|-----------|-----------|
| **複雑さ** | 低 | 中 | 高 | 中 |
| **学習コスト** | 低 | 中 | 高 | 低〜中 |
| **イベント履歴** | ❌ | ✅ | ✅ | ✅ |
| **状態復元** | ❌ | ✅ | ✅ | ✅ |
| **ActiveRecord** | ✅ | 一部使用 | ❌ | ✅ |
| **外部gem依存** | なし | RES必須 | なし | なし |
| **Rails依存** | 高 | 中 | 低 | 高 |
| **監査ログ** | 手動 | 自動 | 自動 | 自動 |
| **導入難易度** | 易 | 中 | 難 | 中 |
| **保守性** | 中 | 高 | 高 | 中〜高 |
| **スケーラビリティ** | 中 | 高 | 最高 | 中〜高 |
| **推奨用途** | 学習/小規模 | 実務推奨 | 大規模/研究 | 実務/中規模 |

## 🚀 使い方

各パターンのディレクトリには、詳細な README と実装例が含まれています。

### Pattern 1 を試す
```bash
cd pattern1_lightweight_cqrs
cat README.md
```

### Pattern 2 を試す
```bash
cd pattern2_rails_event_store
cat README.md
```

### Pattern 3 を試す（実行可能な例）
```bash
cd pattern3_full_event_sourcing
ruby example_usage.rb
```

### Pattern 4 を試す
```bash
cd pattern4_activerecord_events
cat README.md
```

## 📚 学習パス

### 初心者向け
1. **Pattern 1** で CQRS の基本概念を理解
2. **Pattern 4** で ActiveRecord による Event Sourcing を体験
3. **Pattern 2** で Rails Event Store を学習
4. **Pattern 3** で理論的な理解を深める

### 実務導入向け（gem を使いたい場合）
1. **Pattern 1** で既存システムに CQRS を導入
2. **Pattern 2** (Rails Event Store) で本格的な Event Sourcing へ移行

### 実務導入向け（gem を使いたくない場合）
1. **Pattern 1** で既存システムに CQRS を導入
2. **Pattern 4** (ActiveRecord Events) で Event Sourcing を自前実装

### パターン選択のガイドライン
- **外部 gem に依存したくない** → Pattern 4
- **Rails Event Store の機能が必要** → Pattern 2
- **超大規模システム** → Pattern 3
- **まずは CQRS から** → Pattern 1

## 🛠️ 実装の詳細

### 共通のドメインモデル: 銀行口座

全てのパターンで同じドメインモデル（銀行口座）を実装しています：

**主要機能**:
- 口座開設
- 入金処理
- 出金処理
- 残高照会
- 取引履歴

**ドメインイベント** (Pattern 2, 3, 4):
- `AccountOpened`: 口座開設イベント
- `MoneyDeposited`: 入金イベント
- `MoneyWithdrawn`: 出金イベント

## 💡 どのパターンを選ぶべきか？

### Pattern 1 を選ぶべき場合
- Event Sourcing は不要だが、CQRS の概念を導入したい
- 既存の Rails アプリに最小限の変更で導入したい
- まずは小さく始めたい

### Pattern 2 を選ぶべき場合
- 本格的な Event Sourcing を導入したい
- Rails Event Store のエコシステムを活用したい
- 将来的な拡張性を重視
- **実務で推奨される安定した選択肢**

### Pattern 3 を選ぶべき場合
- フレームワークに依存しないドメインモデルが必要
- 超大規模システムやマイクロサービス
- Event Sourcing の理論を深く学びたい
- 学習・研究目的

### Pattern 4 を選ぶべき場合
- Event Sourcing は欲しいが Rails Event Store は使いたくない
- 外部 gem への依存を最小化したい
- ActiveRecord の知識を活かしたい
- **gem を使わずに実装したい中規模プロジェクト**

## 📖 参考資料

### 公式ドキュメント
- [Rails Event Store](https://railseventstore.org/)
- [Sequent Framework](https://sequent.io/)

### 記事・ブログ
- [Arkency Blog - CQRS Examples](https://blog.arkency.com/)
- [Building Event Sourced Applications](https://blog.arkency.com/2015/05/building-an-event-sourced-application-using-rails-event-store/)

### サンプルプロジェクト
- [BankSimplistic](https://github.com/cavalle/banksimplistic) - DDD/CQRS/ES の Ruby 実装例

## 🤝 コントリビューション

このサンプルプロジェクトへの改善提案や質問は Issue でお知らせください。

## 📄 ライセンス

MIT License

---

**注意**: これらは学習・参考用のサンプル実装です。本番環境での使用前には、十分なテストとレビューを行ってください。
