# frozen_string_literal: true

module Queries
  class GetAccountHistory
    def call(account_number:, limit: 100)
      account = AccountBalance.find_by(account_number: account_number)
      return { success: false, error: "口座が見つかりません" } unless account

      history = account.transaction_history || []

      {
        success: true,
        account_number: account.account_number,
        current_balance: account.current_balance,
        transactions: history.last(limit)
      }
    end
  end
end
