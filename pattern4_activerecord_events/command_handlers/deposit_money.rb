# frozen_string_literal: true

module CommandHandlers
  class DepositMoney
    def initialize(repository)
      @repository = repository
    end

    def call(account_number:, amount:, description: nil)
      account = @repository.load(account_number, Domain::Aggregates::Account)
      account.deposit(
        amount: amount,
        description: description
      )
      @repository.save(account, Domain::Aggregates::Account)

      { success: true, account_number: account_number, amount: amount }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end
end
