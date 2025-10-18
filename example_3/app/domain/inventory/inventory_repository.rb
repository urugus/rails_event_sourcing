module Inventory
  class InventoryRepository
    AGGREGATE_TYPE = "Inventory".freeze

    def initialize(event_store:)
      @event_store = event_store
    end

    def load(product_id)
      event_records = event_store.load_events(aggregate_id: product_id, aggregate_type: AGGREGATE_TYPE)
      events = event_records.map { |record| EventMappings.deserialize(record) }

      inventory = Inventory.new(product_id: product_id)
      inventory.load_from_history(events)
      inventory
    end

    def store(inventory)
      return if inventory.pending_events.empty?

      events_data = inventory.pending_events.map do |event|
        {
          aggregate_id: inventory.product_id,
          aggregate_type: AGGREGATE_TYPE,
          event_type: event.event_type,
          data: event.as_json
        }
      end

      event_store.append_events(
        aggregate_id: inventory.product_id,
        aggregate_type: AGGREGATE_TYPE,
        events: events_data,
        expected_version: inventory.persisted_version
      )

      inventory.mark_events_persisted
    end

    private

    attr_reader :event_store
  end
end
