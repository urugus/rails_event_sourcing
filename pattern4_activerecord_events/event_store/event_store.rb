# frozen_string_literal: true

require_relative 'domain_event_model'

module EventStore
  # ActiveRecord を使った Event Store 実装
  class ActiveRecordEventStore
    def initialize
      @subscribers = []
    end

    # イベントを保存
    def append(stream_name, events)
      events = Array(events)

      ActiveRecord::Base.transaction do
        last_version = DomainEventModel.where(stream_name: stream_name).maximum(:stream_version) || 0

        events.each_with_index do |event, index|
          version = last_version + index + 1

          DomainEventModel.create!(
            event_id: event.event_id,
            event_type: event.class.name.split('::').last,
            stream_name: stream_name,
            stream_version: version,
            aggregate_id: event.aggregate_id,
            data: event.data,
            metadata: event.metadata,
            occurred_at: event.occurred_at
          )
        end
      end

      # イベント発行後、購読者に通知
      events.each do |event|
        notify_subscribers(event)
      end

      events.size
    end

    # ストリームからイベントを取得
    def get_stream(stream_name)
      records = DomainEventModel.for_stream(stream_name)
      records.map { |record| deserialize_event(record) }
    end

    # Aggregate からイベントを取得
    def get_events_for_aggregate(aggregate_id)
      records = DomainEventModel.for_aggregate(aggregate_id)
      records.map { |record| deserialize_event(record) }
    end

    # 特定バージョン以降のイベントを取得
    def get_stream_from_version(stream_name, from_version)
      records = DomainEventModel.for_stream(stream_name)
                                .where('stream_version >= ?', from_version)
      records.map { |record| deserialize_event(record) }
    end

    # イベント購読
    def subscribe(handler, event_types: nil)
      @subscribers << { handler: handler, event_types: event_types }
    end

    # ストリームの存在確認
    def stream_exists?(stream_name)
      DomainEventModel.exists?(stream_name: stream_name)
    end

    # 全イベント数
    def event_count
      DomainEventModel.count
    end

    private

    def deserialize_event(record)
      # イベントクラスを動的に取得
      event_class_name = "Domain::Events::#{record.event_type}"

      # シンプルなイベントオブジェクトとして返す
      OpenStruct.new(
        event_id: record.event_id,
        event_type: record.event_type,
        aggregate_id: record.aggregate_id,
        data: record.data.symbolize_keys,
        metadata: record.metadata&.symbolize_keys || {},
        occurred_at: record.occurred_at,
        stream_version: record.stream_version
      )
    end

    def notify_subscribers(event)
      @subscribers.each do |subscriber|
        event_types = subscriber[:event_types]

        # イベントタイプのフィルタリング
        if event_types.nil? || event_types.include?(event.class)
          subscriber[:handler].call(event)
        end
      end
    end
  end
end
