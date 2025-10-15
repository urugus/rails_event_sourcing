# frozen_string_literal: true

module Domain
  module Events
    # イベント基底クラス
    class BaseEvent
      attr_reader :event_id, :aggregate_id, :data, :metadata, :occurred_at

      def initialize(event_id:, aggregate_id:, data:, metadata: {}, occurred_at: Time.current)
        @event_id = event_id
        @aggregate_id = aggregate_id
        @data = data.freeze
        @metadata = metadata.freeze
        @occurred_at = occurred_at
        freeze
      end

      def event_type
        self.class.name.split('::').last
      end

      def to_h
        {
          event_id: @event_id,
          event_type: event_type,
          aggregate_id: @aggregate_id,
          data: @data,
          metadata: @metadata,
          occurred_at: @occurred_at
        }
      end
    end
  end
end
