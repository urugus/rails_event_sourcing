# frozen_string_literal: true

class CreateAccountsAndTransactions < ActiveRecord::Migration[7.1]
  def change
    # 口座テーブル
    create_table :accounts do |t|
      t.string :account_number, null: false, index: { unique: true }
      t.string :owner_name, null: false
      t.decimal :balance, precision: 15, scale: 2, default: 0, null: false
      t.string :status, default: 'active', null: false # active, closed
      t.timestamps
    end

    # 取引履歴テーブル
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :transaction_type, null: false # deposit, withdraw
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.decimal :balance_after, precision: 15, scale: 2, null: false
      t.string :description
      t.datetime :executed_at, null: false
      t.timestamps
    end

    add_index :transactions, [:account_id, :executed_at]
  end
end
