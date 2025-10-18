module EventSourcing
  class EventStore
    ConcurrentWriteError = Class.new(StandardError)
    UnknownEventTypeError = Class.new(StandardError)

    def initialize(event_mappings:, clock: -> { Time.current })
      @event_mappings = event_mappings
      @clock = clock
    end

    def load_stream(aggregate_id:, aggregate_type:)
      EventRecord
        .for_aggregate(aggregate_id: aggregate_id, aggregate_type: aggregate_type)
        .order(:version)
        .map { |record| deserialize(record) }
    end

    def append_to_stream(aggregate_id:, aggregate_type:, events:, expected_version:)
      return [] if events.empty?

      persisted_events = []

      EventRecord.transaction do
        current_version = current_version_for(aggregate_id:, aggregate_type:)
        if current_version != expected_version
          raise ConcurrentWriteError, "expected version #{expected_version}, but found #{current_version}"
        end

        events.each_with_index do |event, index|
          version = expected_version + index + 1
          record = EventRecord.create!(
            aggregate_id: aggregate_id,
            aggregate_type: aggregate_type,
            event_type: event.event_type,
            data: event.as_json,
            occurred_at: @clock.call,
            version: version
          )
          persisted_events << deserialize(record)
        end
      end

      persisted_events
    end

    private

    def deserialize(record)
      mapping = @event_mappings[record.event_type]
      unless mapping
        raise UnknownEventTypeError, "no mapping registered for #{record.event_type}"
      end
      mapping.call(record)
    end

    def current_version_for(aggregate_id:, aggregate_type:)
      EventRecord.for_aggregate(aggregate_id:, aggregate_type:).maximum(:version) || 0
    end

  end
end
