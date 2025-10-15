# frozen_string_literal: true

# Read Model: 取引履歴（非正規化）
class AccountTransaction < ApplicationRecord
  belongs_to :account_balance

  validates :event_id, presence: true
  validates :transaction_type, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :balance_after, numericality: { greater_than_or_equal_to: 0 }
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
end
