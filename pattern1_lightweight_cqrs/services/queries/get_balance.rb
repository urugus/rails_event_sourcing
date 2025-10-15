# frozen_string_literal: true

module Accounts
  module Queries
    class GetBalance
      class Result
        attr_reader :balance, :account, :errors

        def initialize(balance: nil, account: nil, errors: [])
          @balance = balance
          @account = account
          @errors = errors
        end

        def success?
          errors.empty?
        end

        def failure?
          !success?
        end
      end

      def self.call(account_number:)
        new(account_number).call
      end

      def initialize(account_number)
        @account_number = account_number
      end

      def call
        account = Account.find_by(account_number: @account_number)
        return Result.new(errors: ["口座が見つかりません"]) unless account

        Result.new(balance: account.balance, account: account)
      end
    end
  end
end
