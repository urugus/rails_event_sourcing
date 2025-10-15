# 02. Aggregate Root Pattern

## 概要

Aggregate Rootは、ドメイン駆動設計（DDD）の中核概念です。Event Sourcingでは、Aggregateの状態変更をイベントとして記録し、イベントを再生することで状態を復元します。

## 主要概念

### Aggregate Root
- ビジネスロジックをカプセル化するドメインオブジェクト
- 不変条件（Invariant）を保護
- 外部からは **コマンド** を通じてのみ操作可能
- 状態変更は **イベント** として記録

### イベント駆動の状態管理
1. コマンドを受け取る
2. ビジネスルールを検証
3. イベントを生成（`apply`）
4. イベントハンドラで状態を更新（`on`）

### イベントの再生（Event Replay）
- Aggregateの現在の状態は、過去のすべてのイベントを順番に適用することで復元
- データベースには状態を保存せず、イベントのみを保存

## 実装パターン

```ruby
class Order
  include AggregateRoot

  def initialize
    @state = :draft
    @items = []
    @total = 0
  end

  # コマンド: 注文を作成
  def create(customer_id:, items:)
    raise 'Order already created' if @state != :draft

    apply OrderCreated.new(
      customer_id: customer_id,
      items: items,
      total: calculate_total(items)
    )
  end

  # イベントハンドラ: OrderCreatedの適用
  on OrderCreated do |event|
    @state = :created
    @customer_id = event.customer_id
    @items = event.items
    @total = event.total
  end
end
```

## ファイル構成

- `aggregate_root.rb`: AggregateRoot基底モジュール
- `repository.rb`: Aggregateの永続化・復元を担当
- `order.rb`: 注文Aggregateの実装例
- `order_events.rb`: 注文に関するイベント定義
- `example.rb`: 使用例
- `aggregate_root_spec.rb`: テストコード

## 重要な原則

### 1. イベントソーシング原則
- 状態は直接変更しない
- すべての変更はイベントを通じて行う
- イベントは不変

### 2. ビジネスルール保護
```ruby
def submit
  raise 'Cannot submit empty order' if @items.empty?
  raise 'Order already submitted' if @state == :submitted

  apply OrderSubmitted.new
end
```

### 3. イベント駆動状態遷移
```
[draft] --create--> [created] --submit--> [submitted] --ship--> [shipped]
                              \--cancel--> [cancelled]
```

## 使用例

```ruby
# 新しい注文を作成
order = Order.new
order.create(
  customer_id: 1,
  items: [{ product_id: 101, quantity: 2, price: 1000 }]
)

# リポジトリに保存
repository = Repository.new(event_store)
repository.save(order, stream_id: 'Order-123')

# 復元
order = repository.load(Order, stream_id: 'Order-123')
order.submit
repository.save(order, stream_id: 'Order-123')
```

## 学べること

- Aggregate Rootパターンの実装
- コマンドとイベントの分離
- イベントソーシングによる状態管理
- ビジネスルールの保護
- イベントリプレイによる状態復元
