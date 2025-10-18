require "time"

module Orders
  module Events
    class OrderShipped
      EVENT_TYPE = "orders.order_shipped".freeze

      attr_reader :order_id, :tracking_number, :shipped_at

      def self.event_type
        EVENT_TYPE
      end

      def initialize(order_id:, tracking_number:, shipped_at:)
        @order_id = order_id
        @tracking_number = tracking_number
        @shipped_at = shipped_at
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "order_id" => order_id,
          "tracking_number" => tracking_number,
          "shipped_at" => shipped_at.iso8601
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          order_id: record.aggregate_id,
          tracking_number: data.fetch("tracking_number"),
          shipped_at: Time.iso8601(data.fetch("shipped_at"))
        )
      end
    end
  end
end
