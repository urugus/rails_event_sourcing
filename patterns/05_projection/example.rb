#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pg'
require 'securerandom'
require_relative '../01_basic_event_store/event_store'
require_relative '../02_aggregate_root/repository'
require_relative '../02_aggregate_root/order'
require_relative '../03_cqrs/read_model'
require_relative 'order_summary_projection'

# PostgreSQL接続
conn = PG.connect(
  host: 'localhost',
  port: 5432,
  dbname: 'event_sourcing_demo',
  user: 'postgres',
  password: 'postgres'
)

# セットアップ
event_store = EventStore.new(conn)
repository = Repository.new(event_store)
projection = OrderSummaryProjection.new(conn)

# テーブル作成
OrderReadModel.create_table(conn)
conn.exec(File.read(File.join(__dir__, 'migration.sql')))

puts '=== Projection パターンデモ ==='
puts

# 1. 注文を作成（イベントを生成）
puts '1. 注文を作成'
3.times do |i|
  order_id = "PROJ-#{SecureRandom.uuid}"
  repository.with_aggregate(Order, "Order-#{order_id}") do |order|
    order.create(
      customer_id: 1,
      items: [{ product_id: 100 + i, quantity: i + 1, price: 1000 }]
    )
    order.submit
  end
  puts "✓ 注文作成: #{order_id}"
end
puts

# 2. Projectionを実行（手動）
puts '2. Projectionを手動で実行'
events = event_store.read_all_events(limit: 100)
events.each do |event|
  projection.project(event)
  projection.update_checkpoint(event.id)
end
puts "✓ #{events.size}件のイベントを投影"
puts

# 3. Read Modelを確認
puts '3. Read Modelを確認'
result = conn.exec('SELECT * FROM order_read_models ORDER BY created_at DESC')
puts "Read Model: #{result.ntuples}件"
result.each do |row|
  puts "  Order #{row['order_id']}: total=#{row['total']}, state=#{row['state']}"
end
puts

# 4. Checkpointを確認
puts '4. Checkpointを確認'
checkpoint = projection.get_checkpoint
puts "Checkpoint: last_event_id=#{checkpoint}"
puts

# 5. さらにイベントを追加
puts '5. さらにイベントを追加'
order_id = "PROJ-#{SecureRandom.uuid}"
repository.with_aggregate(Order, "Order-#{order_id}") do |order|
  order.create(
    customer_id: 2,
    items: [{ product_id: 200, quantity: 1, price: 5000 }]
  )
  order.submit
  order.ship(tracking_number: 'TRACK-999')
end
puts "✓ 注文作成・発送: #{order_id}"
puts

# 6. Checkpointから再開して新しいイベントだけを投影
puts '6. Checkpointから新しいイベントのみ投影'
last_checkpoint = projection.get_checkpoint
new_events = event_store.read_all_events(limit: 100).select { |e| e.id > last_checkpoint }

puts "新しいイベント: #{new_events.size}件"
new_events.each do |event|
  puts "  Projecting: #{event.event_type} (id: #{event.id})"
  projection.project(event)
  projection.update_checkpoint(event.id)
end
puts

# 7. Read Modelを再確認
puts '7. Read Modelを再確認'
result = conn.exec('SELECT * FROM order_read_models ORDER BY created_at DESC LIMIT 5')
puts "Read Model（最新5件）:"
result.each do |row|
  puts "  #{row['order_id']}: total=#{row['total']}, state=#{row['state']}, items=#{row['item_count']}"
end
puts

# 8. Projectionの再構築
puts '8. Projectionの再構築（すべてのイベントを再生）'
projection.rebuild(event_store)

result = conn.exec('SELECT COUNT(*) as count FROM order_read_models')
puts "✓ Read Model再構築完了: #{result[0]['count']}件"
puts

conn.close
puts '=== デモ完了 ==='
puts
puts 'ポイント:'
puts '- イベントストリームからRead Modelを生成'
puts '- Checkpointで処理位置を記録'
puts '- 新しいイベントのみを投影可能'
puts '- イベントから何度でも再構築可能'
