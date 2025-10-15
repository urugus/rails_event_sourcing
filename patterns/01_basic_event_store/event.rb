# frozen_string_literal: true

require 'json'
require 'time'

# イベントを表すドメインモデル
# Event Sourcingにおいて、イベントは不変のファクト（事実）を表現する
class Event
  attr_reader :id, :stream_id, :version, :event_type, :data, :metadata, :created_at

  def initialize(id: nil, stream_id:, version: nil, event_type:, data:, metadata: {}, created_at: nil)
    @id = id
    @stream_id = stream_id
    @version = version
    @event_type = event_type
    @data = data
    @metadata = metadata
    @created_at = created_at || Time.now
  end

  # イベントをHash形式に変換（データベース保存用）
  def to_h
    {
      id: id,
      stream_id: stream_id,
      version: version,
      event_type: event_type,
      data: data.to_json,
      metadata: metadata.to_json,
      created_at: created_at
    }
  end

  # データベースレコードからEventオブジェクトを生成
  def self.from_db(record)
    new(
      id: record['id'],
      stream_id: record['stream_id'],
      version: record['version'],
      event_type: record['event_type'],
      data: JSON.parse(record['data']),
      metadata: JSON.parse(record['metadata']),
      created_at: Time.parse(record['created_at'])
    )
  end

  # イベントの文字列表現
  def to_s
    "[#{event_type}] stream_id=#{stream_id} version=#{version} data=#{data}"
  end

  # イベントの比較（テスト用）
  def ==(other)
    other.is_a?(Event) &&
      stream_id == other.stream_id &&
      version == other.version &&
      event_type == other.event_type &&
      data == other.data
  end
end
