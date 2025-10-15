#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pg'
require_relative '../01_basic_event_store/event_store'
require_relative 'repository'
require_relative 'order'

# PostgreSQL接続
conn = PG.connect(
  host: 'localhost',
  port: 5432,
  dbname: 'event_sourcing_demo',
  user: 'postgres',
  password: 'postgres'
)

event_store = EventStore.new(conn)
repository = Repository.new(event_store)

puts '=== Aggregate Root パターンデモ ==='
puts

# 1. 新しい注文を作成
puts '1. 新しい注文を作成'
order = Order.new
order.create(
  customer_id: 1,
  items: [
    { product_id: 101, quantity: 2, price: 1000 },
    { product_id: 102, quantity: 1, price: 3000 }
  ]
)

stream_id = 'Order-AGG-001'
repository.save(order, stream_id)
puts "✓ 注文作成: customer_id=#{order.customer_id}, total=#{order.total}, state=#{order.state}"
puts "  未コミットイベント: #{order.uncommitted_events.size}件"
puts

# 2. 注文を復元して操作
puts '2. 注文を復元して確定'
order = repository.load(Order, stream_id)
puts "✓ 注文復元: state=#{order.state}, version=#{order.version}"

order.submit
repository.save(order, stream_id)
puts "✓ 注文確定: state=#{order.state}"
puts

# 3. 商品の追加・削除（エラーデモ）
puts '3. 商品の追加・削除（エラーデモ）'
begin
  order = repository.load(Order, stream_id)
  order.add_item(product_id: 103, quantity: 1, price: 500)
rescue Order::OrderError => e
  puts "✗ エラー: #{e.message}"
end
puts

# 4. 注文を発送
puts '4. 注文を発送'
order = repository.load(Order, stream_id)
order.ship(tracking_number: 'TRACK-123456')
repository.save(order, stream_id)
puts "✓ 注文発送: state=#{order.state}"
puts

# 5. with_aggregateパターン
puts '5. with_aggregateパターンで新しい注文を作成'
order2 = repository.with_aggregate(Order, 'Order-AGG-002') do |o|
  o.create(
    customer_id: 2,
    items: [{ product_id: 201, quantity: 5, price: 800 }]
  )
  o.submit
end

puts "✓ 注文作成・確定: state=#{order2.state}, total=#{order2.total}"
puts

# 6. イベント履歴の確認
puts '6. イベント履歴の確認'
events = event_store.read_stream(stream_id)
puts "ストリーム '#{stream_id}' のイベント:"
events.each do |event|
  puts "  [v#{event.version}] #{event.event_type}"
end
puts

# 7. 状態遷移のデモ
puts '7. 完全な状態遷移のデモ'
order3 = Order.new
order3.create(
  customer_id: 3,
  items: [{ product_id: 301, quantity: 1, price: 1500 }]
)
order3.add_item(product_id: 302, quantity: 2, price: 500)
order3.submit

stream_id3 = 'Order-AGG-003'
repository.save(order3, stream_id3)

puts "イベント履歴:"
event_store.read_stream(stream_id3).each do |event|
  data_str = event.data.map { |k, v| "#{k}=#{v}" }.join(', ')
  puts "  #{event.event_type}: #{data_str}"
end
puts

# 8. キャンセルのデモ
puts '8. 注文のキャンセル'
order4 = repository.with_aggregate(Order, 'Order-AGG-004') do |o|
  o.create(
    customer_id: 4,
    items: [{ product_id: 401, quantity: 1, price: 2000 }]
  )
  o.submit
  o.cancel(reason: 'Customer request')
end

puts "✓ 注文キャンセル: state=#{order4.state}"

conn.close
puts
puts '=== デモ完了 ==='
