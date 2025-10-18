class OrderSummaryReadModel < ApplicationRecord
  self.table_name = "order_summary_read_models"

  validates :order_id, presence: true
  validates :status, presence: true
  validates :total_amount_cents, presence: true
  validates :item_count, presence: true
end
