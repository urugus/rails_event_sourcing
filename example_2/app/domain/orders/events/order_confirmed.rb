require "time"

module Orders
  module Events
    class OrderConfirmed
      EVENT_TYPE = "orders.order_confirmed".freeze

      attr_reader :order_id, :confirmed_at

      def self.event_type
        EVENT_TYPE
      end

      def initialize(order_id:, confirmed_at:)
        @order_id = order_id
        @confirmed_at = confirmed_at
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "order_id" => order_id,
          "confirmed_at" => confirmed_at.iso8601
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          order_id: record.aggregate_id,
          confirmed_at: Time.iso8601(data.fetch("confirmed_at"))
        )
      end
    end
  end
end
