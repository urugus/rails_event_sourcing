#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pg'
require_relative 'event'
require_relative 'event_store'

# PostgreSQL接続設定
# 実際の環境に合わせて修正してください
conn = PG.connect(
  host: 'localhost',
  port: 5432,
  dbname: 'event_sourcing_demo',
  user: 'postgres',
  password: 'postgres'
)

# Event Storeの初期化
event_store = EventStore.new(conn)

puts '=== Event Store デモ ==='
puts

# 1. 注文作成イベントを追加
puts '1. 注文作成イベントを追加'
order_created = Event.new(
  stream_id: 'Order-123',
  event_type: 'OrderCreated',
  data: {
    customer_id: 1,
    total: 5000,
    items: [
      { product_id: 101, quantity: 2, price: 1000 },
      { product_id: 102, quantity: 1, price: 3000 }
    ]
  },
  metadata: { user_id: 'user-1', correlation_id: 'corr-123' }
)

event_store.append(order_created)
puts "✓ イベント追加: #{order_created}"
puts

# 2. 注文確定イベントを追加
puts '2. 注文確定イベントを追加'
order_submitted = Event.new(
  stream_id: 'Order-123',
  event_type: 'OrderSubmitted',
  data: {
    submitted_at: Time.now.to_s
  },
  metadata: { user_id: 'user-1' }
)

event_store.append(order_submitted, expected_version: 1)
puts "✓ イベント追加: #{order_submitted}"
puts

# 3. ストリームからイベントを読み込み
puts '3. ストリームからイベントを読み込み'
events = event_store.read_stream('Order-123')
puts "ストリーム 'Order-123' のイベント数: #{events.size}"
events.each_with_index do |event, i|
  puts "  [#{i + 1}] #{event.event_type} (version: #{event.version})"
  puts "      data: #{event.data}"
end
puts

# 4. 楽観的ロックのデモ（並行更新の検出）
puts '4. 楽観的ロック（並行更新の検出）'
begin
  conflict_event = Event.new(
    stream_id: 'Order-123',
    event_type: 'OrderCancelled',
    data: { reason: 'customer request' }
  )

  # 期待バージョンが実際のバージョンと異なる
  event_store.append(conflict_event, expected_version: 1)
rescue EventStore::ConcurrencyError => e
  puts "✗ 並行更新を検出: #{e.message}"
end
puts

# 5. 複数イベントの一括追加
puts '5. 複数イベントの一括追加（トランザクション）'
batch_events = [
  Event.new(
    stream_id: 'Order-456',
    event_type: 'OrderCreated',
    data: { customer_id: 2, total: 3000 }
  ),
  Event.new(
    stream_id: 'Order-456',
    event_type: 'OrderSubmitted',
    data: { submitted_at: Time.now.to_s }
  ),
  Event.new(
    stream_id: 'Order-456',
    event_type: 'OrderShipped',
    data: { tracking_number: 'TRACK-789' }
  )
]

event_store.append_batch(batch_events)
puts "✓ #{batch_events.size}件のイベントを一括追加"
puts

# 6. すべてのイベントを取得
puts '6. すべてのイベントを取得'
all_events = event_store.read_all_events
puts "全イベント数: #{all_events.size}"
all_events.each do |event|
  puts "  #{event.stream_id}: #{event.event_type}"
end
puts

# 7. イベントタイプでフィルタリング
puts '7. イベントタイプでフィルタリング'
created_events = event_store.read_events_by_type('OrderCreated')
puts "OrderCreatedイベント数: #{created_events.size}"
created_events.each do |event|
  puts "  #{event.stream_id}: customer_id=#{event.data['customer_id']}"
end

conn.close
puts
puts '=== デモ完了 ==='
