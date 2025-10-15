# frozen_string_literal: true

require_relative '../domain/aggregates/account'

module CommandHandlers
  class DepositMoneyHandler
    def initialize(repository)
      @repository = repository
    end

    def handle(command)
      account = @repository.load(command.account_id, Domain::Aggregates::Account)
      account.deposit(
        amount: command.amount,
        description: command.description
      )
      @repository.save(account, Domain::Aggregates::Account)
    end
  end
end
