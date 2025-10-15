# frozen_string_literal: true

class Transaction < ApplicationRecord
  belongs_to :account

  TYPES = %w[deposit withdraw].freeze

  validates :transaction_type, presence: true, inclusion: { in: TYPES }
  validates :amount, numericality: { greater_than: 0 }
  validates :balance_after, numericality: { greater_than_or_equal_to: 0 }
  validates :executed_at, presence: true

  scope :recent, -> { order(executed_at: :desc) }
  scope :deposits, -> { where(transaction_type: 'deposit') }
  scope :withdrawals, -> { where(transaction_type: 'withdraw') }

  before_validation :set_executed_at, on: :create

  private

  def set_executed_at
    self.executed_at ||= Time.current
  end
end
