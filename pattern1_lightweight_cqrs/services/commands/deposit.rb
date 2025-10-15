# frozen_string_literal: true

module Accounts
  module Commands
    class Deposit
      class Result
        attr_reader :transaction, :errors

        def initialize(transaction: nil, errors: [])
          @transaction = transaction
          @errors = errors
        end

        def success?
          errors.empty?
        end

        def failure?
          !success?
        end
      end

      def self.call(account_number:, amount:, description: nil)
        new(account_number, amount, description).call
      end

      def initialize(account_number, amount, description)
        @account_number = account_number
        @amount = amount
        @description = description
      end

      def call
        validate_amount
        return Result.new(errors: @errors) if @errors.any?

        account = Account.find_by(account_number: @account_number)
        return Result.new(errors: ["口座が見つかりません"]) unless account
        return Result.new(errors: ["口座がクローズされています"]) if account.closed?

        transaction_record = nil
        ActiveRecord::Base.transaction do
          new_balance = account.balance + @amount
          account.update!(balance: new_balance)

          transaction_record = Transaction.create!(
            account: account,
            transaction_type: 'deposit',
            amount: @amount,
            balance_after: new_balance,
            description: @description || '入金'
          )
        end

        Result.new(transaction: transaction_record)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(errors: [e.message])
      end

      private

      def validate_amount
        @errors = []
        if @amount <= 0
          @errors << "入金額は0より大きい必要があります"
        end
      end
    end
  end
end
