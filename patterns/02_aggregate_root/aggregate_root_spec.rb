# frozen_string_literal: true

require 'minitest/autorun'
require 'pg'
require_relative '../01_basic_event_store/event_store'
require_relative 'repository'
require_relative 'order'

class AggregateRootTest < Minitest::Test
  def setup
    @conn = PG.connect(
      host: ENV.fetch('DB_HOST', 'localhost'),
      port: ENV.fetch('DB_PORT', 5432),
      dbname: ENV.fetch('DB_NAME', 'event_sourcing_test'),
      user: ENV.fetch('DB_USER', 'postgres'),
      password: ENV.fetch('DB_PASSWORD', 'postgres')
    )

    @conn.exec('TRUNCATE TABLE events RESTART IDENTITY CASCADE')
    @event_store = EventStore.new(@conn)
    @repository = Repository.new(@event_store)
  end

  def teardown
    @conn.close
  end

  def test_create_order
    order = Order.new
    order.create(
      customer_id: 1,
      items: [{ product_id: 101, quantity: 2, price: 1000 }]
    )

    assert_equal :created, order.state
    assert_equal 1, order.customer_id
    assert_equal 2000, order.total
    assert_equal 1, order.uncommitted_events.size
  end

  def test_order_state_transitions
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])
    order.submit
    order.ship(tracking_number: 'TRACK-123')

    assert_equal :shipped, order.state
    assert order.shipped?
  end

  def test_cannot_create_order_twice
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])

    assert_raises(Order::OrderError) do
      order.create(customer_id: 2, items: [{ product_id: 102, quantity: 1, price: 500 }])
    end
  end

  def test_cannot_submit_before_creation
    order = Order.new

    assert_raises(Order::OrderError) do
      order.submit
    end
  end

  def test_cannot_ship_before_submission
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])

    assert_raises(Order::OrderError) do
      order.ship(tracking_number: 'TRACK-123')
    end
  end

  def test_cancel_order
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])
    order.submit
    order.cancel(reason: 'Customer request')

    assert_equal :cancelled, order.state
    assert order.cancelled?
  end

  def test_cannot_cancel_shipped_order
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])
    order.submit
    order.ship(tracking_number: 'TRACK-123')

    assert_raises(Order::OrderError) do
      order.cancel(reason: 'Too late')
    end
  end

  def test_add_and_remove_items
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])
    order.add_item(product_id: 102, quantity: 2, price: 500)

    assert_equal 2, order.items.size
    assert_equal 2000, order.total

    order.remove_item(product_id: 101)

    assert_equal 1, order.items.size
    assert_equal 1000, order.total
  end

  def test_cannot_modify_submitted_order
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])
    order.submit

    assert_raises(Order::OrderError) do
      order.add_item(product_id: 102, quantity: 1, price: 500)
    end
  end

  def test_save_and_load_order
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 2, price: 1000 }])
    order.submit

    stream_id = 'Order-TEST-001'
    @repository.save(order, stream_id)

    # イベントがコミットされたことを確認
    assert_equal 0, order.uncommitted_events.size

    # 復元
    loaded_order = @repository.load(Order, stream_id)

    assert_equal :submitted, loaded_order.state
    assert_equal 1, loaded_order.customer_id
    assert_equal 2000, loaded_order.total
    assert_equal 2, loaded_order.version
  end

  def test_optimistic_locking
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])

    stream_id = 'Order-TEST-002'
    @repository.save(order, stream_id)

    # 2つの異なるインスタンスで同じ注文を読み込む
    order1 = @repository.load(Order, stream_id)
    order2 = @repository.load(Order, stream_id)

    # 両方のインスタンスで操作
    order1.submit
    order2.submit

    # 最初の保存は成功
    @repository.save(order1, stream_id)

    # 2番目の保存は失敗（並行更新の検出）
    assert_raises(EventStore::ConcurrencyError) do
      @repository.save(order2, stream_id)
    end
  end

  def test_with_aggregate_pattern
    stream_id = 'Order-TEST-003'

    order = @repository.with_aggregate(Order, stream_id) do |o|
      o.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])
      o.submit
    end

    assert_equal :submitted, order.state

    # 同じストリームで再度操作
    @repository.with_aggregate(Order, stream_id) do |o|
      o.ship(tracking_number: 'TRACK-456')
    end

    # 確認
    final_order = @repository.load(Order, stream_id)
    assert_equal :shipped, final_order.state
  end

  def test_event_replay
    order = Order.new
    order.create(customer_id: 1, items: [{ product_id: 101, quantity: 1, price: 1000 }])
    order.add_item(product_id: 102, quantity: 2, price: 500)
    order.submit
    order.ship(tracking_number: 'TRACK-789')

    stream_id = 'Order-TEST-004'
    @repository.save(order, stream_id)

    # イベントを読み込んで再生
    events = @event_store.read_stream(stream_id)
    assert_equal 4, events.size

    # 新しいインスタンスでイベントを再生
    replayed_order = Order.new
    replayed_order.load_from_history(events)

    # 状態が正しく復元されたことを確認
    assert_equal :shipped, replayed_order.state
    assert_equal 1, replayed_order.customer_id
    assert_equal 2, replayed_order.items.size
    assert_equal 2000, replayed_order.total
    assert_equal 4, replayed_order.version
  end
end
