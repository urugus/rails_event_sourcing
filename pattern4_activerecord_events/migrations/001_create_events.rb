# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    # イベントストアテーブル
    create_table :domain_events do |t|
      t.string :event_id, null: false, index: { unique: true }
      t.string :event_type, null: false
      t.string :stream_name, null: false
      t.integer :stream_version, null: false
      t.string :aggregate_id, null: false
      t.json :data, null: false
      t.json :metadata
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :domain_events, [:stream_name, :stream_version], unique: true
    add_index :domain_events, :aggregate_id
    add_index :domain_events, :event_type
    add_index :domain_events, :occurred_at

    # Read Model: 口座残高
    create_table :account_balances do |t|
      t.string :account_number, null: false, index: { unique: true }
      t.string :owner_name, null: false
      t.decimal :current_balance, precision: 15, scale: 2, default: 0, null: false
      t.integer :version, default: 0, null: false
      t.datetime :last_transaction_at
      t.timestamps
    end

    # Read Model: 取引履歴（非正規化）
    create_table :account_transactions do |t|
      t.references :account_balance, null: false, foreign_key: true
      t.string :event_id, null: false, index: true
      t.string :transaction_type, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.decimal :balance_after, precision: 15, scale: 2, null: false
      t.string :description
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :account_transactions, [:account_balance_id, :occurred_at]
  end
end
