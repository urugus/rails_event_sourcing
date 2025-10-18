module Inventory
  module EventMappings
    EVENT_TYPE_TO_CLASS = {
      "inventory.stock_added" => Events::StockAdded,
      "inventory.stock_reserved" => Events::StockReserved,
      "inventory.reservation_confirmed" => Events::ReservationConfirmed,
      "inventory.reservation_cancelled" => Events::ReservationCancelled,
      "inventory.reservation_expired" => Events::ReservationExpired
    }.freeze

    def self.event_class_for(event_type)
      EVENT_TYPE_TO_CLASS.fetch(event_type) do
        raise ArgumentError, "unknown event type: #{event_type}"
      end
    end

    def self.deserialize(record)
      event_class = event_class_for(record.event_type)
      event_class.from_record(record)
    end

    def self.build
      {
        Events::StockAdded.event_type => lambda do |record|
          Events::StockAdded.from_record(record)
        end,
        Events::StockReserved.event_type => lambda do |record|
          Events::StockReserved.from_record(record)
        end,
        Events::ReservationConfirmed.event_type => lambda do |record|
          Events::ReservationConfirmed.from_record(record)
        end,
        Events::ReservationCancelled.event_type => lambda do |record|
          Events::ReservationCancelled.from_record(record)
        end,
        Events::ReservationExpired.event_type => lambda do |record|
          Events::ReservationExpired.from_record(record)
        end
      }
    end
  end
end
