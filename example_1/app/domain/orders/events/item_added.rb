module Orders
  module Events
    class ItemAdded
      EVENT_TYPE = "orders.item_added".freeze

      attr_reader :order_id, :product_name, :quantity, :unit_price_cents

      def self.event_type
        EVENT_TYPE
      end

      def initialize(order_id:, product_name:, quantity:, unit_price_cents:)
        @order_id = order_id
        @product_name = product_name
        @quantity = quantity
        @unit_price_cents = unit_price_cents
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "order_id" => order_id,
          "product_name" => product_name,
          "quantity" => quantity,
          "unit_price_cents" => unit_price_cents
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          order_id: record.aggregate_id,
          product_name: data.fetch("product_name"),
          quantity: data.fetch("quantity"),
          unit_price_cents: data.fetch("unit_price_cents")
        )
      end
    end
  end
end
