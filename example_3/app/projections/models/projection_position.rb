module Projections
  module Models
    class ProjectionPosition < ApplicationRecord
      self.table_name = "projection_positions"

      validates :projector_name, presence: true, uniqueness: true
      validates :last_event_id, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    end
  end
end
