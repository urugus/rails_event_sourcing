# frozen_string_literal: true

module Accounts
  module Commands
    class OpenAccount
      class Result
        attr_reader :account, :errors

        def initialize(account: nil, errors: [])
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

      def self.call(account_number:, owner_name:, initial_balance: 0)
        new(account_number, owner_name, initial_balance).call
      end

      def initialize(account_number, owner_name, initial_balance)
        @account_number = account_number
        @owner_name = owner_name
        @initial_balance = initial_balance
      end

      def call
        validate_initial_balance
        return Result.new(errors: @errors) if @errors.any?

        account = nil
        ActiveRecord::Base.transaction do
          account = Account.create!(
            account_number: @account_number,
            owner_name: @owner_name,
            balance: @initial_balance,
            status: 'active'
          )

          if @initial_balance > 0
            Transaction.create!(
              account: account,
              transaction_type: 'deposit',
              amount: @initial_balance,
              balance_after: @initial_balance,
              description: '口座開設時の初期入金'
            )
          end
        end

        Result.new(account: account)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(errors: [e.message])
      end

      private

      def validate_initial_balance
        @errors = []
        if @initial_balance < 0
          @errors << "初期残高は0以上である必要があります"
        end
      end
    end
  end
end
