# frozen_string_literal: true

require_relative 'event'

module EventStore
  # シンプルなインメモリEvent Store実装
  class InMemoryEventStore
    def initialize
      @streams = {}
      @subscribers = []
    end

    # イベントを保存
    def append(stream_name, events)
      events = Array(events)
      @streams[stream_name] ||= []

      events.each do |event|
        @streams[stream_name] << event
        notify_subscribers(event)
      end

      events.size
    end

    # ストリームからイベントを取得
    def get_stream(stream_name)
      @streams[stream_name] || []
    end

    # 特定バージョン以降のイベントを取得
    def get_stream_from_version(stream_name, from_version)
      stream = get_stream(stream_name)
      stream.select { |event| event.version >= from_version }
    end

    # 全イベントを取得
    def all_events
      @streams.values.flatten
    end

    # イベント購読
    def subscribe(handler)
      @subscribers << handler
    end

    # ストリームの存在確認
    def stream_exists?(stream_name)
      @streams.key?(stream_name)
    end

    private

    def notify_subscribers(event)
      @subscribers.each do |subscriber|
        subscriber.call(event)
      end
    end
  end
end
