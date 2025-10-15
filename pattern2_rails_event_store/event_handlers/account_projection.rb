# frozen_string_literal: true

module EventHandlers
  # イベントを購読してRead Modelを更新するProjector
  class AccountProjection
    def call(event)
      case event
      when Events::AccountOpened
        handle_account_opened(event)
      when Events::MoneyDeposited
        handle_money_deposited(event)
      when Events::MoneyWithdrawn
        handle_money_withdrawn(event)
      end
    end

    private

    def handle_account_opened(event)
      AccountBalance.create!(
        account_number: event.data[:account_number],
        owner_name: event.data[:owner_name],
        current_balance: event.data[:initial_balance],
        transaction_history: [
          {
            type: 'opened',
            amount: event.data[:initial_balance],
            timestamp: event.metadata[:timestamp],
            event_id: event.event_id
          }
        ],
        last_transaction_at: event.metadata[:timestamp]
      )
    end

    def handle_money_deposited(event)
      account = AccountBalance.find_by!(account_number: event.data[:account_number])

      new_balance = account.current_balance + event.data[:amount]
      history = account.transaction_history || []
      history << {
        type: 'deposit',
        amount: event.data[:amount],
        description: event.data[:description],
        balance_after: new_balance,
        timestamp: event.metadata[:timestamp],
        event_id: event.event_id
      }

      account.update!(
        current_balance: new_balance,
        transaction_history: history,
        last_transaction_at: event.metadata[:timestamp]
      )
    end

    def handle_money_withdrawn(event)
      account = AccountBalance.find_by!(account_number: event.data[:account_number])

      new_balance = account.current_balance - event.data[:amount]
      history = account.transaction_history || []
      history << {
        type: 'withdraw',
        amount: event.data[:amount],
        description: event.data[:description],
        balance_after: new_balance,
        timestamp: event.metadata[:timestamp],
        event_id: event.event_id
      }

      account.update!(
        current_balance: new_balance,
        transaction_history: history,
        last_transaction_at: event.metadata[:timestamp]
      )
    end
  end
end
