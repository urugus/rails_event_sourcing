# frozen_string_literal: true

module Commands
  class OpenAccount
    attr_reader :account_id, :owner_name, :initial_balance

    def initialize(account_id:, owner_name:, initial_balance: 0)
      @account_id = account_id
      @owner_name = owner_name
      @initial_balance = initial_balance
    end
  end
end
