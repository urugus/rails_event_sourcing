# ActiveRecord版 Event Sourcing + CQRS 実装ガイド

このドキュメントでは、ActiveRecordを使った本番環境向けのEvent Sourcing + CQRS実装について説明します。

## 概要

インメモリ版の実装では学習目的で簡易的なストレージを使用していましたが、実際の本番環境では以下のようにActiveRecordを使ってPostgreSQLなどのデータベースに永続化します。

## アーキテクチャ

### データストア

1. **Event Store (events テーブル)**
   - すべてのドメインイベントを時系列で保存
   - 集約の状態はイベントを再生することで復元
   - イミュータブル（追記専用）

2. **Read Models (複数のテーブル)**
   - クエリ用に最適化されたテーブル
   - イベントから構築される
   - 必要に応じて再構築可能

## 実装の詳細

### 1. マイグレーション

#### イベントストアテーブル

```ruby
# db/migrate/20250101000001_create_event_store.rb
class CreateEventStore < ActiveRecord::Migration[7.0]
  def change
    create_table :events do |t|
      t.string :aggregate_id, null: false
      t.string :aggregate_type, null: false
      t.string :event_type, null: false
      t.jsonb :event_data, null: false, default: {}
      t.integer :version, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :events, [:aggregate_id, :aggregate_type, :version],
              unique: true, name: "idx_events_aggregate_stream"
    add_index :events, :event_type
    add_index :events, :occurred_at
  end
end
```

**重要なポイント:**
- `jsonb` 型でイベントデータを保存（PostgreSQL）
- 集約ID + バージョンの一意制約で楽観的ロックを実現
- 時系列インデックスでイベント再生を高速化

#### Read Modelテーブル

```ruby
# 注文サマリー（一覧表示用）
create_table :order_summary_read_models do |t|
  t.string :order_id, null: false
  t.string :customer_name, null: false
  t.decimal :total_amount, precision: 10, scale: 2, null: false
  t.string :status, null: false
  t.datetime :placed_at, null: false
  # ... その他のフィールド
  t.timestamps
end

# 注文詳細（詳細表示用）
create_table :order_details_read_models do |t|
  t.string :order_id, null: false
  # ... サマリーと同様のフィールド
  t.timestamps
end

# 注文商品（詳細の明細）
create_table :order_item_read_models do |t|
  t.string :order_id, null: false
  t.string :product_name, null: false
  t.integer :quantity, null: false
  t.decimal :unit_price, precision: 10, scale: 2, null: false
  t.decimal :subtotal, precision: 10, scale: 2, null: false
  t.timestamps
end
```

**重要なポイント:**
- 目的別に異なるRead Modelを作成
- 非正規化してクエリパフォーマンスを最適化
- 適切なインデックスで検索を高速化

### 2. ActiveRecord モデル

#### Event Store モデル

```ruby
# app/event_sourcing/ar_event_store.rb
module EventSourcing
  class ArEventStore
    def save_events(aggregate_id:, aggregate_type:, events:, expected_version:)
      ActiveRecord::Base.transaction do
        current_version = get_current_version(aggregate_id, aggregate_type)

        if current_version != expected_version
          raise ConcurrencyError, "Version mismatch"
        end

        events.each_with_index do |event, index|
          EventRecord.create!(
            aggregate_id: aggregate_id,
            aggregate_type: aggregate_type,
            event_type: event.class.name,
            event_data: event.to_h,
            version: expected_version + index + 1,
            occurred_at: Time.current
          )
        end
      end
    end
  end
end
```

**重要なポイント:**
- トランザクション内でバージョンチェックと保存を実行
- 楽観的ロックで並行制御
- イベント購読者への通知

#### Read Model モデル

```ruby
# app/projections/models/order_summary_read_model.rb
module Projections
  module Models
    class OrderSummaryReadModel < ApplicationRecord
      validates :order_id, presence: true, uniqueness: true
      validates :status, inclusion: { in: %w[pending confirmed shipped cancelled] }

      scope :pending, -> { where(status: "pending") }
      scope :shipped, -> { where(status: "shipped") }
      scope :recent, -> { order(placed_at: :desc) }
    end
  end
end
```

**重要なポイント:**
- 通常のActiveRecordモデルとして実装
- スコープで頻繁に使うクエリを定義
- バリデーションでデータ整合性を保証

### 3. Projector (イベントハンドラー)

```ruby
# app/projections/projectors/ar_order_summary_projector.rb
module Projections
  module Projectors
    class ArOrderSummaryProjector
      def handle_event(event, event_record)
        case event
        when Domain::Orders::Events::OrderPlaced
          handle_order_placed(event)
        when Domain::Orders::Events::OrderConfirmed
          handle_order_confirmed(event)
        # ...
        end
      end

      private

      def handle_order_placed(event)
        Models::OrderSummaryReadModel.create!(
          order_id: event.order_id,
          customer_name: event.customer_name,
          total_amount: event.total_amount,
          status: "pending",
          placed_at: event.placed_at
        )
      end

      def handle_order_confirmed(event)
        order = Models::OrderSummaryReadModel.find_by(order_id: event.order_id)
        order.update!(status: "confirmed", confirmed_at: event.confirmed_at)
      end
    end
  end
end
```

**重要なポイント:**
- イベントを受け取ってRead Modelを更新
- べき等性を考慮した実装
- 複数のRead Modelを同じイベントから構築可能

### 4. Query Service

```ruby
# app/projections/queries/ar_order_queries.rb
module Projections
  module Queries
    class ArOrderQueries
      def all_orders
        Models::OrderSummaryReadModel.recent.all
      end

      def find_order_details(order_id)
        Models::OrderDetailsReadModel
          .includes(:order_item_read_models)
          .find_by(order_id: order_id)
      end

      def shipped_orders
        Models::OrderSummaryReadModel.shipped.recent.all
      end

      def order_statistics
        {
          total_count: Models::OrderSummaryReadModel.count,
          total_revenue: Models::OrderSummaryReadModel.shipped.sum(:total_amount)
        }
      end
    end
  end
end
```

**重要なポイント:**
- Read Modelに直接アクセス
- ActiveRecordの強力なクエリ機能を活用
- N+1問題を避けるため`includes`を使用

## セットアップ

### 1. マイグレーションの実行

```bash
rails db:migrate
```

### 2. アプリケーションの初期化

```ruby
# config/initializers/event_sourcing.rb
Rails.application.config.to_prepare do
  $event_store = EventSourcing::ArEventStore.new

  # Projectorの登録
  summary_projector = Projections::Projectors::ArOrderSummaryProjector.new
  details_projector = Projections::Projectors::ArOrderDetailsProjector.new

  $event_store.subscribe do |event, event_record|
    summary_projector.handle_event(event, event_record)
    details_projector.handle_event(event, event_record)
  end

  # リポジトリとハンドラーの設定
  $order_repository = EventSourcing::Repository.new(
    event_store: $event_store,
    aggregate_class: Domain::Orders::Order
  )

  $order_command_handler = Domain::Orders::OrderCommandHandler.new(
    repository: $order_repository
  )

  $order_queries = Projections::Queries::ArOrderQueries.new
end
```

### 3. コントローラーでの使用

```ruby
# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  # コマンド（書き込み）
  def create
    command = Domain::Orders::Commands::PlaceOrder.new(
      order_id: SecureRandom.uuid,
      customer_name: params[:customer_name],
      total_amount: params[:total_amount]
    )

    $order_command_handler.handle_place_order(command)

    head :created
  end

  # クエリ（読み取り）
  def index
    @orders = $order_queries.all_orders
    render json: @orders
  end

  def show
    @order = $order_queries.find_order_details(params[:id])
    render json: @order
  end
end
```

## 本番環境での考慮事項

### 1. イベントの再生とRead Modelの再構築

Read Modelが壊れた場合や、新しいRead Modelを追加する場合、イベントを再生して再構築できます。

```ruby
# lib/tasks/event_sourcing.rake
namespace :event_sourcing do
  desc "Rebuild all read models from events"
  task rebuild_read_models: :environment do
    # Read Modelをクリア
    Projections::Models::OrderSummaryReadModel.delete_all
    Projections::Models::OrderDetailsReadModel.delete_all
    Projections::Models::OrderItemReadModel.delete_all

    # すべてのイベントを再生
    EventSourcing::ArEventStore::EventRecord.order(:occurred_at).find_each do |record|
      event_class = record.event_type.constantize
      event = event_class.from_h(record.event_data)

      # Projectorでイベントを処理
      summary_projector.handle_event(event, record)
      details_projector.handle_event(event, record)
    end

    puts "Read models rebuilt successfully"
  end
end
```

### 2. スナップショット

多数のイベントを持つ集約の復元を高速化するために、定期的にスナップショットを保存します。

```ruby
# app/event_sourcing/snapshot_store.rb
module EventSourcing
  class SnapshotStore
    def save_snapshot(aggregate_id:, aggregate_type:, version:, state:)
      Snapshot.create!(
        aggregate_id: aggregate_id,
        aggregate_type: aggregate_type,
        version: version,
        state: state
      )
    end

    def get_latest_snapshot(aggregate_id:, aggregate_type:)
      Snapshot
        .where(aggregate_id: aggregate_id, aggregate_type: aggregate_type)
        .order(version: :desc)
        .first
    end
  end
end
```

### 3. 非同期イベント処理

大量のイベントを処理する場合、Projectorを非同期で実行します。

```ruby
# app/jobs/event_projection_job.rb
class EventProjectionJob < ApplicationJob
  queue_as :default

  def perform(event_type, event_data, event_record)
    event_class = event_type.constantize
    event = event_class.from_h(event_data)

    # Projectorで処理
    summary_projector.handle_event(event, event_record)
    details_projector.handle_event(event, event_record)
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

### 4. イベントのバージョニング

イベントスキーマが変更された場合の対応：

```ruby
# app/domain/orders/events/order_placed_v2.rb
module Domain
  module Orders
    module Events
      class OrderPlacedV2 < EventSourcing::Event
        # 新しいフィールドを追加
        def shipping_address
          attributes[:shipping_address]
        end

        # 古いバージョンから変換
        def self.from_v1(v1_event)
          new(
            order_id: v1_event.order_id,
            customer_name: v1_event.customer_name,
            total_amount: v1_event.total_amount,
            placed_at: v1_event.placed_at,
            shipping_address: nil # デフォルト値
          )
        end
      end
    end
  end
end
```

## パフォーマンス最適化

### 1. インデックス戦略

```ruby
# 頻繁に使うクエリに対してインデックスを追加
add_index :order_summary_read_models, [:status, :placed_at]
add_index :order_summary_read_models, [:customer_name, :status]
```

### 2. マテリアライズドビュー

複雑な集計クエリにはマテリアライズドビューを使用：

```sql
CREATE MATERIALIZED VIEW order_statistics AS
SELECT
  status,
  COUNT(*) as count,
  SUM(total_amount) as total_revenue,
  AVG(total_amount) as average_order_value
FROM order_summary_read_models
GROUP BY status;

CREATE INDEX idx_order_statistics_status ON order_statistics(status);
```

### 3. キャッシュ

頻繁にアクセスされるRead Modelをキャッシュ：

```ruby
class ArOrderQueries
  def find_order_summary(order_id)
    Rails.cache.fetch("order_summary:#{order_id}", expires_in: 5.minutes) do
      Models::OrderSummaryReadModel.find_by(order_id: order_id)
    end
  end
end
```

## まとめ

ActiveRecord版の実装により：

- **永続化**: データベースに安全に保存
- **スケーラビリティ**: Read/Writeの独立したスケーリング
- **パフォーマンス**: インデックスと最適化されたクエリ
- **信頼性**: トランザクションと制約による整合性
- **運用性**: Railsの標準ツールで管理可能

インメモリ版で学んだ概念を、そのままActiveRecordに適用できます。
