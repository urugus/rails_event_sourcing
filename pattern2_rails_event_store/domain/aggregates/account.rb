# frozen_string_literal: true

module Aggregates
  class Account
    include AggregateRoot

    # 状態
    attr_reader :account_number, :owner_name, :balance, :status

    # エラークラス
    class AccountNotOpenError < StandardError; end
    class InsufficientBalanceError < StandardError; end
    class NegativeAmountError < StandardError; end

    def initialize(account_number)
      @account_number = account_number
      @balance = 0
      @status = nil
    end

    # コマンド: 口座を開設する
    def open(owner_name:, initial_balance: 0)
      raise StandardError, "口座は既に開設されています" if @status == :active

      if initial_balance < 0
        raise NegativeAmountError, "初期残高は0以上である必要があります"
      end

      apply Events::AccountOpened.strict(
        data: {
          account_number: @account_number,
          owner_name: owner_name,
          initial_balance: initial_balance,
          opened_at: Time.current
        }
      )
    end

    # コマンド: 入金する
    def deposit(amount:, description: nil)
      raise AccountNotOpenError, "口座が開設されていません" unless @status == :active
      raise NegativeAmountError, "入金額は0より大きい必要があります" if amount <= 0

      apply Events::MoneyDeposited.strict(
        data: {
          account_number: @account_number,
          amount: amount,
          description: description,
          deposited_at: Time.current
        }
      )
    end

    # コマンド: 出金する
    def withdraw(amount:, description: nil)
      raise AccountNotOpenError, "口座が開設されていません" unless @status == :active
      raise NegativeAmountError, "出金額は0より大きい必要があります" if amount <= 0
      raise InsufficientBalanceError, "残高不足です" if @balance < amount

      apply Events::MoneyWithdrawn.strict(
        data: {
          account_number: @account_number,
          amount: amount,
          description: description,
          withdrawn_at: Time.current
        }
      )
    end

    # イベントハンドラ: 状態を更新する（イベントから復元）
    on Events::AccountOpened do |event|
      @owner_name = event.data[:owner_name]
      @balance = event.data[:initial_balance]
      @status = :active
    end

    on Events::MoneyDeposited do |event|
      @balance += event.data[:amount]
    end

    on Events::MoneyWithdrawn do |event|
      @balance -= event.data[:amount]
    end
  end
end
