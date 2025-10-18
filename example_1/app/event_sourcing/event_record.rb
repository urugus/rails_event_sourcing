class EventRecord < ApplicationRecord
  self.table_name = "event_records"

  validates :aggregate_id, presence: true
  validates :aggregate_type, presence: true
  validates :event_type, presence: true
  validates :version, presence: true
  validates :occurred_at, presence: true

  scope :for_aggregate, lambda { |aggregate_id:, aggregate_type:|
    where(aggregate_id: aggregate_id, aggregate_type: aggregate_type)
  }
  scope :pending_projection, -> { where(projected_at: nil) }

  def mark_projected!(timestamp = Time.current)
    update!(projected_at: timestamp)
  end
end
