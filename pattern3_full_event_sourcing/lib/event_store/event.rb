# frozen_string_literal: true

module EventStore
  # イベント基底クラス（不変オブジェクト）
  class Event
    attr_reader :event_id, :event_type, :aggregate_id, :data, :metadata, :version, :created_at

    def initialize(event_id:, event_type:, aggregate_id:, data:, metadata: {}, version: 1, created_at: Time.now)
      @event_id = event_id
      @event_type = event_type
      @aggregate_id = aggregate_id
      @data = data.freeze
      @metadata = metadata.freeze
      @version = version
      @created_at = created_at
      freeze
    end

    def to_h
      {
        event_id: @event_id,
        event_type: @event_type,
        aggregate_id: @aggregate_id,
        data: @data,
        metadata: @metadata,
        version: @version,
        created_at: @created_at
      }
    end
  end
end
