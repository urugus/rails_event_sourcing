# frozen_string_literal: true

class CreateReadModels < ActiveRecord::Migration[7.1]
  def change
    # Read Model: 口座残高（クエリ用）
    create_table :account_balances do |t|
      t.string :account_number, null: false, index: { unique: true }
      t.string :owner_name, null: false
      t.decimal :current_balance, precision: 15, scale: 2, default: 0, null: false
      t.text :transaction_history # JSON形式で保存
      t.datetime :last_transaction_at
      t.timestamps
    end
  end
end
