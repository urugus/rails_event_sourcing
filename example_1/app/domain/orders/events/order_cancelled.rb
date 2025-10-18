require "time"

module Orders
  module Events
    class OrderCancelled
      EVENT_TYPE = "orders.order_cancelled".freeze

      attr_reader :order_id, :reason, :cancelled_at

      def self.event_type
        EVENT_TYPE
      end

      def initialize(order_id:, reason:, cancelled_at:)
        @order_id = order_id
        @reason = reason
        @cancelled_at = cancelled_at
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "order_id" => order_id,
          "reason" => reason,
          "cancelled_at" => cancelled_at.iso8601
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          order_id: record.aggregate_id,
          reason: data.fetch("reason"),
          cancelled_at: Time.iso8601(data.fetch("cancelled_at"))
        )
      end
    end
  end
end
