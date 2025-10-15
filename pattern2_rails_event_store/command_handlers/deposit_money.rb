# frozen_string_literal: true

module CommandHandlers
  class DepositMoney
    def initialize(event_store: Rails.configuration.event_store)
      @event_store = event_store
      @repository = AggregateRoot::Repository.new(@event_store)
    end

    def call(account_number:, amount:, description: nil)
      stream_name = "Account$#{account_number}"

      @repository.with_aggregate(Aggregates::Account, stream_name) do |account|
        account.deposit(
          amount: amount,
          description: description
        )
      end

      { success: true, account_number: account_number, amount: amount }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end
end
