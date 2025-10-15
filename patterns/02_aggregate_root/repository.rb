# frozen_string_literal: true

require_relative '../01_basic_event_store/event'
require_relative '../01_basic_event_store/event_store'
require_relative 'aggregate_root'

# Aggregateの永続化と復元を担当するリポジトリ
class Repository
  def initialize(event_store)
    @event_store = event_store
  end

  # Aggregateをイベントストリームから復元
  def load(aggregate_class, stream_id)
    events = @event_store.read_stream(stream_id)

    if events.empty?
      raise "Stream not found: #{stream_id}"
    end

    aggregate = aggregate_class.new
    aggregate.load_from_history(events)
    aggregate
  end

  # Aggregateをイベントストアに保存
  def save(aggregate, stream_id)
    uncommitted_events = aggregate.uncommitted_events

    return if uncommitted_events.empty?

    # 楽観的ロック: 期待バージョンは現在のバージョン - 未コミットイベント数
    expected_version = aggregate.version - uncommitted_events.size

    # イベントをEvent Storeに保存
    uncommitted_events.each do |domain_event|
      event = Event.new(
        stream_id: stream_id,
        event_type: domain_event.event_type,
        data: domain_event.data,
        metadata: domain_event.metadata
      )

      @event_store.append(event, expected_version: expected_version)
      expected_version = event.version
    end

    # 未コミットイベントをクリア
    aggregate.mark_events_as_committed
  end

  # Aggregateが存在するか確認
  def exists?(stream_id)
    @event_store.stream_exists?(stream_id)
  end

  # with_aggregateパターン: ブロック内でAggregateを操作し、自動保存
  def with_aggregate(aggregate_class, stream_id)
    aggregate = if exists?(stream_id)
                  load(aggregate_class, stream_id)
                else
                  aggregate_class.new
                end

    yield aggregate

    save(aggregate, stream_id)
    aggregate
  end
end
