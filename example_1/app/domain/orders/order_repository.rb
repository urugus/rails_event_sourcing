module Orders
  class OrderRepository
    AGGREGATE_TYPE = "Orders::Order".freeze

    def initialize(event_store:)
      @event_store = event_store
    end

    def load(order_id)
      events = @event_store.load_stream(
        aggregate_id: order_id,
        aggregate_type: AGGREGATE_TYPE
      )
      Order.new(id: order_id).load_from_history(events)
    end

    def store(order)
      new_events = order.pending_events
      return [] if new_events.empty?

      persisted_events = @event_store.append_to_stream(
        aggregate_id: order.id,
        aggregate_type: AGGREGATE_TYPE,
        events: new_events,
        expected_version: order.persisted_version
      )

      order.mark_events_persisted
      persisted_events
    end
  end
end
