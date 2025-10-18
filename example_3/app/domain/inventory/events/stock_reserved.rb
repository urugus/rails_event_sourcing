module Inventory
  module Events
    class StockReserved
      EVENT_TYPE = "inventory.stock_reserved".freeze

      attr_reader :product_id, :quantity, :reservation_id, :reserved_at, :expires_at

      def self.event_type
        EVENT_TYPE
      end

      def initialize(product_id:, quantity:, reservation_id:, reserved_at:, expires_at:)
        @product_id = product_id
        @quantity = quantity
        @reservation_id = reservation_id
        @reserved_at = reserved_at
        @expires_at = expires_at
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "product_id" => product_id,
          "quantity" => quantity,
          "reservation_id" => reservation_id,
          "reserved_at" => reserved_at.iso8601,
          "expires_at" => expires_at.iso8601
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          product_id: record.aggregate_id,
          quantity: data.fetch("quantity"),
          reservation_id: data.fetch("reservation_id"),
          reserved_at: Time.parse(data.fetch("reserved_at")),
          expires_at: Time.parse(data.fetch("expires_at"))
        )
      end
    end
  end
end
