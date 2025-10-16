# frozen_string_literal: true

# Event Store用のActiveRecordモデル
# eventsテーブルにドメインイベントを保存する
class EventRecord < ApplicationRecord
  self.table_name = "events"

  # バリデーション
  validates :aggregate_id, presence: true
  validates :aggregate_type, presence: true
  validates :event_type, presence: true
  validates :event_data, presence: true
  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :occurred_at, presence: true

  # 集約とバージョンの組み合わせは一意（楽観的ロック）
  validates :version, uniqueness: { scope: [:aggregate_id, :aggregate_type] }
end
