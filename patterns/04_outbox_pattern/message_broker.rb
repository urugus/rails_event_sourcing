# frozen_string_literal: true

# メッセージブローカーのインターフェース
# 実際の環境では、Kafka、RabbitMQ、AWS SNS/SQSなどを使用
class MessageBroker
  def initialize
    @published_messages = []
  end

  # メッセージを発行
  def publish(topic:, message:)
    # 実際の実装では、Kafka、RabbitMQなどにメッセージを送信
    # ここではシンプルに配列に追加
    @published_messages << {
      topic: topic,
      message: message,
      published_at: Time.now
    }

    puts "[MessageBroker] Published to #{topic}: #{message[:event_type]}"
    true
  rescue => e
    puts "[MessageBroker] Failed to publish: #{e.message}"
    false
  end

  # 発行されたメッセージの一覧（テスト用）
  def published_messages
    @published_messages
  end

  # メッセージ数をカウント
  def message_count
    @published_messages.size
  end

  # メッセージをクリア（テスト用）
  def clear
    @published_messages.clear
  end
end

# Kafka風のメッセージブローカー（シミュレーション）
class KafkaMessageBroker < MessageBroker
  def publish(topic:, message:)
    # Kafkaへのメッセージ発行をシミュレート
    # 実際はkafka-ruby gemなどを使用
    puts "[Kafka] Producing message to topic '#{topic}'"
    puts "  Event: #{message[:event_type]}"
    puts "  Aggregate: #{message[:aggregate_id]}"
    puts "  Payload: #{message[:payload]}"

    super
  end
end

# RabbitMQ風のメッセージブローカー（シミュレーション）
class RabbitMQMessageBroker < MessageBroker
  def publish(topic:, message:)
    # RabbitMQへのメッセージ発行をシミュレート
    # 実際はbunny gemなどを使用
    exchange = topic.split('.').first
    routing_key = topic

    puts "[RabbitMQ] Publishing to exchange '#{exchange}' with routing key '#{routing_key}'"
    puts "  Event: #{message[:event_type]}"

    super
  end
end
