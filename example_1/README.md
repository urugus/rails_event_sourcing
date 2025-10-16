# Rails Event Sourcing + CQRS 完全実装例

RailsでEvent SourcingとCQRSパターンを実装した本番環境対応のコード例です。

## 特徴

- **ActiveRecordベース**: PostgreSQLを使った本番環境対応の実装
- **gemなし**: 外部ライブラリに依存しない純粋なRails実装
- **メタプログラミングなし**: 明示的で理解しやすいコード
- **完全なCQRS**: 書き込みと読み取りの完全な分離
- **Event Sourcing**: すべての状態変更をイベントとして永続化

## プロジェクト構造

```
example_1/
├── app/
│   ├── controllers/
│   │   └── orders_controller.rb          # REST API エンドポイント
│   │
│   ├── domain/                            # ドメイン層（書き込み側）
│   │   └── orders/
│   │       ├── order.rb                   # 注文集約
│   │       ├── order_command_handler.rb   # コマンドハンドラー
│   │       ├── events/                    # ドメインイベント
│   │       │   ├── order_placed.rb
│   │       │   ├── order_item_added.rb
│   │       │   ├── order_confirmed.rb
│   │       │   ├── order_cancelled.rb
│   │       │   └── order_shipped.rb
│   │       └── commands/                  # コマンド
│   │           ├── place_order.rb
│   │           ├── add_order_item.rb
│   │           ├── confirm_order.rb
│   │           ├── cancel_order.rb
│   │           └── ship_order.rb
│   │
│   ├── event_sourcing/                    # Event Sourcingインフラ
│   │   ├── event.rb                       # イベント基底クラス
│   │   ├── ar_event_store.rb              # ActiveRecord Event Store
│   │   ├── aggregate_root.rb              # 集約ルート基底クラス
│   │   └── repository.rb                  # 集約リポジトリ
│   │
│   └── projections/                       # 読み取り側（CQRS）
│       ├── models/                        # ActiveRecord Read Models
│       │   ├── order_summary_read_model.rb
│       │   ├── order_details_read_model.rb
│       │   └── order_item_read_model.rb
│       ├── projectors/                    # イベントハンドラー
│       │   ├── ar_order_summary_projector.rb
│       │   └── ar_order_details_projector.rb
│       └── queries/                       # クエリサービス
│           └── ar_order_queries.rb
│
├── config/
│   ├── initializers/
│   │   └── event_sourcing.rb              # Event Sourcing初期化設定
│   └── routes.rb                          # ルーティング設定
│
├── db/
│   └── migrate/                           # マイグレーション
│       ├── 20250101000001_create_event_store.rb
│       ├── 20250101000002_create_order_summary_read_models.rb
│       ├── 20250101000003_create_order_details_read_models.rb
│       └── 20250101000004_create_order_item_read_models.rb
│
└── example_usage.rb                       # 動作確認用スクリプト（インメモリ版）
```

## セットアップ

### 1. データベースのマイグレーション

```bash
rails db:migrate
```

これにより以下のテーブルが作成されます：
- `events` - イベントストア（追記専用）
- `order_summary_read_models` - 注文サマリー（一覧表示用）
- `order_details_read_models` - 注文詳細
- `order_item_read_models` - 注文商品

### 2. Railsサーバーの起動

```bash
rails server
```

## API エンドポイント

### コマンド（書き込み）

#### 注文を作成
```bash
POST /orders
Content-Type: application/json

{
  "customer_name": "山田太郎",
  "total_amount": 10000
}

# レスポンス
{
  "order_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### 商品を追加
```bash
POST /orders/:order_id/add_item
Content-Type: application/json

{
  "product_name": "ノートPC",
  "quantity": 1,
  "unit_price": 80000
}
```

#### 注文を確定
```bash
POST /orders/:order_id/confirm
```

#### 注文をキャンセル
```bash
POST /orders/:order_id/cancel
Content-Type: application/json

{
  "reason": "顧客都合によるキャンセル"
}
```

#### 注文を発送
```bash
POST /orders/:order_id/ship
Content-Type: application/json

{
  "tracking_number": "TRACK-12345678"
}
```

### クエリ（読み取り）

#### すべての注文を取得
```bash
GET /orders
```

#### 注文詳細を取得
```bash
GET /orders/:order_id
```

#### ステータスで注文を検索
```bash
GET /orders/status/shipped
GET /orders/status/pending
GET /orders/status/confirmed
GET /orders/status/cancelled
```

#### 統計情報を取得
```bash
GET /orders/statistics

# レスポンス
{
  "total_count": 150,
  "pending_count": 10,
  "confirmed_count": 30,
  "shipped_count": 100,
  "cancelled_count": 10,
  "total_revenue": 5000000.00
}
```

## アーキテクチャの詳細

### Event Sourcing

すべての状態変更がイベントとして`events`テーブルに保存されます。

```ruby
# イベントの例
{
  aggregate_id: "ORDER-001",
  aggregate_type: "Domain::Orders::Order",
  event_type: "Domain::Orders::Events::OrderPlaced",
  event_data: {
    order_id: "ORDER-001",
    customer_name: "山田太郎",
    total_amount: 10000,
    placed_at: "2025-01-01 10:00:00"
  },
  version: 1,
  occurred_at: "2025-01-01 10:00:00"
}
```

集約の現在の状態は、イベントを時系列で再生することで復元できます。

### CQRS (Command Query Responsibility Segregation)

#### 書き込み側（コマンド）

1. クライアントがコマンドを送信
2. コマンドハンドラーがコマンドを受信
3. 集約がビジネスロジックを実行
4. ドメインイベントが生成される
5. イベントがEvent Storeに保存される

```ruby
# コマンド実行の例
command = Domain::Orders::Commands::PlaceOrder.new(
  order_id: "ORDER-001",
  customer_name: "山田太郎",
  total_amount: 10000
)

$order_command_handler.handle_place_order(command)
```

#### 読み取り側（クエリ）

1. イベントがProjectorに通知される
2. Projectorがイベントを処理してRead Modelを更新
3. クライアントはRead Modelから直接データを取得

```ruby
# クエリ実行の例
orders = $order_queries.all_orders
order_details = $order_queries.find_order_details("ORDER-001")
```

### データフロー

```
┌─────────┐
│ Client  │
└────┬────┘
     │
     ├── POST /orders (コマンド)
     │   ↓
     │   ┌────────────────┐
     │   │ Controller     │
     │   └───────┬────────┘
     │           ↓
     │   ┌────────────────────┐
     │   │ Command Handler    │
     │   └───────┬────────────┘
     │           ↓
     │   ┌────────────────────┐
     │   │ Order Aggregate    │
     │   │ (ビジネスロジック)  │
     │   └───────┬────────────┘
     │           ↓
     │   ┌────────────────────┐
     │   │ Event Store (DB)   │
     │   └───────┬────────────┘
     │           ↓
     │   ┌────────────────────┐
     │   │ Projector          │
     │   └───────┬────────────┘
     │           ↓
     │   ┌────────────────────┐
     │   │ Read Models (DB)   │
     │   └────────────────────┘
     │
     └── GET /orders (クエリ)
         ↓
         ┌────────────────┐
         │ Controller     │
         └───────┬────────┘
                 ↓
         ┌────────────────────┐
         │ Query Service      │
         └───────┬────────────┘
                 ↓
         ┌────────────────────┐
         │ Read Models (DB)   │
         └────────────────────┘
```

## Event SourcingとCQRSの利点

### Event Sourcingの利点

1. **完全な監査ログ**: すべての変更が記録される
2. **時間旅行**: 過去の任意の時点の状態を復元可能
3. **イベント駆動**: イベントを他のサービスに配信可能
4. **柔軟なRead Model**: 同じイベントから複数のRead Modelを構築
5. **デバッグが容易**: イベントを再生して問題を再現

### CQRSの利点

1. **読み取りの最適化**: クエリ専用のデータ構造で高速化
2. **スケーラビリティ**: 読み取りと書き込みを独立にスケール
3. **複雑性の分離**: ビジネスロジックとクエリロジックを分離
4. **柔軟性**: 異なるストレージ技術を使用可能

## 本番環境での運用

### Read Modelの再構築

Read Modelが壊れた場合や、新しいRead Modelを追加する場合：

```ruby
# lib/tasks/event_sourcing.rake
namespace :event_sourcing do
  desc "Rebuild read models from events"
  task rebuild_read_models: :environment do
    # Read Modelをクリア
    Projections::Models::OrderSummaryReadModel.delete_all
    Projections::Models::OrderDetailsReadModel.delete_all
    Projections::Models::OrderItemReadModel.delete_all

    # すべてのイベントを再生
    EventSourcing::ArEventStore::EventRecord.order(:occurred_at).find_each do |record|
      event_class = record.event_type.constantize
      event = event_class.from_h(record.event_data)

      # Projectorで処理
      $summary_projector.handle_event(event, record)
      $details_projector.handle_event(event, record)
    end

    puts "Read models rebuilt successfully"
  end
end
```

実行:
```bash
rails event_sourcing:rebuild_read_models
```

### 非同期イベント処理

大量のイベントを処理する場合、Projectorsを非同期で実行：

```ruby
class EventProjectionJob < ApplicationJob
  queue_as :default

  def perform(event_type, event_data, event_record)
    event_class = event_type.constantize
    event = event_class.from_h(event_data)

    $summary_projector.handle_event(event, event_record)
    $details_projector.handle_event(event, event_record)
  end
end

# Event Storeで購読
$event_store.subscribe do |event, event_record|
  EventProjectionJob.perform_later(
    event.class.name,
    event.to_h,
    event_record
  )
end
```

## テスト

### ドメイン層のテスト

```ruby
RSpec.describe Domain::Orders::Order do
  it "creates a new order" do
    order = Order.place(
      order_id: "ORDER-001",
      customer_name: "山田太郎",
      total_amount: 10000
    )

    expect(order.customer_name).to eq("山田太郎")
    expect(order.status).to eq("pending")
    expect(order.uncommitted_events.size).to eq(1)
  end
end
```

### イベントハンドラーのテスト

```ruby
RSpec.describe Projections::Projectors::ArOrderSummaryProjector do
  it "creates read model on OrderPlaced event" do
    event = Domain::Orders::Events::OrderPlaced.new(
      order_id: "ORDER-001",
      customer_name: "山田太郎",
      total_amount: 10000,
      placed_at: Time.current
    )

    projector.handle_event(event, {})

    order = OrderSummaryReadModel.find_by(order_id: "ORDER-001")
    expect(order.customer_name).to eq("山田太郎")
  end
end
```

## まとめ

この実装により：

- ✅ RailsでEvent Sourcingを実践的に適用
- ✅ CQRSパターンで読み書きを分離
- ✅ ActiveRecordで本番環境対応
- ✅ gemなしのシンプルな実装
- ✅ 完全な監査ログとイベント履歴
- ✅ スケーラブルなアーキテクチャ

Event SourcingとCQRSの本質を理解し、Railsアプリケーションに適用する方法を学べます。
