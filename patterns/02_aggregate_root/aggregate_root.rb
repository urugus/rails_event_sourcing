# frozen_string_literal: true

# Aggregate Rootの基底モジュール
# イベントソーシングのための基本機能を提供
module AggregateRoot
  # イベントハンドラの登録
  def self.included(base)
    base.extend(ClassMethods)
    base.class_eval do
      @event_handlers = {}
    end
  end

  module ClassMethods
    # イベントハンドラを登録
    # 例: on OrderCreated do |event| ... end
    def on(event_class, &block)
      @event_handlers ||= {}
      @event_handlers[event_class] = block
    end

    # 登録されたイベントハンドラを取得
    def event_handlers
      @event_handlers || {}
    end
  end

  def initialize
    @uncommitted_events = []
    @version = 0
  end

  # 未コミットのイベントリスト
  def uncommitted_events
    @uncommitted_events
  end

  # 現在のバージョン
  def version
    @version
  end

  # イベントを適用（新しいイベント）
  # このメソッドはコマンドハンドラから呼ばれる
  def apply(event)
    # イベントを未コミットリストに追加
    @uncommitted_events << event

    # イベントハンドラを実行して状態を更新
    apply_event(event)
  end

  # イベントハンドラを実行（イベントの再生時にも使用）
  def apply_event(event)
    handler = self.class.event_handlers[event.class]

    if handler
      instance_exec(event, &handler)
      @version += 1
    else
      raise "No handler registered for #{event.class}"
    end
  end

  # すべてのイベントを適用（状態の復元）
  def load_from_history(events)
    events.each do |event_data|
      event = deserialize_event(event_data)
      apply_event(event)
    end
  end

  # 未コミットイベントをクリア（保存後に呼ばれる）
  def mark_events_as_committed
    @uncommitted_events.clear
  end

  private

  # イベントデータからイベントオブジェクトを復元
  def deserialize_event(event_data)
    event_type = event_data.event_type
    event_class = Object.const_get(event_type)
    event_class.from_data(event_data.data, event_data.metadata)
  rescue NameError
    raise "Unknown event type: #{event_type}"
  end
end

# ドメインイベントの基底クラス
class DomainEvent
  attr_reader :data, :metadata

  def initialize(**data)
    @data = data
    @metadata = {}
  end

  # イベント名（クラス名）
  def event_type
    self.class.name
  end

  # イベントをHash形式に変換
  def to_h
    {
      event_type: event_type,
      data: data,
      metadata: metadata
    }
  end

  # データからイベントオブジェクトを生成
  def self.from_data(data, metadata = {})
    event = allocate
    event.instance_variable_set(:@data, data.transform_keys(&:to_sym))
    event.instance_variable_set(:@metadata, metadata.transform_keys(&:to_sym))
    event
  end

  # データへのアクセス（シンボルキーでアクセス可能）
  def method_missing(method_name, *args)
    if @data.key?(method_name)
      @data[method_name]
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @data.key?(method_name) || super
  end
end
