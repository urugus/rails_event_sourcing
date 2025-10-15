# frozen_string_literal: true

module Queries
  class GetTransactionHistory
    def call(account_number:, limit: 100, offset: 0)
      account = AccountBalance.find_by(account_number: account_number)
      return { success: false, error: "口座が見つかりません" } unless account

      transactions = account.account_transactions
                            .recent
                            .limit(limit)
                            .offset(offset)

      {
        success: true,
        account_number: account.account_number,
        current_balance: account.current_balance,
        transactions: transactions.map do |t|
          {
            event_id: t.event_id,
            type: t.transaction_type,
            amount: t.amount,
            balance_after: t.balance_after,
            description: t.description,
            occurred_at: t.occurred_at
          }
        end
      }
    end
  end
end
