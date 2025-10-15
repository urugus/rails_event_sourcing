# frozen_string_literal: true

module Queries
  class GetAccountBalance
    def call(account_number:)
      account = AccountBalance.find_by(account_number: account_number)
      return { success: false, error: "口座が見つかりません" } unless account

      {
        success: true,
        account_number: account.account_number,
        owner_name: account.owner_name,
        balance: account.current_balance,
        version: account.version,
        last_transaction_at: account.last_transaction_at
      }
    end
  end
end
