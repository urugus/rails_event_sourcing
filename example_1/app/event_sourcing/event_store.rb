# frozen_string_literal: true

module EventSourcing
  # インメモリのイベントストア
  # イベントを保存し、集約IDごとにイベントストリームを管理する
  class EventStore
    def initialize
      @events = []
      @subscribers = []
    end

    # イベントを保存する
    # @param aggregate_id [String] 集約のID
    # @param aggregate_type [String] 集約のタイプ
    # @param events [Array<Event>] 保存するイベントのリスト
    # @param expected_version [Integer] 期待されるバージョン（楽観的ロック用）
    def save_events(aggregate_id:, aggregate_type:, events:, expected_version:)
      current_version = get_current_version(aggregate_id, aggregate_type)

      if current_version != expected_version
        raise ConcurrencyError, "Expected version #{expected_version} but was #{current_version}"
      end

      events.each_with_index do |event, index|
        event_record = {
          aggregate_id: aggregate_id,
          aggregate_type: aggregate_type,
          event_type: event.class.name,
          event_data: event.to_h,
          version: expected_version + index + 1,
          occurred_at: Time.current
        }
        @events << event_record

        # イベントを購読者に通知
        notify_subscribers(event, event_record)
      end
    end

    # 集約のイベントストリームを取得する
    # @param aggregate_id [String] 集約のID
    # @param aggregate_type [String] 集約のタイプ
    # @return [Array<Hash>] イベントレコードのリスト
    def get_events(aggregate_id:, aggregate_type:)
      @events.select do |e|
        e[:aggregate_id] == aggregate_id && e[:aggregate_type] == aggregate_type
      end.sort_by { |e| e[:version] }
    end

    # すべてのイベントを取得する
    # @return [Array<Hash>] すべてのイベントレコード
    def all_events
      @events.sort_by { |e| e[:occurred_at] }
    end

    # イベント購読者を登録する
    # @param subscriber [Proc] イベントを受け取るコールバック
    def subscribe(&subscriber)
      @subscribers << subscriber
    end

    # すべてのイベントをクリアする（テスト用）
    def clear!
      @events.clear
      @subscribers.clear
    end

    private

    # 現在のバージョンを取得する
    def get_current_version(aggregate_id, aggregate_type)
      events = get_events(aggregate_id: aggregate_id, aggregate_type: aggregate_type)
      events.empty? ? 0 : events.last[:version]
    end

    # 購読者に通知する
    def notify_subscribers(event, event_record)
      @subscribers.each do |subscriber|
        subscriber.call(event, event_record)
      end
    end

    class ConcurrencyError < StandardError; end
  end
end
