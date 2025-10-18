# テストガイド - Example 2

example_2 では、すべての依存性が Container 経由で管理されているため、テストが容易です。

## 基本方針

**Container をスタブすることで、すべての依存性をモックに差し替え可能**

```ruby
# テスト時の基本パターン
RSpec.describe SomeClass do
  before do
    # Containerをリセット（他のテストの影響を排除）
    Orders::Container.reset!
    Projections::Container.reset!
  end

  # Containerをスタブしてモックを注入
  let(:mock_handler) { instance_double(Orders::OrderCommandHandler) }

  before do
    allow(Orders::Container).to receive(:command_handler).and_return(mock_handler)
  end
end
```

## Controller のテスト

### Write Side（コマンド側）

```ruby
# spec/controllers/orders_controller_spec.rb
require 'rails_helper'

RSpec.describe OrdersController, type: :controller do
  let(:mock_command_handler) { instance_double(Orders::OrderCommandHandler) }

  before do
    # Container経由でモックを注入
    allow(Orders::Container).to receive(:command_handler).and_return(mock_command_handler)
  end

  describe 'POST #create' do
    it 'creates an order via command handler' do
      # モックの期待値を設定
      expect(mock_command_handler).to receive(:create_order)
        .with(customer_name: 'Test Customer')
        .and_return('order-123')

      # リクエスト実行
      post :create, params: { order: { customer_name: 'Test Customer' } }

      # レスポンス検証
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to eq({ 'order_id' => 'order-123' })
    end
  end

  describe 'POST #add_item' do
    it 'adds an item to the order' do
      expect(mock_command_handler).to receive(:add_item)
        .with(
          order_id: 'order-123',
          product_name: 'Laptop',
          quantity: 1,
          unit_price_cents: 120000
        )

      post :add_item, params: {
        id: 'order-123',
        order_item: {
          product_name: 'Laptop',
          quantity: 1,
          unit_price_cents: 120000
        }
      }

      expect(response).to have_http_status(:no_content)
    end
  end
end
```

### Read Side（クエリ側）

```ruby
# spec/controllers/orders_controller_spec.rb (続き)
RSpec.describe OrdersController, type: :controller do
  let(:mock_query_service) { instance_double(Projections::Queries::OrderQueryService) }

  before do
    allow(Projections::Container).to receive(:query_service).and_return(mock_query_service)
  end

  describe 'GET #index' do
    it 'returns a list of orders' do
      mock_summaries = [
        double(
          order_id: 'order-1',
          customer_name: 'Customer 1',
          status: 'confirmed',
          total_amount_cents: 100000,
          item_count: 2,
          confirmed_at: Time.current,
          cancelled_at: nil,
          shipped_at: nil
        )
      ]

      expect(mock_query_service).to receive(:list_orders).and_return(mock_summaries)

      get :index

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.first['order_id']).to eq('order-1')
    end
  end

  describe 'GET #show' do
    it 'returns order details' do
      mock_details = double(
        order_id: 'order-1',
        customer_name: 'Customer 1',
        status: 'confirmed',
        items: [{ 'product_name' => 'Laptop', 'quantity' => 1, 'unit_price_cents' => 100000 }],
        total_amount_cents: 100000,
        confirmed_at: Time.current,
        cancelled_at: nil,
        shipped_at: nil,
        cancellation_reason: nil,
        tracking_number: nil
      )

      expect(mock_query_service).to receive(:find_order)
        .with('order-1')
        .and_return(mock_details)

      get :show, params: { id: 'order-1' }

      expect(response).to have_http_status(:ok)
    end
  end
end
```

## CommandHandler のテスト

```ruby
# spec/domain/orders/order_command_handler_spec.rb
require 'rails_helper'

RSpec.describe Orders::OrderCommandHandler do
  let(:mock_repository) { instance_double(Orders::OrderRepository) }
  let(:mock_order) { instance_double(Orders::Order) }
  let(:handler) { described_class.new(repository: mock_repository) }

  describe '#create_order' do
    it 'creates a new order' do
      allow(mock_repository).to receive(:load).and_return(mock_order)
      expect(mock_order).to receive(:create).with(customer_name: 'Test')
      expect(mock_repository).to receive(:store).with(mock_order)

      order_id = handler.create_order(customer_name: 'Test')

      expect(order_id).to be_a(String)
    end
  end

  describe '#add_item' do
    it 'adds an item to an order' do
      allow(mock_repository).to receive(:load).with('order-123').and_return(mock_order)
      expect(mock_order).to receive(:add_item)
        .with(product_name: 'Laptop', quantity: 1, unit_price_cents: 120000)
      expect(mock_repository).to receive(:store).with(mock_order)

      handler.add_item(
        order_id: 'order-123',
        product_name: 'Laptop',
        quantity: 1,
        unit_price_cents: 120000
      )
    end
  end
end
```

## Projector のテスト

```ruby
# spec/projections/projectors/order_summary_projector_spec.rb
require 'rails_helper'

RSpec.describe Projections::Projectors::OrderSummaryProjector do
  let(:projector) { described_class.new }

  describe '#project' do
    context 'when OrderCreated event' do
      it 'creates a new read model' do
        event = Orders::Events::OrderCreated.new(
          order_id: 'order-123',
          customer_name: 'Test Customer'
        )

        expect {
          projector.project(event)
        }.to change(OrderSummaryReadModel, :count).by(1)

        read_model = OrderSummaryReadModel.find_by(order_id: 'order-123')
        expect(read_model.customer_name).to eq('Test Customer')
        expect(read_model.status).to eq('draft')
      end
    end

    context 'when ItemAdded event' do
      before do
        OrderSummaryReadModel.create!(
          order_id: 'order-123',
          customer_name: 'Test',
          status: 'draft',
          total_amount_cents: 0,
          item_count: 0
        )
      end

      it 'updates the read model' do
        event = Orders::Events::ItemAdded.new(
          order_id: 'order-123',
          product_name: 'Laptop',
          quantity: 2,
          unit_price_cents: 100000
        )

        projector.project(event)

        read_model = OrderSummaryReadModel.find_by(order_id: 'order-123')
        expect(read_model.total_amount_cents).to eq(200000)
        expect(read_model.item_count).to eq(2)
      end
    end
  end
end
```

## ProjectionManager のテスト

```ruby
# spec/projections/projection_manager_spec.rb
require 'rails_helper'

RSpec.describe Projections::ProjectionManager do
  let(:mock_projector) { instance_double(Projections::BaseProjector) }
  let(:event_mappings) { Orders::EventMappings.build }
  let(:manager) do
    described_class.new(
      event_mappings: event_mappings,
      projectors: [mock_projector]
    )
  end

  before do
    # Event Store にイベントを準備
    EventRecord.create!(
      aggregate_id: 'order-123',
      aggregate_type: 'Order',
      event_type: 'orders.order_created',
      data: { customer_name: 'Test' },
      version: 1,
      occurred_at: Time.current
    )
  end

  describe '#call' do
    it 'projects events to projectors' do
      # Projectorがイベントを購読している
      allow(mock_projector).to receive(:subscribes_to?).and_return(true)
      allow(mock_projector).to receive_message_chain(:class, :projector_name).and_return('test_projector')

      # イベントが投影される
      expect(mock_projector).to receive(:project).once

      manager.call
    end
  end

  describe '#retry_failed_projections' do
    before do
      # エラーレコードを作成
      Projections::Models::ProjectionError.create!(
        projector_name: 'test_projector',
        event_id: EventRecord.first.id,
        event_type: 'orders.order_created',
        error_message: 'Test error',
        retry_count: 1,
        next_retry_at: 1.minute.ago
      )

      allow(mock_projector).to receive_message_chain(:class, :projector_name).and_return('test_projector')
    end

    it 'retries failed projections' do
      allow(mock_projector).to receive(:subscribes_to?).and_return(true)
      expect(mock_projector).to receive(:project).once

      manager.retry_failed_projections
    end
  end
end
```

## Rake タスクのテスト

```ruby
# spec/tasks/event_sourcing_rake_spec.rb
require 'rails_helper'
require 'rake'

RSpec.describe 'event_sourcing rake tasks' do
  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:mock_manager) { instance_double(Projections::ProjectionManager) }

  before do
    # Container経由でモックを注入
    allow(Projections::Container).to receive(:projection_manager).and_return(mock_manager)
  end

  describe 'event_sourcing:project' do
    it 'runs projection via Container' do
      expect(mock_manager).to receive(:call)

      Rake::Task['event_sourcing:project'].execute
    end
  end

  describe 'event_sourcing:retry_failed' do
    it 'retries failed projections via Container' do
      expect(mock_manager).to receive(:retry_failed_projections)

      Rake::Task['event_sourcing:retry_failed'].execute
    end
  end
end
```

## 統合テスト

```ruby
# spec/integration/order_flow_spec.rb
require 'rails_helper'

RSpec.describe 'Order flow integration test' do
  # 統合テストでは実際のDBを使用
  # Containerのモックは使わない

  it 'creates an order and projects to read models' do
    # 1. 注文作成
    order_id = Orders::Container.command_handler.create_order(
      customer_name: 'Integration Test'
    )

    # 2. イベントが保存されているか確認
    expect(EventRecord.count).to eq(1)
    event = EventRecord.first
    expect(event.event_type).to eq('orders.order_created')

    # 3. Projection実行
    Projections::Container.projection_manager.call

    # 4. Read Modelに反映されているか確認
    summary = OrderSummaryReadModel.find_by(order_id: order_id)
    expect(summary).not_to be_nil
    expect(summary.customer_name).to eq('Integration Test')
    expect(summary.status).to eq('draft')

    details = OrderDetailsReadModel.find_by(order_id: order_id)
    expect(details).not_to be_nil
  end
end
```

## テスト実行速度の比較

| テストタイプ | 依存性 | 実行速度 | 用途 |
|------------|--------|---------|------|
| ユニットテスト（モック） | Containerをスタブ | 5ms/test | ロジックの検証 |
| 統合テスト | 実際のDB | 500ms/test | E2Eフローの検証 |

## ベストプラクティス

1. **ユニットテストではContainer経由でモックを注入**
   - 高速で並列実行可能
   - 依存性を完全にコントロール

2. **統合テストでは実際のContainerを使用**
   - 実際の動作を検証
   - テスト数は少なめに

3. **各テストでreset!を呼ぶ**
   - テスト間の影響を排除
   - クリーンな状態で開始

```ruby
RSpec.configure do |config|
  config.before(:each) do
    Orders::Container.reset!
    Projections::Container.reset!
  end
end
```

これにより、**テストしやすく、保守しやすいコードベース**が実現できます。
