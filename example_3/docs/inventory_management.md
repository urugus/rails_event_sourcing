# 在庫管理の詳細設計

## 概要

このドキュメントでは、example_3で実装した在庫管理機能の設計と実装の詳細を説明します。

## 設計の背景

### 解決したい課題

**質問**: Event SourcingとCQRSを使用した場合、注文時に商品を操作する際、在庫を増減させる必要がある。このとき、クエリ側（Read Model）の反映が遅いと実在庫と乖離が生まれる可能性があるのではないか？

### 解決策

**在庫予約の2段階プロセス + イベントストアベースの状態再構築**

1. **コマンド側はイベントストアのみを信頼**
   - 在庫チェック・予約時は、必ずInventoryRepositoryを通じてイベントストアから集約を再構築
   - Read Modelには一切依存しない

2. **2段階の予約プロセス**
   - 注文時: 在庫を「予約」（仮確保）
   - 注文確定時: 予約を「確定」（在庫から減算）
   - 注文キャンセル時: 予約を「解放」

3. **予約タイムアウト**
   - 予約には有効期限（デフォルト15分）
   - 期限切れ予約は自動的に解放

## アーキテクチャ

### ドメインモデル

#### Inventory 集約

**責務**:
- 商品ごとの在庫管理
- 在庫の追加・予約・確定・キャンセル・期限切れ処理
- ビジネスルールの検証（在庫不足チェック）

**状態**:
```ruby
class Inventory
  attr_reader :product_id, :total_quantity, :reservations

  # total_quantity: 総在庫数
  # reservations: 予約のリスト [InventoryItem, ...]
  # available_quantity = total_quantity - reservations.sum(&:quantity)
end
```

**イベント**:
1. `StockAdded` - 在庫追加
2. `StockReserved` - 在庫予約
3. `ReservationConfirmed` - 予約確定（在庫から減算）
4. `ReservationCancelled` - 予約キャンセル（予約を削除）
5. `ReservationExpired` - 予約期限切れ（予約を削除）

#### Order 集約（拡張）

**変更点**:
- `OrderItem` に `product_id` と `reservation_id` を追加
- `ItemAdded` イベントに `product_id` と `reservation_id` を追加

### Process Manager（Saga）パターン

#### OrderInventorySaga

複数の集約（Order と Inventory）を調整するための Process Manager です。

**責務**:
- Order と Inventory の整合性を保証
- エラー時の補償トランザクション

**主要なフロー**:

##### 1. 商品追加フロー

```
add_item_with_reservation(order_id, product_id, product_name, quantity, unit_price)
├─ ステップ1: Inventory.reserve_stock()
│  ├─ InventoryRepository.load(product_id)
│  │  └→ イベントストアから再構築（最新の在庫状態）
│  ├─ 在庫チェック（available_quantity >= quantity）
│  ├─ OK: StockReserved イベント発行
│  └─ NG: DomainError（在庫不足）
│
├─ ステップ2: Order.add_item(reservation_id付き)
│  ├─ ItemAdded イベント発行
│  └─ NG: 補償トランザクション
│     └→ Inventory.cancel_reservation() で予約をロールバック
│
└─ 完了
```

##### 2. 注文確定フロー

```
confirm_order_with_inventory(order_id, item_reservations)
├─ ステップ1: Order.confirm()
│  └─ OrderConfirmed イベント発行
│
├─ ステップ2: すべての予約を確定
│  └─ 各商品について:
│     └─ Inventory.confirm_reservation(reservation_id)
│        ├─ 予約を検索
│        ├─ total_quantity -= reservation.quantity
│        ├─ 予約を削除
│        └─ ReservationConfirmed イベント発行
│
└─ 完了
```

##### 3. 注文キャンセルフロー

```
cancel_order_with_inventory(order_id, reason, item_reservations)
├─ ステップ1: Order.cancel(reason)
│  └─ OrderCancelled イベント発行
│
├─ ステップ2: すべての予約をキャンセル
│  └─ 各商品について:
│     └─ Inventory.cancel_reservation(reservation_id)
│        ├─ 予約を削除
│        └─ ReservationCancelled イベント発行
│
└─ 完了
```

### Read Model

#### InventoryReadModel

**目的**:
- 在庫の表示・検索用
- パフォーマンスの最適化

**スキーマ**:
```ruby
create_table :inventory_read_models do |t|
  t.string :product_id, null: false, index: { unique: true }
  t.integer :total_quantity, null: false, default: 0
  t.integer :reserved_quantity, null: false, default: 0
  t.integer :available_quantity, null: false, default: 0
  t.jsonb :reservations, default: []
  t.timestamps
end
```

**重要な注意点**:
- **ビジネスロジックには使用しない**
- あくまで表示・検索用
- コマンド側は常にイベントストアから状態を再構築

### イベントフロー

```
┌─────────────────────────────────────────────────────────┐
│                  コマンド実行                            │
│  OrderInventorySaga.add_item_with_reservation()         │
└───────────────────┬─────────────────────────────────────┘
                    │
        ┌───────────▼───────────┐
        │ Inventory集約         │
        │ (イベントストアから   │
        │  再構築して最新状態)  │
        │ reserve_stock()       │
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │ StockReserved イベント│
        │ をイベントストアに保存│
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │ Order集約             │
        │ add_item()            │
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │ ItemAdded イベント    │
        │ をイベントストアに保存│
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │ ProjectionManager     │
        │ (非同期処理)          │
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │ InventoryProjector    │
        │ + OrderProjector      │
        └───────────┬───────────┘
                    │
        ┌───────────▼───────────┐
        │ Read Model 更新       │
        │ (InventoryReadModel)  │
        │ (OrderReadModel)      │
        └───────────────────────┘
```

## 整合性の保証

### なぜRead Modelの遅延が問題にならないのか

1. **コマンド側の判断はイベントストアベース**
   ```ruby
   # InventoryRepository.load()
   def load(product_id)
     event_records = event_store.load_events(
       aggregate_id: product_id,
       aggregate_type: "Inventory"
     )
     events = event_records.map { |record| EventMappings.deserialize(record) }

     inventory = Inventory.new(product_id: product_id)
     inventory.load_from_history(events)  # <- イベントを再生して最新状態を復元
     inventory
   end
   ```

2. **Read Modelは参照のみ**
   - InventoryReadModelは表示・検索のみに使用
   - ビジネスロジック（在庫チェック）には使用しない

3. **トランザクション内でイベント保存**
   ```ruby
   EventRecord.transaction do
     # イベントを保存
     # 楽観的ロックで並行制御
   end
   ```

### 並行制御

**楽観的ロック**を使用して、同時に複数のリクエストが来た場合も整合性を保証:

```ruby
# EventStore
def append_events(aggregate_id:, aggregate_type:, events:, expected_version:)
  EventRecord.transaction do
    events.each_with_index do |event_data, index|
      EventRecord.create!(
        aggregate_id: aggregate_id,
        aggregate_type: aggregate_type,
        event_type: event_data[:event_type],
        data: event_data[:data],
        version: expected_version + index + 1  # <- バージョンチェック
      )
    end
  end
rescue ActiveRecord::RecordNotUnique
  raise ConcurrentWriteError
end
```

## 予約タイムアウト

### 設計

**目的**:
- 未確定の予約による在庫の長期占有を防ぐ
- カートに入れたまま放置された商品の在庫を解放

**仕組み**:
1. 予約作成時に有効期限を設定（デフォルト15分）
2. バックグラウンドジョブで期限切れ予約を検出
3. 期限切れ予約に対して `expire_reservation` コマンドを実行
4. `ReservationExpired` イベントを発行

### 実装

```ruby
# Rakeタスク（lib/tasks/inventory.rake）
task expire_reservations: :environment do
  query_service = InventoryQueryService.new
  command_handler = Inventory::Container.inventory_command_handler

  expired = query_service.find_expired_reservations

  expired.each do |reservation|
    command_handler.expire_reservation(
      product_id: reservation[:product_id],
      reservation_id: reservation[:reservation_id]
    )
  end

  # プロジェクションを更新
  Projections::Container.projection_manager.call
end
```

**定期実行**:
- cron, Sidekiq-cron, whenever などで定期的に実行
- 例: 1分ごとに実行

## API エンドポイント

### 在庫管理

```
POST   /inventory/:product_id/add_stock  # 在庫追加
GET    /inventory/:product_id             # 在庫照会
GET    /inventory                         # 在庫一覧
```

### 注文管理（Process Manager統合）

```
POST   /orders                            # 注文作成
POST   /orders/:id/add_item               # 商品追加（在庫予約を含む）
POST   /orders/:id/confirm                # 注文確定（予約確定を含む）
POST   /orders/:id/cancel                 # 注文キャンセル（予約解放を含む）
```

## テストシナリオ

### シナリオ1: 正常な注文フロー

1. 在庫を100個追加
2. 注文を作成
3. 商品を2個追加
   - 在庫予約: 98個利用可能、2個予約中
4. 注文を確定
   - 在庫確定: 98個総在庫、0個予約中、98個利用可能
5. 検証: 総在庫が98個に減少

### シナリオ2: 在庫不足エラー

1. 在庫を1個追加
2. 注文を作成
3. 商品を2個追加（失敗）
   - エラー: "insufficient stock: available=1, requested=2"
4. 検証: 在庫は変更されていない

### シナリオ3: 注文キャンセル

1. 在庫を100個追加
2. 注文を作成
3. 商品を2個追加
4. 注文をキャンセル
   - 予約解放: 100個利用可能、0個予約中
5. 検証: 在庫は元に戻る

### シナリオ4: 予約タイムアウト

1. 在庫を100個追加
2. 注文を作成
3. 商品を2個追加（有効期限1分）
4. 1分以上待機
5. 期限切れタスクを実行
   - 予約期限切れ: 100個利用可能、0個予約中
6. 検証: 在庫は元に戻る

## まとめ

### 主要な設計判断

1. **イベントストアをシングルソースオブトゥルース（唯一の真実の源）とする**
   - コマンド側は常にイベントストアから状態を再構築
   - Read Modelは表示・検索のみに使用

2. **2段階の予約プロセス**
   - 予約 → 確定/キャンセルの明確なライフサイクル
   - 予約タイムアウトで在庫の長期占有を防ぐ

3. **Process Manager（Saga）による複数集約の調整**
   - Order と Inventory の整合性を保証
   - 補償トランザクションでエラー時のロールバック

4. **楽観的ロックによる並行制御**
   - イベントのバージョン管理で競合を検出
   - 競合時はリトライ

### 利点

✅ **厳格な整合性**: イベントストアベースの状態管理
✅ **柔軟性**: 複数のRead Modelを構築可能
✅ **監査ログ**: すべての在庫変動が記録される
✅ **デバッグ性**: イベントを再生して問題を再現
✅ **スケーラビリティ**: 読み書きを独立にスケール

### トレードオフ

⚠ **複雑性**: 通常のCRUDより実装が複雑
⚠ **Eventual Consistency**: Read Modelの更新は非同期
⚠ **学習コスト**: Event SourcingとCQRSの理解が必要

しかし、在庫管理のような厳格な整合性が必要なドメインでは、
この複雑性は十分に価値があります。
