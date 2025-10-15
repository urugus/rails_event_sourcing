#!/usr/bin/env ruby
# frozen_string_literal: true

require 'securerandom'
require 'time'

# 全ての依存ファイルを読み込み
require_relative 'lib/event_store/event'
require_relative 'lib/event_store/event_store'
require_relative 'lib/domain/events/account_opened'
require_relative 'lib/domain/events/money_deposited'
require_relative 'lib/domain/events/money_withdrawn'
require_relative 'lib/domain/aggregates/account'
require_relative 'lib/domain/repository'
require_relative 'lib/commands/open_account'
require_relative 'lib/commands/deposit_money'
require_relative 'lib/commands/withdraw_money'
require_relative 'lib/command_handlers/open_account_handler'
require_relative 'lib/command_handlers/deposit_money_handler'
require_relative 'lib/command_handlers/withdraw_money_handler'

# Event Store の初期化
puts "=== Pattern 3: Full Event Sourcing サンプル ==="
puts

event_store = EventStore::InMemoryEventStore.new
repository = Domain::Repository.new(event_store)

# Command Handlers の初期化
open_account_handler = CommandHandlers::OpenAccountHandler.new(repository)
deposit_handler = CommandHandlers::DepositMoneyHandler.new(repository)
withdraw_handler = CommandHandlers::WithdrawMoneyHandler.new(repository)

# 1. 口座開設
puts "1. 口座開設"
command = Commands::OpenAccount.new(
  account_id: "acc-001",
  owner_name: "山田太郎",
  initial_balance: 10000
)
open_account_handler.handle(command)
puts "   ✓ 口座 acc-001 を開設（初期残高: 10,000円）"
puts

# 2. 入金
puts "2. 入金処理"
command = Commands::DepositMoney.new(
  account_id: "acc-001",
  amount: 5000,
  description: "給与振込"
)
deposit_handler.handle(command)
puts "   ✓ 5,000円を入金"
puts

# 3. 出金
puts "3. 出金処理"
command = Commands::WithdrawMoney.new(
  account_id: "acc-001",
  amount: 2000,
  description: "ATM出金"
)
withdraw_handler.handle(command)
puts "   ✓ 2,000円を出金"
puts

# 4. Aggregate から現在の状態を取得
puts "4. 現在の残高確認（Aggregateから復元）"
account = repository.load("acc-001", Domain::Aggregates::Account)
puts "   口座番号: acc-001"
puts "   所有者: #{account.owner_name}"
puts "   現在残高: #{account.balance}円"
puts "   バージョン: #{account.version}"
puts

# 5. イベント履歴の表示
puts "5. イベント履歴（Event Storeから取得）"
events = event_store.get_stream("Account-acc-001")
events.each_with_index do |event, index|
  puts "   [#{index + 1}] #{event.event_type}"
  puts "       Event ID: #{event.event_id}"
  puts "       Data: #{event.data}"
  puts "       Timestamp: #{event.metadata[:timestamp]}"
  puts
end

# 6. エラーハンドリングの例
puts "6. エラーハンドリング（残高不足）"
begin
  command = Commands::WithdrawMoney.new(
    account_id: "acc-001",
    amount: 20000,
    description: "大きな出金"
  )
  withdraw_handler.handle(command)
rescue Domain::Aggregates::Account::InsufficientBalanceError => e
  puts "   ✗ エラー: #{e.message}"
end
puts

# 7. 統計情報
puts "7. 統計情報"
puts "   総イベント数: #{events.size}"
puts "   現在残高: #{account.balance}円"
puts "   総入金額: #{events.select { |e| e.event_type == 'MoneyDeposited' }.sum { |e| e.data[:amount] }}円"
puts "   総出金額: #{events.select { |e| e.event_type == 'MoneyWithdrawn' }.sum { |e| e.data[:amount] }}円"
puts

puts "=== サンプル終了 ==="
