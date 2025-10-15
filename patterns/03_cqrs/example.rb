#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pg'
require 'securerandom'
require_relative '../01_basic_event_store/event_store'
require_relative '../02_aggregate_root/repository'
require_relative 'command'
require_relative 'command_handler'
require_relative 'command_bus'
require_relative 'query'
require_relative 'query_handler'
require_relative 'read_model'

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

# Read Modelテーブルを作成
OrderReadModel.create_table(conn)

# Command Busの設定
command_bus = CommandBus.new
command_bus.register(CreateOrderCommand, CreateOrderHandler.new(repository))
command_bus.register(SubmitOrderCommand, SubmitOrderHandler.new(repository))
command_bus.register(ShipOrderCommand, ShipOrderHandler.new(repository))
command_bus.register(CancelOrderCommand, CancelOrderHandler.new(repository))
command_bus.register(AddOrderItemCommand, AddOrderItemHandler.new(repository))

puts '=== CQRS パターンデモ ==='
puts

# 1. コマンドで注文を作成
puts '1. コマンドで注文を作成'
order_id_1 = SecureRandom.uuid
command = CreateOrderCommand.new(
  order_id: order_id_1,
  customer_id: 1,
  items: [
    { product_id: 101, quantity: 2, price: 1000 },
    { product_id: 102, quantity: 1, price: 3000 }
  ]
)

result = command_bus.dispatch(command)
puts "✓ 注文作成: #{result.success? ? 'SUCCESS' : 'FAILURE'}"
puts

# Read Modelを手動で更新（後でProjectionパターンで自動化）
order = repository.load(Order, "Order-#{order_id_1}")
read_model = OrderReadModel.new(
  order_id: order_id_1,
  customer_id: order.customer_id,
  total: order.total,
  item_count: order.items.size,
  state: order.state.to_s,
  created_at: Time.now,
  updated_at: Time.now
)
read_model.save(conn)

# 2. クエリで注文を取得
puts '2. クエリで注文を取得'
query = GetOrderQuery.new(order_id: order_id_1)
query_result = GetOrderHandler.new(conn).handle(query)

if query_result.success?
  puts "✓ 注文詳細:"
  query_result.data.each { |k, v| puts "  #{k}: #{v}" }
end
puts

# 3. 注文を確定
puts '3. 注文を確定'
submit_command = SubmitOrderCommand.new(order_id: order_id_1)
command_bus.dispatch(submit_command)

# Read Model更新
order = repository.load(Order, "Order-#{order_id_1}")
read_model.state = order.state.to_s
read_model.updated_at = Time.now
read_model.save(conn)
puts "✓ 注文確定完了"
puts

# 4. 注文を発送
puts '4. 注文を発送'
ship_command = ShipOrderCommand.new(
  order_id: order_id_1,
  tracking_number: 'TRACK-123456'
)
command_bus.dispatch(ship_command)

# Read Model更新
order = repository.load(Order, "Order-#{order_id_1}")
read_model.state = order.state.to_s
read_model.tracking_number = 'TRACK-123456'
read_model.updated_at = Time.now
read_model.save(conn)
puts "✓ 注文発送完了"
puts

# 5. 複数の注文を作成
puts '5. 複数の注文を作成'
3.times do |i|
  order_id = SecureRandom.uuid
  command = CreateOrderCommand.new(
    order_id: order_id,
    customer_id: 1,
    items: [{ product_id: 200 + i, quantity: 1, price: 1000 * (i + 1) }]
  )
  command_bus.dispatch(command)

  # Read Model更新
  order = repository.load(Order, "Order-#{order_id}")
  read_model = OrderReadModel.new(
    order_id: order_id,
    customer_id: 1,
    total: order.total,
    item_count: order.items.size,
    state: order.state.to_s,
    created_at: Time.now,
    updated_at: Time.now
  )
  read_model.save(conn)
end
puts "✓ 3件の注文を作成"
puts

# 6. 顧客の注文一覧を取得
puts '6. 顧客の注文一覧を取得'
customer_query = GetCustomerOrdersQuery.new(customer_id: 1, limit: 10)
customer_result = GetCustomerOrdersHandler.new(conn).handle(customer_query)

puts "顧客1の注文: #{customer_result.data.size}件"
customer_result.data.each do |order_data|
  puts "  Order #{order_data[:order_id]}: total=#{order_data[:total]}, state=#{order_data[:state]}"
end
puts

# 7. 注文統計を取得
puts '7. 注文統計を取得'
stats_query = GetOrderStatsQuery.new
stats_result = GetOrderStatsHandler.new(conn).handle(stats_query)

puts "注文統計:"
stats_result.data.each { |k, v| puts "  #{k}: #{v}" }
puts

# 8. 出荷待ち注文を取得
puts '8. 出荷待ち注文を取得'

# 確定状態の注文を作成
order_id_pending = SecureRandom.uuid
command = CreateOrderCommand.new(
  order_id: order_id_pending,
  customer_id: 2,
  items: [{ product_id: 999, quantity: 1, price: 5000 }]
)
command_bus.dispatch(command)
command_bus.dispatch(SubmitOrderCommand.new(order_id: order_id_pending))

# Read Model更新
order = repository.load(Order, "Order-#{order_id_pending}")
OrderReadModel.new(
  order_id: order_id_pending,
  customer_id: 2,
  total: 5000,
  item_count: 1,
  state: 'submitted',
  created_at: Time.now,
  updated_at: Time.now
).save(conn)

pending_query = GetPendingShipmentsQuery.new(limit: 10)
pending_result = GetPendingShipmentsHandler.new(conn).handle(pending_query)

puts "出荷待ち注文: #{pending_result.data.size}件"
pending_result.data.each do |order_data|
  puts "  Order #{order_data[:order_id]}: total=#{order_data[:total]}"
end

conn.close
puts
puts '=== デモ完了 ==='
puts
puts 'ポイント:'
puts '- Commandで書き込み操作を実行'
puts '- Queryで読み取り操作を実行'
puts '- Write ModelとRead Modelが分離'
puts '- Read Modelはクエリに最適化された構造'
