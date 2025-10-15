# frozen_string_literal: true

require 'minitest/autorun'
require 'pg'
require_relative 'event'
require_relative 'event_store'

# Event Storeのテスト
class EventStoreTest < Minitest::Test
  def setup
    @conn = PG.connect(
      host: ENV.fetch('DB_HOST', 'localhost'),
      port: ENV.fetch('DB_PORT', 5432),
      dbname: ENV.fetch('DB_NAME', 'event_sourcing_test'),
      user: ENV.fetch('DB_USER', 'postgres'),
      password: ENV.fetch('DB_PASSWORD', 'postgres')
    )
    @event_store = EventStore.new(@conn)

    # テスト用テーブルをクリーンアップ
    @conn.exec('TRUNCATE TABLE events RESTART IDENTITY CASCADE')
  end

  def teardown
    @conn.close
  end

  def test_append_event
    event = Event.new(
      stream_id: 'Order-1',
      event_type: 'OrderCreated',
      data: { customer_id: 1, total: 1000 }
    )

    result = @event_store.append(event)

    assert result.id, 'Event should have an ID'
    assert_equal 1, result.version, 'First event should have version 1'
  end

  def test_append_multiple_events_to_same_stream
    stream_id = 'Order-2'

    event1 = Event.new(
      stream_id: stream_id,
      event_type: 'OrderCreated',
      data: { customer_id: 1 }
    )

    event2 = Event.new(
      stream_id: stream_id,
      event_type: 'OrderSubmitted',
      data: { submitted_at: Time.now.to_s }
    )

    @event_store.append(event1)
    @event_store.append(event2)

    assert_equal 1, event1.version
    assert_equal 2, event2.version
  end

  def test_read_stream
    stream_id = 'Order-3'

    3.times do |i|
      event = Event.new(
        stream_id: stream_id,
        event_type: "Event#{i}",
        data: { index: i }
      )
      @event_store.append(event)
    end

    events = @event_store.read_stream(stream_id)

    assert_equal 3, events.size
    assert_equal 'Event0', events[0].event_type
    assert_equal 'Event2', events[2].event_type
  end

  def test_read_stream_from_version
    stream_id = 'Order-4'

    3.times do |i|
      event = Event.new(
        stream_id: stream_id,
        event_type: "Event#{i}",
        data: { index: i }
      )
      @event_store.append(event)
    end

    events = @event_store.read_stream(stream_id, from_version: 1)

    assert_equal 2, events.size
    assert_equal 'Event1', events[0].event_type
  end

  def test_optimistic_locking
    stream_id = 'Order-5'

    event1 = Event.new(
      stream_id: stream_id,
      event_type: 'OrderCreated',
      data: { customer_id: 1 }
    )
    @event_store.append(event1)

    # 正しいバージョンを指定すれば成功
    event2 = Event.new(
      stream_id: stream_id,
      event_type: 'OrderSubmitted',
      data: {}
    )
    @event_store.append(event2, expected_version: 1)

    # 間違ったバージョンを指定すると失敗
    event3 = Event.new(
      stream_id: stream_id,
      event_type: 'OrderShipped',
      data: {}
    )

    assert_raises(EventStore::ConcurrencyError) do
      @event_store.append(event3, expected_version: 1)
    end
  end

  def test_append_batch
    stream_id = 'Order-6'

    events = [
      Event.new(stream_id: stream_id, event_type: 'Event1', data: { a: 1 }),
      Event.new(stream_id: stream_id, event_type: 'Event2', data: { b: 2 }),
      Event.new(stream_id: stream_id, event_type: 'Event3', data: { c: 3 })
    ]

    @event_store.append_batch(events)

    stored_events = @event_store.read_stream(stream_id)
    assert_equal 3, stored_events.size
    assert_equal 1, stored_events[0].version
    assert_equal 3, stored_events[2].version
  end

  def test_get_stream_version
    stream_id = 'Order-7'

    assert_equal 0, @event_store.get_stream_version(stream_id)

    2.times do |i|
      event = Event.new(
        stream_id: stream_id,
        event_type: "Event#{i}",
        data: {}
      )
      @event_store.append(event)
    end

    assert_equal 2, @event_store.get_stream_version(stream_id)
  end

  def test_stream_exists
    stream_id = 'Order-8'

    refute @event_store.stream_exists?(stream_id)

    event = Event.new(
      stream_id: stream_id,
      event_type: 'OrderCreated',
      data: {}
    )
    @event_store.append(event)

    assert @event_store.stream_exists?(stream_id)
  end

  def test_read_all_events
    3.times do |i|
      event = Event.new(
        stream_id: "Order-#{i}",
        event_type: 'OrderCreated',
        data: { index: i }
      )
      @event_store.append(event)
    end

    events = @event_store.read_all_events
    assert events.size >= 3
  end

  def test_read_events_by_type
    2.times do |i|
      @event_store.append(
        Event.new(
          stream_id: "Order-#{i}",
          event_type: 'OrderCreated',
          data: {}
        )
      )
    end

    @event_store.append(
      Event.new(
        stream_id: 'Order-100',
        event_type: 'OrderShipped',
        data: {}
      )
    )

    created_events = @event_store.read_events_by_type('OrderCreated')
    assert created_events.size >= 2
    assert created_events.all? { |e| e.event_type == 'OrderCreated' }
  end
end
