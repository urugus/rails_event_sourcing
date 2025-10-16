# frozen_string_literal: true

module EventSourcing
  # 集約ルートの基底クラス
  class AggregateRoot
    attr_reader :id, :version, :uncommitted_events

    def initialize(id)
      @id = id
      @version = 0
      @uncommitted_events = []
    end

    # イベントストリームから集約を復元する
    def load_from_history(events)
      events.each do |event_record|
        event_class = Object.const_get(event_record[:event_type])
        event = event_class.from_h(event_record[:event_data])
        apply_event(event)
        @version = event_record[:version]
      end
    end

    # 未コミットのイベントをクリアする
    def mark_events_as_committed
      @uncommitted_events.clear
    end

    protected

    # イベントを適用する（サブクラスでオーバーライド）
    def apply_event(event)
      raise NotImplementedError, "Subclass must implement apply_event"
    end

    # イベントを記録する
    def record_event(event)
      apply_event(event)
      @uncommitted_events << event
    end
  end
end
