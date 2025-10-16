# frozen_string_literal: true

module EventSourcing
  # ActiveRecord版のイベントストア
  # PostgreSQLなどのDBにイベントを永続化する
  class ArEventStore
    def initialize
      @subscribers = []
    end

    # イベントを保存する
    # @param aggregate_id [String] 集約のID
    # @param aggregate_type [String] 集約のタイプ
    # @param events [Array<Event>] 保存するイベントのリスト
    # @param expected_version [Integer] 期待されるバージョン（楽観的ロック用）
    def save_events(aggregate_id:, aggregate_type:, events:, expected_version:)
      ActiveRecord::Base.transaction do
        current_version = get_current_version(aggregate_id, aggregate_type)

        if current_version != expected_version
          raise ConcurrencyError, "Expected version #{expected_version} but was #{current_version}"
        end

        events.each_with_index do |event, index|
          event_record = EventRecord.create!(
            aggregate_id: aggregate_id,
            aggregate_type: aggregate_type,
            event_type: event.class.name,
            event_data: event.to_h,
            version: expected_version + index + 1,
            occurred_at: Time.current
          )

          # イベントを購読者に通知
          notify_subscribers(event, event_record)
        end
      end
    end

    # 集約のイベントストリームを取得する
    # @param aggregate_id [String] 集約のID
    # @param aggregate_type [String] 集約のタイプ
    # @return [Array<Hash>] イベントレコードのリスト
    def get_events(aggregate_id:, aggregate_type:)
      EventRecord
        .where(aggregate_id: aggregate_id, aggregate_type: aggregate_type)
        .order(:version)
        .map { |record| record_to_hash(record) }
    end

    # すべてのイベントを取得する
    # @return [Array<Hash>] すべてのイベントレコード
    def all_events
      EventRecord
        .order(:occurred_at)
        .map { |record| record_to_hash(record) }
    end

    # イベント購読者を登録する
    # @param subscriber [Proc] イベントを受け取るコールバック
    def subscribe(&subscriber)
      @subscribers << subscriber
    end

    private

    # 現在のバージョンを取得する
    def get_current_version(aggregate_id, aggregate_type)
      EventRecord
        .where(aggregate_id: aggregate_id, aggregate_type: aggregate_type)
        .maximum(:version) || 0
    end

    # 購読者に通知する
    def notify_subscribers(event, event_record)
      @subscribers.each do |subscriber|
        subscriber.call(event, record_to_hash(event_record))
      end
    end

    # レコードをハッシュに変換
    def record_to_hash(record)
      {
        aggregate_id: record.aggregate_id,
        aggregate_type: record.aggregate_type,
        event_type: record.event_type,
        event_data: record.event_data,
        version: record.version,
        occurred_at: record.occurred_at
      }
    end

    class ConcurrencyError < StandardError; end

    # ActiveRecordモデル
    class EventRecord < ApplicationRecord
      self.table_name = "events"

      validates :aggregate_id, presence: true
      validates :aggregate_type, presence: true
      validates :event_type, presence: true
      validates :event_data, presence: true
      validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :occurred_at, presence: true

      # 集約とバージョンの組み合わせは一意
      validates :version, uniqueness: { scope: [:aggregate_id, :aggregate_type] }
    end
  end
end
