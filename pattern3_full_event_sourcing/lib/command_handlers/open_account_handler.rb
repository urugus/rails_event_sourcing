# frozen_string_literal: true

require_relative '../domain/aggregates/account'

module CommandHandlers
  class OpenAccountHandler
    def initialize(repository)
      @repository = repository
    end

    def handle(command)
      account = Domain::Aggregates::Account.new(command.account_id)
      account.open(
        owner_name: command.owner_name,
        initial_balance: command.initial_balance
      )
      @repository.save(account, Domain::Aggregates::Account)
    end
  end
end
