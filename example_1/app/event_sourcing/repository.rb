# frozen_string_literal: true

module EventSourcing
  # 集約のリポジトリ
  # イベントストアとやり取りして集約の保存・読み込みを行う
  class Repository
    def initialize(event_store:, aggregate_class:)
      @event_store = event_store
      @aggregate_class = aggregate_class
    end

    # 集約を取得する
    # @param aggregate_id [String] 集約のID
    # @return [AggregateRoot] 集約のインスタンス
    def find(aggregate_id)
      events = @event_store.get_events(
        aggregate_id: aggregate_id,
        aggregate_type: @aggregate_class.name
      )

      if events.empty?
        return nil
      end

      aggregate = @aggregate_class.new(aggregate_id)
      aggregate.load_from_history(events)
      aggregate
    end

    # 集約を保存する
    # @param aggregate [AggregateRoot] 集約のインスタンス
    def save(aggregate)
      return if aggregate.uncommitted_events.empty?

      @event_store.save_events(
        aggregate_id: aggregate.id,
        aggregate_type: @aggregate_class.name,
        events: aggregate.uncommitted_events,
        expected_version: aggregate.version
      )

      aggregate.mark_events_as_committed
    end
  end
end
