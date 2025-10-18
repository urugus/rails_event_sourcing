# DIあり vs DIなし の比較

## 1. テスタビリティの問題

### DIなしの場合（テストが困難）

```ruby
class OrdersController < ApplicationController
  def create
    # 実装に直接依存
    event_store = EventSourcing::EventStore.new(
      event_mappings: Orders::EventMappings.build
    )
    repository = Orders::OrderRepository.new(event_store: event_store)
    command_handler = Orders::OrderCommandHandler.new(repository: repository)

    order_id = command_handler.create_order(
      customer_name: create_params.fetch(:customer_name)
    )
    render json: { order_id: order_id }, status: :created
  end
end

# テストコード（モック化できない）
RSpec.describe OrdersController, type: :controller do
  describe "POST #create" do
    it "creates an order" do
      post :create, params: { order: { customer_name: "Test" } }

      # 問題：実際のEventStoreに書き込まれてしまう
      # - DBへの実際の書き込みが発生
      # - テストが遅い
      # - テストデータのクリーンアップが必要
      # - 並列実行できない

      expect(response).to have_http_status(:created)
      # EventRecordテーブルを確認しないといけない...
    end
  end
end
```

### DIありの場合（テストしやすい）

```ruby
class OrdersController < ApplicationController
  def create
    order_id = command_handler.create_order(
      customer_name: create_params.fetch(:customer_name)
    )
    render json: { order_id: order_id }, status: :created
  end

  private

  def command_handler
    @command_handler ||= Orders::Container.command_handler
  end
end

# テストコード（モック化可能）
RSpec.describe OrdersController, type: :controller do
  describe "POST #create" do
    let(:mock_handler) { instance_double(Orders::OrderCommandHandler) }

    before do
      # Containerをモックに差し替え
      allow(Orders::Container).to receive(:command_handler).and_return(mock_handler)
    end

    it "creates an order" do
      expect(mock_handler).to receive(:create_order)
        .with(customer_name: "Test")
        .and_return("order-123")

      post :create, params: { order: { customer_name: "Test" } }

      # メリット：
      # - DBアクセスなし（高速）
      # - 振る舞いだけをテスト
      # - 並列実行可能
      # - クリーンアップ不要

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to eq({ "order_id" => "order-123" })
    end
  end
end
```

**テスト実行速度の比較:**
- DIなし: 1テストあたり 500ms（DB書き込み含む）
- DIあり: 1テストあたり 5ms（モックのみ）
- **100倍の速度差！**

## 2. コードの重複

### DIなしの場合

```ruby
class OrdersController < ApplicationController
  def create
    event_store = EventSourcing::EventStore.new(
      event_mappings: Orders::EventMappings.build
    )
    repository = Orders::OrderRepository.new(event_store: event_store)
    command_handler = Orders::OrderCommandHandler.new(repository: repository)
    # ... 実装
  end

  def add_item
    # 同じコードをコピペ
    event_store = EventSourcing::EventStore.new(
      event_mappings: Orders::EventMappings.build
    )
    repository = Orders::OrderRepository.new(event_store: event_store)
    command_handler = Orders::OrderCommandHandler.new(repository: repository)
    # ... 実装
  end

  def confirm
    # また同じコードをコピペ
    event_store = EventSourcing::EventStore.new(
      event_mappings: Orders::EventMappings.build
    )
    repository = Orders::OrderRepository.new(event_store: event_store)
    command_handler = Orders::OrderCommandHandler.new(repository: repository)
    # ... 実装
  end

  # 7つのアクション × 4行の初期化 = 28行の重複コード
end

# さらに他のクラスでも同じコード
class OrderProjectionJob
  def perform
    # また同じ初期化コード...
    event_store = EventSourcing::EventStore.new(
      event_mappings: Orders::EventMappings.build
    )
    # ...
  end
end
```

### DIありの場合

```ruby
class OrdersController < ApplicationController
  def create
    command_handler.create_order(...)
  end

  def add_item
    command_handler.add_item(...)
  end

  def confirm
    command_handler.confirm(...)
  end

  private

  # 一箇所だけ
  def command_handler
    @command_handler ||= Orders::Container.command_handler
  end
end

# 他のクラスでも簡潔
class OrderProjectionJob
  def perform
    Orders::Container.command_handler.process(...)
  end
end
```

## 3. 変更への脆弱性

### シナリオ: EventStoreにログ機能を追加したい

**DIなしの場合:**
```ruby
# 変更前
event_store = EventSourcing::EventStore.new(
  event_mappings: Orders::EventMappings.build
)

# 変更後（すべての箇所を修正しないといけない）
event_store = EventSourcing::EventStore.new(
  event_mappings: Orders::EventMappings.build,
  logger: Rails.logger  # 新しいパラメータ
)

# 修正箇所:
# - OrdersController の 7つのアクション
# - OrderProjectionJob
# - その他の使用箇所すべて
# → 10箇所以上の修正が必要
# → 修正漏れのリスク
```

**DIありの場合:**
```ruby
# 変更箇所は1箇所だけ
module Orders
  class Container
    def self.event_store
      @event_store ||= EventSourcing::EventStore.new(
        event_mappings: EventMappings.build,
        logger: Rails.logger  # ここだけ修正
      )
    end
  end
end

# すべての使用箇所に自動的に反映される
```

## 4. メモリとパフォーマンスの問題

### DIなしの場合

```ruby
class OrdersController < ApplicationController
  def create
    # リクエストごとに新しいインスタンスを生成
    event_store = EventSourcing::EventStore.new(...)  # インスタンス1
    repository = Orders::OrderRepository.new(...)      # インスタンス2
    command_handler = Orders::OrderCommandHandler.new(...) # インスタンス3
    # ...
  end

  def add_item
    # また新しいインスタンスを生成（無駄）
    event_store = EventSourcing::EventStore.new(...)  # インスタンス4
    repository = Orders::OrderRepository.new(...)      # インスタンス5
    command_handler = Orders::OrderCommandHandler.new(...) # インスタンス6
    # ...
  end
end

# 1リクエストで6つのインスタンス生成
# 100リクエスト/秒 × 6インスタンス = 600オブジェクト/秒
# → GCへの負荷
```

### DIありの場合（メモ化）

```ruby
class OrdersController < ApplicationController
  private

  def command_handler
    @command_handler ||= Orders::Container.command_handler
    # 1リクエスト内で再利用される
  end
end

# 1リクエストで1つのインスタンスのみ
# 100リクエスト/秒 × 1インスタンス = 100オブジェクト/秒
# → GCへの負荷が6分の1
```

## 5. 設定の切り替えが困難

### DIなしの場合

```ruby
# 本番環境
event_store = EventSourcing::EventStore.new(
  event_mappings: Orders::EventMappings.build
)

# テスト環境では InMemoryEventStore を使いたい
# → すべての箇所で if Rails.env.test? を書かないといけない
if Rails.env.test?
  event_store = InMemoryEventStore.new(...)
else
  event_store = EventSourcing::EventStore.new(...)
end
# → 環境分岐がコード中に散在
```

### DIありの場合

```ruby
# Container で環境に応じて切り替え
module Orders
  class Container
    def self.event_store
      @event_store ||= if Rails.env.test?
        InMemoryEventStore.new(...)
      else
        EventSourcing::EventStore.new(...)
      end
    end
  end
end

# 使用側は環境を意識しない
Orders::Container.event_store  # 自動的に適切なものが返る
```

## 6. 依存関係の可視性

### DIなしの場合

```ruby
# OrderCommandHandler が何に依存しているか分かりにくい
class OrderCommandHandler
  def create_order(customer_name:)
    # 内部で直接インスタンス化
    event_store = EventSourcing::EventStore.new(...)
    repository = OrderRepository.new(event_store: event_store)
    # ...

    # さらにネストした依存
    notifier = EmailNotifier.new
    notifier.send(...)
  end
end

# 問題：
# - 外から依存関係が見えない
# - テストでモック化できない
# - 変更時の影響範囲が不明
```

### DIありの場合

```ruby
# 依存関係が明示的
class OrderCommandHandler
  def initialize(repository:)
    @repository = repository  # 依存が明確
  end

  def create_order(customer_name:)
    @repository.save(...)
  end
end

# メリット：
# - 何に依存しているか一目瞭然
# - テストで簡単にモック化
# - 変更時の影響範囲が明確
```

## まとめ

| 観点 | DIなし | DIあり |
|------|--------|--------|
| テスト速度 | 遅い（DB書き込み） | 高速（モック） |
| テスト並列実行 | 困難 | 容易 |
| コード重複 | 多い | 少ない |
| 変更時の修正箇所 | 多数 | 1箇所 |
| メモリ効率 | 悪い（毎回生成） | 良い（再利用） |
| 設定切り替え | 困難 | 容易 |
| 依存関係の可視性 | 低い | 高い |
| 保守性 | 低い | 高い |

**結論: DI（Dependency Injection）は、テスタビリティ、保守性、パフォーマンスのすべてで優位性がある**
