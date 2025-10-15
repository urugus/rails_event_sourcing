# Pattern 4: ActiveRecord による Event Sourcing + CQRS

## 概要
Rails Event Store を使わず、ActiveRecord でイベントを永続化する Event Sourcing + CQRS の実装パターンです。
Rails の標準機能のみで Event Sourcing を実現し、外部 gem への依存を最小化します。

## 特徴

### メリット
- ✅ Rails Event Store gem が不要
- ✅ ActiveRecord の機能をフル活用
- ✅ イベントの完全な履歴が残る
- ✅ 既存の Rails 知識で実装可能
- ✅ シンプルな構成で保守しやすい
- ✅ データベースマイグレーションで管理

### デメリット
- ⚠️ Rails Event Store の高度な機能は使えない
- ⚠️ イベントストアの実装を自前で管理
- ⚠️ スケーラビリティは中程度

## アーキテクチャ

```
Controller
    ↓
Command Handler
    ↓
Aggregate Root (ドメインロジック)
    ↓
Domain Events → Event Store (ActiveRecord)
    ↓
Event Handlers / Projectors
    ↓
Read Models (ActiveRecord)
```

## 主要コンポーネント

### 1. Event Store (ActiveRecord)
- `DomainEventModel`: イベントを保存するテーブル
- `EventStore::ActiveRecordEventStore`: Event Store の実装

### 2. Domain Events (Pure Ruby)
- `BaseEvent`: イベント基底クラス
- `AccountOpened`: 口座開設イベント
- `MoneyDeposited`: 入金イベント
- `MoneyWithdrawn`: 出金イベント

### 3. Aggregate Root
- `Domain::Aggregates::Account`: 口座の集約ルート

### 4. Command Handlers
- イベントを発行するビジネスロジック

### 5. Event Handlers / Projectors
- `AccountProjection`: Read Model を更新

### 6. Read Models (ActiveRecord)
- `AccountBalance`: 口座残高（クエリ用）
- `AccountTransaction`: 取引履歴（非正規化）

## ディレクトリ構成

```
pattern4_activerecord_events/
├── README.md
├── event_store/
│   ├── domain_event_model.rb      # イベントテーブル
│   └── event_store.rb             # Event Store実装
├── domain/
│   ├── events/
│   │   ├── base_event.rb
│   │   ├── account_opened.rb
│   │   ├── money_deposited.rb
│   │   └── money_withdrawn.rb
│   ├── aggregates/
│   │   └── account.rb
│   └── repository.rb
├── command_handlers/
│   ├── open_account.rb
│   ├── deposit_money.rb
│   └── withdraw_money.rb
├── event_handlers/
│   └── account_projection.rb
├── read_models/
│   ├── account_balance.rb
│   └── account_transaction.rb
├── queries/
│   ├── get_account_balance.rb
│   └── get_transaction_history.rb
├── controllers/
│   └── accounts_controller.rb
└── migrations/
    └── 001_create_events.rb
```

## データベーススキーマ

### domain_events テーブル（イベントストア）
```ruby
create_table :domain_events do |t|
  t.string :event_id, null: false        # UUID
  t.string :event_type, null: false      # イベントタイプ
  t.string :stream_name, null: false     # ストリーム名
  t.integer :stream_version, null: false # バージョン
  t.string :aggregate_id, null: false    # Aggregate ID
  t.json :data, null: false              # イベントデータ
  t.json :metadata                       # メタデータ
  t.datetime :occurred_at, null: false   # 発生日時
  t.timestamps
end
```

### account_balances テーブル（Read Model）
```ruby
create_table :account_balances do |t|
  t.string :account_number              # 口座番号
  t.string :owner_name                  # 所有者名
  t.decimal :current_balance            # 現在残高
  t.integer :version                    # バージョン
  t.datetime :last_transaction_at       # 最終取引日時
  t.timestamps
end
```

## 使用例

### セットアップ

```ruby
# Event Store の初期化
event_store = EventStore::ActiveRecordEventStore.new
repository = Domain::Repository.new(event_store)

# Event Handlers の登録
event_store.subscribe(EventHandlers::AccountProjection.new)
```

### 口座開設

```ruby
handler = CommandHandlers::OpenAccount.new(repository)
result = handler.call(
  account_number: "ACC001",
  owner_name: "山田太郎",
  initial_balance: 10000
)
# => { success: true, account_number: "ACC001" }
```

### 入金

```ruby
handler = CommandHandlers::DepositMoney.new(repository)
result = handler.call(
  account_number: "ACC001",
  amount: 5000,
  description: "給与振込"
)
# => { success: true, account_number: "ACC001", amount: 5000 }
```

### 出金

```ruby
handler = CommandHandlers::WithdrawMoney.new(repository)
result = handler.call(
  account_number: "ACC001",
  amount: 2000,
  description: "ATM出金"
)
# => { success: true, account_number: "ACC001", amount: 2000 }
```

### 残高照会（Read Model）

```ruby
query = Queries::GetAccountBalance.new
result = query.call(account_number: "ACC001")
# => {
#   success: true,
#   account_number: "ACC001",
#   owner_name: "山田太郎",
#   balance: 13000,
#   version: 3,
#   last_transaction_at: 2025-01-15 10:30:00
# }
```

### イベント履歴の取得

```ruby
events = DomainEventModel.for_stream("Account-ACC001")
events.each do |event|
  puts "#{event.event_type}: #{event.data}"
end
```

### Aggregate から現在の状態を復元

```ruby
account = repository.load("ACC001", Domain::Aggregates::Account)
puts account.balance # => 13000
puts account.owner_name # => "山田太郎"
```

## Rails アプリケーションへの統合

### 1. マイグレーション実行

```bash
rails db:migrate
```

### 2. Initializer で Event Store をセットアップ

```ruby
# config/initializers/event_store.rb
Rails.application.config.to_prepare do
  event_store = EventStore::ActiveRecordEventStore.new

  # Event Handlers の登録
  event_store.subscribe(EventHandlers::AccountProjection.new)

  Rails.application.config.event_store = event_store
  Rails.application.config.repository = Domain::Repository.new(event_store)
end
```

### 3. Controller で使用

```ruby
class AccountsController < ApplicationController
  def create
    result = CommandHandlers::OpenAccount.new(repository).call(
      account_number: params[:account_number],
      owner_name: params[:owner_name],
      initial_balance: params[:initial_balance]&.to_f || 0
    )

    render json: result
  end

  private

  def repository
    Rails.application.config.repository
  end
end
```

## Pattern 2 (Rails Event Store) との比較

| 項目 | Pattern 4 (ActiveRecord) | Pattern 2 (RES) |
|-----|--------------------------|-----------------|
| **外部 gem** | 不要 | 必要 (rails_event_store) |
| **学習コスト** | 低（Rails の知識のみ） | 中（RES の API 学習） |
| **イベント保存** | ActiveRecord | RES の EventStore |
| **スナップショット** | 自前実装 | RES が提供 |
| **イベントバージョニング** | 自前実装 | RES が提供 |
| **パフォーマンス** | 中 | 高 |
| **カスタマイズ性** | 高 | 中 |
| **保守性** | 自前管理 | gem 依存 |

## 実装のポイント

### 1. イベントの一意性保証

```ruby
validates :event_id, presence: true, uniqueness: true
```

### 2. ストリームバージョンの楽観的ロック

```ruby
add_index :domain_events, [:stream_name, :stream_version], unique: true
```

### 3. イベント購読の仕組み

```ruby
def subscribe(handler, event_types: nil)
  @subscribers << { handler: handler, event_types: event_types }
end
```

### 4. JSON カラムでイベントデータを保存

```ruby
t.json :data, null: false
t.json :metadata
```

## 適用シーン

- Rails Event Store を使いたくない
- 外部 gem への依存を減らしたい
- シンプルな Event Sourcing を実現したい
- ActiveRecord の知識を活かしたい
- 中規模のアプリケーション

## パフォーマンス最適化

### インデックスの追加

```ruby
add_index :domain_events, :aggregate_id
add_index :domain_events, :event_type
add_index :domain_events, :occurred_at
```

### スナップショット機能の実装（将来）

長いイベントストリームの場合、定期的にスナップショットを保存して読み込みを高速化。

### 非同期イベント処理

ActiveJob を使ってイベントハンドラを非同期実行。

```ruby
class AsyncEventHandler
  def call(event)
    ProcessEventJob.perform_later(event.to_h)
  end
end
```

## 次のステップ

- イベントのバージョニング戦略
- スナップショット機能の追加
- Saga パターンによる複雑なワークフロー
- マルチテナント対応
- イベントリプレイ機能

## まとめ

Pattern 4 は、Rails の標準機能のみで Event Sourcing を実現したい場合に最適です。
Rails Event Store の高度な機能は必要ないが、イベント履歴と CQRS のメリットを享受したい中規模プロジェクトに向いています。
