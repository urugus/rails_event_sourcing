module Inventory
  module Events
    class StockAdded
      EVENT_TYPE = "inventory.stock_added".freeze

      attr_reader :product_id, :quantity, :added_at

      def self.event_type
        EVENT_TYPE
      end

      def initialize(product_id:, quantity:, added_at:)
        @product_id = product_id
        @quantity = quantity
        @added_at = added_at
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "product_id" => product_id,
          "quantity" => quantity,
          "added_at" => added_at.iso8601
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          product_id: record.aggregate_id,
          quantity: data.fetch("quantity"),
          added_at: Time.parse(data.fetch("added_at"))
        )
      end
    end
  end
end
