#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pg'
require_relative '../01_basic_event_store/event_store'
require_relative '../01_basic_event_store/event'
require_relative 'outbox'
require_relative 'message_broker'
require_relative 'outbox_publisher'

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
outbox = Outbox.new(conn)
message_broker = KafkaMessageBroker.new

puts '=== Transactional Outbox パターンデモ ==='
puts

# 1. イベントとOutboxの原子的な保存
puts '1. イベントとOutboxを同じトランザクションで保存'

conn.transaction do
  # イベントをEvent Storeに保存
  event = Event.new(
    stream_id: 'Order-OUTBOX-001',
    event_type: 'OrderCreated',
    data: {
      customer_id: 1,
      total: 5000,
      items: [{ product_id: 101, quantity: 2, price: 2500 }]
    },
    metadata: { user_id: 'user-1' }
  )
  event_store.append(event)

  # 同じトランザクションでOutboxに追加
  outbox.add(
    aggregate_id: 'Order-OUTBOX-001',
    event_type: 'OrderCreated',
    payload: event.data,
    metadata: event.metadata
  )

  puts "✓ イベントとOutboxを保存（トランザクション内）"
end
puts

# 2. Outboxの内容を確認
puts '2. Outboxの内容を確認'
stats = outbox.stats
puts "Outbox統計:"
puts "  Total: #{stats['total']}"
puts "  Unpublished: #{stats['unpublished']}"
puts "  Published: #{stats['published']}"
puts

# 3. 未発行メッセージを取得
puts '3. 未発行メッセージを取得'
unpublished = outbox.fetch_unpublished(limit: 10)
puts "未発行メッセージ: #{unpublished.size}件"
unpublished.each do |msg|
  puts "  [#{msg.id}] #{msg.event_type} (aggregate: #{msg.aggregate_id})"
end
puts

# 4. さらにイベントを追加
puts '4. さらに複数のイベントを追加'
3.times do |i|
  conn.transaction do
    event = Event.new(
      stream_id: "Order-OUTBOX-00#{i + 2}",
      event_type: 'OrderSubmitted',
      data: { order_id: i + 2 }
    )
    event_store.append(event)

    outbox.add(
      aggregate_id: "Order-OUTBOX-00#{i + 2}",
      event_type: 'OrderSubmitted',
      payload: event.data
    )
  end
end
puts "✓ 3件のイベントを追加"
puts

# 5. Outbox Publisherを使って発行
puts '5. Outbox Publisherでメッセージを発行'
publisher = OutboxPublisher.new(
  outbox: outbox,
  message_broker: message_broker,
  poll_interval: 1,
  batch_size: 10
)

# 1回だけ実行
publisher.publish_once
puts

# 6. 発行結果を確認
puts '6. 発行結果を確認'
stats = outbox.stats
puts "Outbox統計（発行後）:"
puts "  Total: #{stats['total']}"
puts "  Unpublished: #{stats['unpublished']}"
puts "  Published: #{stats['published']}"
puts

puts "メッセージブローカーに発行されたメッセージ: #{message_broker.message_count}件"
message_broker.published_messages.each do |msg|
  puts "  Topic: #{msg[:topic]}"
  puts "    Event: #{msg[:message][:event_type]}"
  puts "    Aggregate: #{msg[:message][:aggregate_id]}"
end
puts

# 7. バックグラウンドでPublisherを起動
puts '7. バックグラウンドでPublisherを起動（5秒間）'

# 新しいメッセージを追加
conn.transaction do
  event = Event.new(
    stream_id: 'Order-OUTBOX-999',
    event_type: 'OrderShipped',
    data: { tracking_number: 'TRACK-XYZ' }
  )
  event_store.append(event)

  outbox.add(
    aggregate_id: 'Order-OUTBOX-999',
    event_type: 'OrderShipped',
    payload: event.data
  )
end

# Publisherを起動
publisher.start
sleep 3  # 3秒待機

# さらにメッセージを追加
2.times do |i|
  conn.transaction do
    event = Event.new(
      stream_id: "Order-OUTBOX-99#{i}",
      event_type: 'OrderCancelled',
      data: { reason: 'test' }
    )
    event_store.append(event)

    outbox.add(
      aggregate_id: "Order-OUTBOX-99#{i}",
      event_type: 'OrderCancelled',
      payload: event.data
    )
  end
end

sleep 3  # さらに3秒待機
publisher.stop

puts "✓ Publisher停止"
puts

# 8. 最終的な統計
puts '8. 最終的な統計'
stats = outbox.stats
puts "Outbox統計（最終）:"
puts "  Total: #{stats['total']}"
puts "  Unpublished: #{stats['unpublished']}"
puts "  Published: #{stats['published']}"
puts "  Max Retries: #{stats['max_retries']}"
puts

puts "メッセージブローカー: #{message_broker.message_count}件のメッセージを発行"
puts

# 9. クリーンアップデモ
puts '9. 古い発行済みメッセージをクリーンアップ'
deleted = outbox.delete_published(older_than: Time.now + 1) # 全て削除
puts "✓ #{deleted}件の発行済みメッセージを削除"

conn.close
puts
puts '=== デモ完了 ==='
puts
puts 'ポイント:'
puts '- イベント保存とOutbox追加を同じトランザクションで実行'
puts '- Message Relayが定期的にOutboxをポーリング'
puts '- メッセージブローカーへの発行を保証'
puts '- At-Least-Once配信（冪等性が重要）'
