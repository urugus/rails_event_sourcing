# frozen_string_literal: true

module Domain
  # Aggregate を Event Store から読み込み・保存する Repository
  class Repository
    def initialize(event_store)
      @event_store = event_store
    end

    # Aggregate を読み込む
    def load(aggregate_id, aggregate_class)
      stream_name = stream_name_for(aggregate_class, aggregate_id)
      events = @event_store.get_stream(stream_name)

      aggregate = aggregate_class.new(aggregate_id)
      aggregate.load_from_history(events)
      aggregate
    end

    # Aggregate を保存する
    def save(aggregate, aggregate_class)
      return if aggregate.uncommitted_events.empty?

      stream_name = stream_name_for(aggregate_class, aggregate.id)
      @event_store.append(stream_name, aggregate.uncommitted_events)
      aggregate.mark_changes_as_committed
    end

    # Aggregate の存在確認
    def exists?(aggregate_id, aggregate_class)
      stream_name = stream_name_for(aggregate_class, aggregate_id)
      @event_store.stream_exists?(stream_name)
    end

    private

    def stream_name_for(aggregate_class, aggregate_id)
      "#{aggregate_class.name.split('::').last}-#{aggregate_id}"
    end
  end
end
