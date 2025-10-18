module Projections
  class EventProjectionRunner
    DEFAULT_BATCH_SIZE = 100

    def initialize(event_mappings:, projector_runner:, clock: -> { Time.current }, batch_size: DEFAULT_BATCH_SIZE)
      @event_mappings = event_mappings
      @projector_runner = projector_runner
      @clock = clock
      @batch_size = batch_size
    end

    def call
      loop do
        processed = process_next_batch
        break if processed.zero?
      end
    end

    private

    attr_reader :event_mappings, :projector_runner, :clock, :batch_size

    def process_next_batch
      EventRecord.transaction do
        records = fetch_locked_batch
        if records.empty?
          0
        else
          records.each do |record|
            event = deserialize(record)
            projector_runner.call(event)
            record.mark_projected!(clock.call)
          end
          records.size
        end
      end
    end

    def fetch_locked_batch
      EventRecord.pending_projection
                 .order(:id)
                 .limit(batch_size)
                 .lock("FOR UPDATE SKIP LOCKED")
    end

    def deserialize(record)
      mapping = event_mappings[record.event_type]
      unless mapping
        raise EventSourcing::EventStore::UnknownEventTypeError,
              "no mapping registered for #{record.event_type}"
      end
      mapping.call(record)
    end
  end
end
