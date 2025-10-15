# frozen_string_literal: true

require_relative 'outbox'
require_relative 'message_broker'

# Outbox Publisher (Message Relay)
# Polling方式でOutboxテーブルから未発行メッセージを取得し、
# メッセージブローカーに発行する
class OutboxPublisher
  DEFAULT_POLL_INTERVAL = 1 # 秒
  DEFAULT_BATCH_SIZE = 100
  MAX_RETRIES = 3

  def initialize(outbox:, message_broker:, poll_interval: DEFAULT_POLL_INTERVAL, batch_size: DEFAULT_BATCH_SIZE)
    @outbox = outbox
    @message_broker = message_broker
    @poll_interval = poll_interval
    @batch_size = batch_size
    @running = false
  end

  # Publisherを開始（別スレッドで実行）
  def start
    @running = true
    @thread = Thread.new do
      puts "[OutboxPublisher] Started (poll_interval: #{@poll_interval}s, batch_size: #{@batch_size})"

      while @running
        begin
          publish_batch
          sleep @poll_interval
        rescue => e
          puts "[OutboxPublisher] Error: #{e.message}"
          puts e.backtrace
          sleep @poll_interval
        end
      end

      puts "[OutboxPublisher] Stopped"
    end
  end

  # Publisherを停止
  def stop
    @running = false
    @thread&.join
  end

  # 1回だけバッチ処理を実行（テスト用）
  def publish_once
    publish_batch
  end

  private

  def publish_batch
    messages = @outbox.fetch_unpublished(limit: @batch_size)

    return if messages.empty?

    puts "[OutboxPublisher] Processing #{messages.size} messages..."

    messages.each do |message|
      publish_message(message)
    end

    puts "[OutboxPublisher] Batch completed (#{messages.size} messages)"
  end

  def publish_message(message)
    # トピック名を生成（イベントタイプから）
    topic = generate_topic(message.event_type)

    # メッセージブローカーに発行
    success = @message_broker.publish(
      topic: topic,
      message: {
        aggregate_id: message.aggregate_id,
        event_type: message.event_type,
        payload: message.payload,
        metadata: message.metadata
      }
    )

    if success
      # 発行成功: Outboxから削除またはマーク
      @outbox.mark_as_published(message.id)
      puts "[OutboxPublisher] Published message #{message.id} (#{message.event_type})"
    else
      # 発行失敗: 再試行カウントをインクリメント
      @outbox.increment_retry_count(message.id)
      puts "[OutboxPublisher] Failed to publish message #{message.id}, retry count: #{message.retry_count + 1}"

      # 最大再試行回数を超えた場合
      if message.retry_count + 1 >= MAX_RETRIES
        puts "[OutboxPublisher] Message #{message.id} exceeded max retries, marking as failed"
        # 実際の実装では、Dead Letter Queueに移動するなどの処理を行う
      end
    end
  rescue => e
    puts "[OutboxPublisher] Error publishing message #{message.id}: #{e.message}"
    @outbox.increment_retry_count(message.id)
  end

  def generate_topic(event_type)
    # イベントタイプからトピック名を生成
    # 例: OrderCreated -> orders.created
    event_type
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase
      .gsub('_', '.')
  end
end
