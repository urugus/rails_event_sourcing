# frozen_string_literal: true

module CommandHandlers
  class OpenAccount
    def initialize(repository)
      @repository = repository
    end

    def call(account_number:, owner_name:, initial_balance: 0)
      account = Domain::Aggregates::Account.new(account_number)
      account.open(
        owner_name: owner_name,
        initial_balance: initial_balance
      )
      @repository.save(account, Domain::Aggregates::Account)

      { success: true, account_number: account_number }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end
end
