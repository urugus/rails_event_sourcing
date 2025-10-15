# frozen_string_literal: true

require_relative '../events/account_opened'
require_relative '../events/money_deposited'
require_relative '../events/money_withdrawn'

module Domain
  module Aggregates
    class Account
      attr_reader :id, :owner_name, :balance, :version, :uncommitted_events

      # カスタムエラー
      class AccountAlreadyOpenedError < StandardError; end
      class AccountNotOpenedError < StandardError; end
      class InsufficientBalanceError < StandardError; end
      class InvalidAmountError < StandardError; end

      def initialize(id)
        @id = id
        @balance = 0
        @version = 0
        @uncommitted_events = []
        @is_opened = false
      end

      # コマンド: 口座を開設
      def open(owner_name:, initial_balance: 0)
        raise AccountAlreadyOpenedError if @is_opened
        raise InvalidAmountError, "初期残高は0以上である必要があります" if initial_balance < 0

        apply_change(
          Events::AccountOpened.create(
            aggregate_id: @id,
            owner_name: owner_name,
            initial_balance: initial_balance
          )
        )
      end

      # コマンド: 入金
      def deposit(amount:, description: nil)
        raise AccountNotOpenedError unless @is_opened
        raise InvalidAmountError, "入金額は0より大きい必要があります" if amount <= 0

        apply_change(
          Events::MoneyDeposited.create(
            aggregate_id: @id,
            amount: amount,
            description: description
          )
        )
      end

      # コマンド: 出金
      def withdraw(amount:, description: nil)
        raise AccountNotOpenedError unless @is_opened
        raise InvalidAmountError, "出金額は0より大きい必要があります" if amount <= 0
        raise InsufficientBalanceError, "残高不足です (残高: #{@balance}, 出金額: #{amount})" if @balance < amount

        apply_change(
          Events::MoneyWithdrawn.create(
            aggregate_id: @id,
            amount: amount,
            description: description
          )
        )
      end

      # イベントから状態を復元
      def load_from_history(events)
        events.each do |event|
          apply_event(event, is_new: false)
        end
      end

      # 未コミットのイベントをクリア
      def mark_changes_as_committed
        @uncommitted_events.clear
      end

      private

      # 新しいイベントを適用（コマンド実行時）
      def apply_change(event)
        apply_event(event, is_new: true)
      end

      # イベントを適用して状態を更新
      def apply_event(event, is_new:)
        # イベントの型判定（OpenStruct の場合は event_type を使用）
        event_type = event.respond_to?(:event_type) ? event.event_type : event.class.name.split('::').last

        case event_type
        when 'AccountOpened'
          @owner_name = event.data[:owner_name]
          @balance = event.data[:initial_balance]
          @is_opened = true
        when 'MoneyDeposited'
          @balance += event.data[:amount]
        when 'MoneyWithdrawn'
          @balance -= event.data[:amount]
        end

        @version += 1
        @uncommitted_events << event if is_new
      end
    end
  end
end
