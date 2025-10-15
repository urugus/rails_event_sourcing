# frozen_string_literal: true

# Read Model: クエリ用の非正規化されたデータ
class AccountBalance < ApplicationRecord
  validates :account_number, presence: true, uniqueness: true
  validates :owner_name, presence: true
  validates :current_balance, numericality: { greater_than_or_equal_to: 0 }

  # 履歴を JSON で保存（簡易的な実装）
  serialize :transaction_history, Array
end
