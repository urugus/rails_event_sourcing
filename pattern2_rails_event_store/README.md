# Pattern 2: Rails Event Store による Event Sourcing + CQRS

## 概要
Rails Event Store (RES) を使った Event Sourcing + CQRS の実装パターンです。
イベントを永続化し、イベントから状態を復元できる本格的な Event Sourcing を実現します。

## 特徴

### メリット
- イベントの完全な履歴が残る
- 任意の時点の状態を復元可能
- 監査ログが自動的に構築される
- Read/Write の完全な分離
- 複数の Read Model を構築可能

### デメリット
- 学習コストが高い
- イベント設計が重要
- データ移行の複雑さ
- イベントのバージョニング管理が必要

## アーキテクチャ

```
Controller
    ↓
Command Handler
    ↓
Aggregate Root (ドメインロジック)
    ↓
Domain Events → Event Store (永続化)
    ↓
Event Handlers / Projectors
    ↓
Read Models (DB)
```

## 主要コンポーネント

### 1. Domain Events (ドメインイベント)
- `AccountOpened`: 口座開設イベント
- `MoneyDeposited`: 入金イベント
- `MoneyWithdrawn`: 出金イベント

### 2. Aggregate Root (集約ルート)
- `Account`: 口座の集約ルート（イベントから状態を復元）

### 3. Command Handlers
- イベントを発行するビジネスロジック

### 4. Event Handlers / Projectors
- イベントを購読して Read Model を更新

### 5. Read Models
- クエリ用の非正規化されたデータ

## ディレクトリ構成

```
pattern2_rails_event_store/
├── README.md
├── domain/
│   ├── events/
│   │   ├── account_opened.rb
│   │   ├── money_deposited.rb
│   │   └── money_withdrawn.rb
│   └── aggregates/
│       └── account.rb
├── command_handlers/
│   ├── open_account.rb
│   ├── deposit_money.rb
│   └── withdraw_money.rb
├── event_handlers/
│   └── account_projection.rb
├── read_models/
│   └── account_balance.rb
├── queries/
│   ├── get_account_balance.rb
│   └── get_account_history.rb
├── controllers/
│   └── accounts_controller.rb
└── migrations/
    └── 001_create_read_models.rb
```

## 使用例

```ruby
# Event Store の初期化
event_store = RailsEventStore::Client.new

# 口座開設
stream_name = "Account$#{SecureRandom.uuid}"
event = AccountOpened.new(
  data: {
    account_number: "ACC001",
    owner_name: "山田太郎",
    initial_balance: 10000
  }
)
event_store.publish(event, stream_name: stream_name)

# 入金
event = MoneyDeposited.new(
  data: {
    account_number: "ACC001",
    amount: 5000,
    description: "給与振込"
  }
)
event_store.publish(event, stream_name: stream_name)

# 出金
event = MoneyWithdrawn.new(
  data: {
    account_number: "ACC001",
    amount: 2000,
    description: "ATM出金"
  }
)
event_store.publish(event, stream_name: stream_name)

# Aggregate から現在の状態を取得
account = Account.new(stream_name)
account.load(event_store)
puts account.balance # => 13000

# Read Model から残高取得（高速）
balance = AccountBalance.find_by(account_number: "ACC001")
puts balance.current_balance # => 13000
```

## Rails Event Store のセットアップ

### Gemfile
```ruby
gem 'rails_event_store'
gem 'aggregate_root'
```

### 初期化
```bash
rails generate rails_event_store:install
rails db:migrate
```

### Event Store の設定
```ruby
# config/initializers/rails_event_store.rb
Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::Client.new

  # Event Handlers の登録
  Rails.configuration.event_store.subscribe(
    AccountProjection.new,
    to: [AccountOpened, MoneyDeposited, MoneyWithdrawn]
  )
end
```

## イベント設計のポイント

### 1. イベントは過去形で命名
- ❌ `OpenAccount`
- ✅ `AccountOpened`

### 2. イベントは不変
- 一度発行したイベントは変更しない
- スキーマ変更は新しいバージョンを作成

### 3. イベントはビジネスの事実
- 技術的な実装詳細ではなく、ビジネス上の出来事を表現

### 4. イベントにはメタデータを含める
- `timestamp`, `user_id`, `correlation_id` など

## 適用シーン

- 完全な監査ログが必要
- 過去の状態を復元する必要がある
- 複雑なビジネスロジック
- 複数の Read Model が必要
- イベント駆動アーキテクチャを採用

## パフォーマンス考慮事項

### イベントの読み込み
- スナップショット機能の活用
- イベント数が多い場合は定期的にスナップショットを取る

### Read Model の更新
- 同期/非同期の選択
- バックグラウンドジョブでの処理

## 次のステップ

- イベントのバージョニング戦略
- スナップショット機能の実装
- Saga パターンによる複雑なワークフロー
- Pattern 3: フル Event Sourcing で完全なイベント駆動設計
