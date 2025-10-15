# frozen_string_literal: true

require 'json'

# Outboxメッセージ
class OutboxMessage
  attr_reader :id, :aggregate_id, :event_type, :payload, :metadata,
              :created_at, :published_at, :published, :retry_count

  def initialize(attrs)
    @id = attrs['id']&.to_i
    @aggregate_id = attrs['aggregate_id']
    @event_type = attrs['event_type']
    @payload = attrs['payload'].is_a?(String) ? JSON.parse(attrs['payload']) : attrs['payload']
    @metadata = attrs['metadata'].is_a?(String) ? JSON.parse(attrs['metadata']) : (attrs['metadata'] || {})
    @created_at = attrs['created_at']
    @published_at = attrs['published_at']
    @published = attrs['published'] == true || attrs['published'] == 't'
    @retry_count = attrs['retry_count']&.to_i || 0
  end

  def to_h
    {
      id: id,
      aggregate_id: aggregate_id,
      event_type: event_type,
      payload: payload,
      metadata: metadata,
      created_at: created_at,
      published_at: published_at,
      published: published,
      retry_count: retry_count
    }
  end
end

# Outboxリポジトリ
class Outbox
  def initialize(connection)
    @connection = connection
  end

  # メッセージを追加（イベント保存と同じトランザクション内で呼ぶ）
  def add(aggregate_id:, event_type:, payload:, metadata: {})
    result = @connection.exec_params(
      'INSERT INTO outbox (aggregate_id, event_type, payload, metadata)
       VALUES ($1, $2, $3, $4)
       RETURNING id',
      [aggregate_id, event_type, payload.to_json, metadata.to_json]
    )

    result[0]['id'].to_i
  end

  # 未発行メッセージを取得
  def fetch_unpublished(limit: 100)
    result = @connection.exec_params(
      'SELECT * FROM outbox
       WHERE published = FALSE
       ORDER BY aggregate_id, created_at ASC
       LIMIT $1',
      [limit]
    )

    result.map { |row| OutboxMessage.new(row) }
  end

  # 発行済みとしてマーク
  def mark_as_published(message_id)
    @connection.exec_params(
      'UPDATE outbox
       SET published = TRUE, published_at = CURRENT_TIMESTAMP
       WHERE id = $1',
      [message_id]
    )
  end

  # 再試行回数をインクリメント
  def increment_retry_count(message_id)
    @connection.exec_params(
      'UPDATE outbox
       SET retry_count = retry_count + 1
       WHERE id = $1',
      [message_id]
    )
  end

  # 発行済みメッセージを削除（クリーンアップ用）
  def delete_published(older_than: Time.now - 7 * 24 * 60 * 60)
    result = @connection.exec_params(
      'DELETE FROM outbox
       WHERE published = TRUE AND published_at < $1',
      [older_than]
    )

    result.cmd_tuples
  end

  # 統計情報
  def stats
    result = @connection.exec(
      'SELECT
         COUNT(*) as total,
         COUNT(CASE WHEN published = FALSE THEN 1 END) as unpublished,
         COUNT(CASE WHEN published = TRUE THEN 1 END) as published,
         MAX(retry_count) as max_retries
       FROM outbox'
    )

    result[0]
  end

  # 特定のAggregateのメッセージを取得
  def fetch_by_aggregate(aggregate_id, limit: 100)
    result = @connection.exec_params(
      'SELECT * FROM outbox
       WHERE aggregate_id = $1
       ORDER BY created_at ASC
       LIMIT $2',
      [aggregate_id, limit]
    )

    result.map { |row| OutboxMessage.new(row) }
  end
end
