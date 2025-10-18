module Projections
  module Models
    class ProjectionError < ApplicationRecord
      self.table_name = "projection_errors"

      validates :projector_name, presence: true
      validates :event_id, presence: true
      validates :event_type, presence: true
      validates :error_message, presence: true
      validates :retry_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      scope :pending_retry, -> { where("next_retry_at <= ?", Time.current).where("retry_count < ?", ProjectionManager::MAX_RETRY_COUNT) }
      scope :failed, -> { where("retry_count >= ?", ProjectionManager::MAX_RETRY_COUNT) }
      scope :for_projector, ->(projector_name) { where(projector_name: projector_name) }
    end
  end
end
