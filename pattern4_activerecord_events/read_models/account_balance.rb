# frozen_string_literal: true

# Read Model: クエリ用の非正規化されたデータ
class AccountBalance < ApplicationRecord
  has_many :account_transactions, dependent: :destroy

  validates :account_number, presence: true, uniqueness: true
  validates :owner_name, presence: true
  validates :current_balance, numericality: { greater_than_or_equal_to: 0 }
  validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
