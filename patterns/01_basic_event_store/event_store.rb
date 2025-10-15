# frozen_string_literal: true

require 'pg'
require_relative 'event'

# Event Storeの実装
# イベントの永続化と取得を担当するサービスクラス
class EventStore
  class ConcurrencyError < StandardError; end
  class StreamNotFoundError < StandardError; end

  def initialize(connection)
    @connection = connection
  end

  # ストリームにイベントを追加
  # expected_version: 楽観的ロック用の期待バージョン（nilの場合はチェックなし）
  def append(event, expected_version: nil)
    # 現在のストリームバージョンを取得
    current_version = get_stream_version(event.stream_id)

    # 楽観的ロックチェック
    if expected_version && current_version != expected_version
      raise ConcurrencyError,
            "Expected version #{expected_version} but current is #{current_version}"
    end

    # 次のバージョン番号を設定
    event.instance_variable_set(:@version, current_version + 1)

    # イベントをデータベースに保存
    result = @connection.exec_params(
      'INSERT INTO events (stream_id, version, event_type, data, metadata, created_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id',
      [
        event.stream_id,
        event.version,
        event.event_type,
        event.data.to_json,
        event.metadata.to_json,
        event.created_at
      ]
    )

    event.instance_variable_set(:@id, result[0]['id'].to_i)
    event
  rescue PG::UniqueViolation
    # UNIQUE制約違反 = 並行更新の競合
    raise ConcurrencyError, "Concurrent modification detected for stream #{event.stream_id}"
  end

  # 複数のイベントを一括追加（トランザクション内）
  def append_batch(events, expected_version: nil)
    return [] if events.empty?

    stream_id = events.first.stream_id

    # すべてのイベントが同じストリームに属することを確認
    unless events.all? { |e| e.stream_id == stream_id }
      raise ArgumentError, 'All events must belong to the same stream'
    end

    @connection.transaction do
      events.map do |event|
        append(event, expected_version: expected_version)
        expected_version = event.version if expected_version
      end
    end
  end

  # ストリームからすべてのイベントを読み込み
  def read_stream(stream_id, from_version: 0)
    result = @connection.exec_params(
      'SELECT * FROM events WHERE stream_id = $1 AND version > $2 ORDER BY version ASC',
      [stream_id, from_version]
    )

    result.map { |record| Event.from_db(record) }
  end

  # ストリームの現在のバージョンを取得
  def get_stream_version(stream_id)
    result = @connection.exec_params(
      'SELECT MAX(version) as max_version FROM events WHERE stream_id = $1',
      [stream_id]
    )

    max_version = result[0]['max_version']
    max_version ? max_version.to_i : 0
  end

  # すべてのイベントを時系列順に取得（デバッグ・監査用）
  def read_all_events(limit: 100, offset: 0)
    result = @connection.exec_params(
      'SELECT * FROM events ORDER BY created_at ASC, id ASC LIMIT $1 OFFSET $2',
      [limit, offset]
    )

    result.map { |record| Event.from_db(record) }
  end

  # イベントタイプでフィルタリング
  def read_events_by_type(event_type, limit: 100)
    result = @connection.exec_params(
      'SELECT * FROM events WHERE event_type = $1 ORDER BY created_at ASC LIMIT $2',
      [event_type, limit]
    )

    result.map { |record| Event.from_db(record) }
  end

  # ストリームが存在するか確認
  def stream_exists?(stream_id)
    get_stream_version(stream_id) > 0
  end
end
