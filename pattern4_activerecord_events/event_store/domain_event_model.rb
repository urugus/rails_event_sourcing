# frozen_string_literal: true

# ActiveRecord モデル: イベントの永続化
class DomainEventModel < ApplicationRecord
  self.table_name = 'domain_events'

  validates :event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :stream_name, presence: true
  validates :stream_version, presence: true, numericality: { only_integer: true }
  validates :aggregate_id, presence: true
  validates :data, presence: true
  validates :occurred_at, presence: true

  scope :for_stream, ->(stream_name) { where(stream_name: stream_name).order(:stream_version) }
  scope :for_aggregate, ->(aggregate_id) { where(aggregate_id: aggregate_id).order(:occurred_at) }
  scope :of_type, ->(event_type) { where(event_type: event_type) }
  scope :recent, -> { order(occurred_at: :desc) }
end
