# frozen_string_literal: true

module EventHandlers
  # イベントを購読して Read Model を更新する Projector
  class AccountProjection
    def call(event)
      event_type = event.respond_to?(:event_type) ? event.event_type : event.class.name.split('::').last

      case event_type
      when 'AccountOpened'
        handle_account_opened(event)
      when 'MoneyDeposited'
        handle_money_deposited(event)
      when 'MoneyWithdrawn'
        handle_money_withdrawn(event)
      end
    end

    private

    def handle_account_opened(event)
      AccountBalance.create!(
        account_number: event.aggregate_id,
        owner_name: event.data[:owner_name],
        current_balance: event.data[:initial_balance],
        version: 1,
        last_transaction_at: event.occurred_at
      )

      if event.data[:initial_balance] > 0
        account = AccountBalance.find_by!(account_number: event.aggregate_id)
        AccountTransaction.create!(
          account_balance: account,
          event_id: event.event_id,
          transaction_type: 'initial_deposit',
          amount: event.data[:initial_balance],
          balance_after: event.data[:initial_balance],
          description: '口座開設時の初期入金',
          occurred_at: event.occurred_at
        )
      end
    end

    def handle_money_deposited(event)
      account = AccountBalance.find_by!(account_number: event.aggregate_id)

      new_balance = account.current_balance + event.data[:amount]

      account.update!(
        current_balance: new_balance,
        version: account.version + 1,
        last_transaction_at: event.occurred_at
      )

      AccountTransaction.create!(
        account_balance: account,
        event_id: event.event_id,
        transaction_type: 'deposit',
        amount: event.data[:amount],
        balance_after: new_balance,
        description: event.data[:description],
        occurred_at: event.occurred_at
      )
    end

    def handle_money_withdrawn(event)
      account = AccountBalance.find_by!(account_number: event.aggregate_id)

      new_balance = account.current_balance - event.data[:amount]

      account.update!(
        current_balance: new_balance,
        version: account.version + 1,
        last_transaction_at: event.occurred_at
      )

      AccountTransaction.create!(
        account_balance: account,
        event_id: event.event_id,
        transaction_type: 'withdraw',
        amount: event.data[:amount],
        balance_after: new_balance,
        description: event.data[:description],
        occurred_at: event.occurred_at
      )
    end
  end
end
