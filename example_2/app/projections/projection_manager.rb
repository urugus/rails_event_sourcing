module Projections
  class ProjectionManager
    DEFAULT_BATCH_SIZE = 100
    MAX_RETRY_COUNT = 5
    RETRY_DELAYS = [1.minute, 5.minutes, 15.minutes, 1.hour, 6.hours].freeze

    def initialize(
      event_mappings:,
      projectors:,
      clock: -> { Time.current },
      batch_size: DEFAULT_BATCH_SIZE
    )
      @event_mappings = event_mappings
      @projectors = Array(projectors)
      @clock = clock
      @batch_size = batch_size
    end

    def call
      loop do
        processed = process_next_batch
        break if processed.zero?
      end
    end

    def retry_failed_projections
      ProjectionError.where("next_retry_at <= ?", @clock.call)
                      .where("retry_count < ?", MAX_RETRY_COUNT)
                      .find_each do |error_record|
        retry_projection(error_record)
      end
    end

    private

    attr_reader :event_mappings, :projectors, :clock, :batch_size

    def process_next_batch
      EventRecord.transaction do
        records = fetch_next_batch
        return 0 if records.empty?

        records.each do |record|
          process_event_record(record)
        end

        records.size
      end
    end

    def fetch_next_batch
      min_position = projectors.map { |p| get_position(p) }.min || 0

      EventRecord.where("id > ?", min_position)
                 .order(:id)
                 .limit(batch_size)
                 .lock("FOR UPDATE SKIP LOCKED")
    end

    def process_event_record(record)
      event = deserialize(record)

      projectors.each do |projector|
        next unless should_process?(projector, record, event)

        begin
          project_with_tracking(projector, record, event)
        rescue StandardError => e
          record_error(projector, record, event, e)
        end
      end
    end

    def should_process?(projector, record, event)
      # Check if projector subscribes to this event type
      return false unless projector.subscribes_to?(event.class)

      # Check if already processed
      position = get_position(projector)
      record.id > position
    end

    def project_with_tracking(projector, record, event)
      projector.project(event)
      update_position(projector, record.id)
      clear_error(projector, record.id) if had_error?(projector, record.id)
    end

    def get_position(projector)
      ProjectionPosition.find_or_create_by(
        projector_name: projector.class.projector_name
      ).last_event_id || 0
    end

    def update_position(projector, event_id)
      position = ProjectionPosition.find_or_create_by(
        projector_name: projector.class.projector_name
      )
      position.update!(
        last_event_id: event_id,
        last_processed_at: clock.call
      )
    end

    def record_error(projector, record, event, error)
      error_record = ProjectionError.find_or_initialize_by(
        projector_name: projector.class.projector_name,
        event_id: record.id
      )

      error_record.assign_attributes(
        event_type: event.class.to_s,
        error_message: "#{error.class}: #{error.message}",
        error_backtrace: error.backtrace&.first(10)&.join("\n"),
        retry_count: error_record.retry_count.to_i + 1,
        next_retry_at: calculate_next_retry(error_record.retry_count.to_i),
        last_error_at: clock.call
      )

      error_record.save!

      Rails.logger.error(
        "[ProjectionManager] Error in #{projector.class.projector_name} " \
        "for event #{record.id} (#{event.class}): #{error.message}"
      )
    end

    def calculate_next_retry(current_count)
      delay = RETRY_DELAYS[current_count] || RETRY_DELAYS.last
      clock.call + delay
    end

    def had_error?(projector, event_id)
      ProjectionError.exists?(
        projector_name: projector.class.projector_name,
        event_id: event_id
      )
    end

    def clear_error(projector, event_id)
      ProjectionError.where(
        projector_name: projector.class.projector_name,
        event_id: event_id
      ).delete_all
    end

    def retry_projection(error_record)
      record = EventRecord.find_by(id: error_record.event_id)
      return unless record

      event = deserialize(record)
      projector = projectors.find { |p| p.class.projector_name == error_record.projector_name }
      return unless projector

      EventRecord.transaction do
        project_with_tracking(projector, record, event)
      end
    rescue StandardError => e
      # Update retry information
      error_record.update!(
        retry_count: error_record.retry_count + 1,
        next_retry_at: calculate_next_retry(error_record.retry_count),
        last_error_at: clock.call,
        error_message: "#{e.class}: #{e.message}"
      )
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
