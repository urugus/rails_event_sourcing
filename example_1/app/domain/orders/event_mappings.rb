module Orders
  module EventMappings
    def self.build
      {
        Events::OrderCreated.event_type => lambda do |record|
          Events::OrderCreated.from_record(record)
        end,
        Events::ItemAdded.event_type => lambda do |record|
          Events::ItemAdded.from_record(record)
        end,
        Events::ItemRemoved.event_type => lambda do |record|
          Events::ItemRemoved.from_record(record)
        end,
        Events::OrderConfirmed.event_type => lambda do |record|
          Events::OrderConfirmed.from_record(record)
        end,
        Events::OrderCancelled.event_type => lambda do |record|
          Events::OrderCancelled.from_record(record)
        end,
        Events::OrderShipped.event_type => lambda do |record|
          Events::OrderShipped.from_record(record)
        end
      }
    end
  end
end
