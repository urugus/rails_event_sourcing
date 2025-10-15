# frozen_string_literal: true

module Accounts
  module Queries
    class GetTransactionHistory
      class Result
        attr_reader :transactions, :errors

        def initialize(transactions: [], errors: [])
          @transactions = transactions
          @errors = errors
        end

        def success?
          errors.empty?
        end

        def failure?
          !success?
        end
      end

      def self.call(account_number:, limit: 100, offset: 0)
        new(account_number, limit, offset).call
      end

      def initialize(account_number, limit, offset)
        @account_number = account_number
        @limit = limit
        @offset = offset
      end

      def call
        account = Account.find_by(account_number: @account_number)
        return Result.new(errors: ["口座が見つかりません"]) unless account

        transactions = account.transactions
                              .recent
                              .limit(@limit)
                              .offset(@offset)

        Result.new(transactions: transactions)
      end
    end
  end
end
