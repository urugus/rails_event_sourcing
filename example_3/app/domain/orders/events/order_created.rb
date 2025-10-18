module Orders
  module Events
    class OrderCreated
      EVENT_TYPE = "orders.order_created".freeze

      attr_reader :order_id, :customer_name

      def self.event_type
        EVENT_TYPE
      end

      def initialize(order_id:, customer_name:)
        @order_id = order_id
        @customer_name = customer_name
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "order_id" => order_id,
          "customer_name" => customer_name
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          order_id: record.aggregate_id,
          customer_name: data.fetch("customer_name")
        )
      end
    end
  end
end
