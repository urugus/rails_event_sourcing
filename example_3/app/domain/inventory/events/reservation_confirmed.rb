module Inventory
  module Events
    class ReservationConfirmed
      EVENT_TYPE = "inventory.reservation_confirmed".freeze

      attr_reader :product_id, :reservation_id, :confirmed_at

      def self.event_type
        EVENT_TYPE
      end

      def initialize(product_id:, reservation_id:, confirmed_at:)
        @product_id = product_id
        @reservation_id = reservation_id
        @confirmed_at = confirmed_at
      end

      def event_type
        EVENT_TYPE
      end

      def as_json(*)
        {
          "product_id" => product_id,
          "reservation_id" => reservation_id,
          "confirmed_at" => confirmed_at.iso8601
        }
      end

      def self.from_record(record)
        data = record.data || {}
        new(
          product_id: record.aggregate_id,
          reservation_id: data.fetch("reservation_id"),
          confirmed_at: Time.parse(data.fetch("confirmed_at"))
        )
      end
    end
  end
end
