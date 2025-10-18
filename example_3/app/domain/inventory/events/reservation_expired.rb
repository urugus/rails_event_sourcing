module Inventory
  module Events
    class ReservationExpired
      EVENT_TYPE = "inventory.reservation_expired".freeze

      attr_reader :product_id, :reservation_id, :quantity, :expired_at

      def self.event_type
        EVENT_TYPE
      end

      def initialize(product_id:, reservation_id:, quantity:, expired_at:)
        @product_id = product_id
        @reservation_id = reservation_id
        @quantity = quantity
        @expired_at = expired_at
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "product_id" => product_id,
          "reservation_id" => reservation_id,
          "quantity" => quantity,
          "expired_at" => expired_at.iso8601
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          product_id: record.aggregate_id,
          reservation_id: data.fetch("reservation_id"),
          quantity: data.fetch("quantity"),
          expired_at: Time.parse(data.fetch("expired_at"))
        )
      end
    end
  end
end
