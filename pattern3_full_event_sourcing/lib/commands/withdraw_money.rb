# frozen_string_literal: true

module Commands
  class WithdrawMoney
    attr_reader :account_id, :amount, :description

    def initialize(account_id:, amount:, description: nil)
      @account_id = account_id
      @amount = amount
      @description = description
    end
  end
end
