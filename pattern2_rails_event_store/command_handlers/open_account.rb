# frozen_string_literal: true

module CommandHandlers
  class OpenAccount
    def initialize(event_store: Rails.configuration.event_store)
      @event_store = event_store
      @repository = AggregateRoot::Repository.new(@event_store)
    end

    def call(account_number:, owner_name:, initial_balance: 0)
      stream_name = "Account$#{account_number}"

      @repository.with_aggregate(Aggregates::Account, stream_name) do |account|
        account.open(
          owner_name: owner_name,
          initial_balance: initial_balance
        )
      end

      { success: true, account_number: account_number }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end
end
