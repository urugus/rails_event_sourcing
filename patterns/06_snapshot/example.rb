#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pg'
require 'benchmark'
require_relative '../01_basic_event_store/event_store'
require_relative '../02_aggregate_root/repository'
require_relative '../02_aggregate_root/order'
require_relative 'snapshot_store'
require_relative 'repository_with_snapshot'

# OrderにSnapshot機能を追加
class Order
  def to_snapshot
    {
      state: @state,
      customer_id: @customer_id,
      items: @items,
      total: @total
    }
  end

  def from_snapshot(snapshot)
    @state = snapshot[:state].to_sym
    @customer_id = snapshot[:customer_id]
    @items = snapshot[:items] || []
    @total = snapshot[:total] || 0
  end
end

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
snapshot_store = SnapshotStore.new(conn)
repository = RepositoryWithSnapshot.new(event_store, snapshot_store)

# テーブル作成
conn.exec(File.read(File.join(__dir__, 'migration.sql')))

puts '=== Snapshot パターンデモ ==='
puts

# 1. 大量のイベントを持つAggregateを作成
puts '1. 大量のイベントを持つ注文を作成'
stream_id = 'Order-SNAPSHOT-001'
order = Order.new
order.create(
  customer_id: 1,
  items: [{ product_id: 101, quantity: 1, price: 1000 }]
)

# 100個の商品を追加（100個のイベント）
puts '商品を100個追加中...'
100.times do |i|
  order.add_item(product_id: 200 + i, quantity: 1, price: 100)
end

repository.save(order, stream_id)
puts "✓ #{order.version}個のイベントを保存"
puts

# 2. スナップショットの確認
puts '2. スナップショットの確認'
snapshot = snapshot_store.find(stream_id)
if snapshot
  puts "✓ スナップショット作成済み:"
  puts "  Version: #{snapshot.version}"
  puts "  State: #{snapshot.state[:state]}"
  puts "  Items: #{snapshot.state[:items].size}"
end
puts

# 3. スナップショットなしで復元（ベンチマーク）
puts '3. パフォーマンス比較'
puts
puts '[スナップショットなし]'
repository_without_snapshot = Repository.new(event_store)
time_without_snapshot = Benchmark.realtime do
  order_without = repository_without_snapshot.load(Order, stream_id)
  puts "  復元したOrder: version=#{order_without.version}, items=#{order_without.items.size}"
end
puts "  時間: #{(time_without_snapshot * 1000).round(2)}ms"
puts

# 4. スナップショットありで復元（ベンチマーク）
puts '[スナップショットあり]'
time_with_snapshot = Benchmark.realtime do
  order_with = repository.load(Order, stream_id)
  puts "  復元したOrder: version=#{order_with.version}, items=#{order_with.items.size}"
end
puts "  時間: #{(time_with_snapshot * 1000).round(2)}ms"
puts

speedup = time_without_snapshot / time_with_snapshot
puts "✓ スナップショットにより #{speedup.round(2)}x 高速化"
puts

# 5. さらにイベントを追加してスナップショット更新
puts '5. さらにイベントを追加'
order = repository.load(Order, stream_id)
25.times do
  order.add_item(product_id: 300, quantity: 1, price: 50)
end
repository.save(order, stream_id)
puts "✓ 25個のイベントを追加 (total version: #{order.version})"
puts

# 6. スナップショットの状態を確認
puts '6. 更新されたスナップショット'
snapshot = snapshot_store.find(stream_id)
puts "  Version: #{snapshot.version}"
puts "  Items: #{snapshot.state[:items].size}"
puts

# 7. すべてのスナップショットを表示
puts '7. すべてのスナップショット'
all_snapshots = snapshot_store.all
puts "スナップショット数: #{all_snapshots.size}"
all_snapshots.each do |snap|
  puts "  #{snap.stream_id}: version=#{snap.version}, created_at=#{snap.created_at}"
end

conn.close
puts
puts '=== デモ完了 ==='
puts
puts 'ポイント:'
puts '- スナップショットでイベント再生を高速化'
puts '- N個のイベントごとに自動作成'
puts '- スナップショット + 差分イベントで復元'
puts '- イベントが真のデータソース'
