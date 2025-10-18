class OrderDetailsReadModel < ApplicationRecord
  self.table_name = "order_details_read_models"

  validates :order_id, presence: true
  validates :status, presence: true
  validates :total_amount_cents, presence: true
end
