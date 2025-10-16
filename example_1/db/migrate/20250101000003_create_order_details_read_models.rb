# frozen_string_literal: true

class CreateOrderDetailsReadModels < ActiveRecord::Migration[7.0]
  def change
    # 注文詳細Read Model
    # 注文詳細表示用に最適化されたテーブル
    create_table :order_details_read_models do |t|
      t.string :order_id, null: false
      t.string :customer_name, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.string :status, null: false
      t.datetime :placed_at, null: false
      t.datetime :confirmed_at
      t.datetime :shipped_at
      t.datetime :cancelled_at
      t.string :tracking_number
      t.string :cancel_reason

      t.timestamps
    end

    # インデックス
    # order_idで一意に検索
    add_index :order_details_read_models, :order_id, unique: true

    # 顧客名で検索
    add_index :order_details_read_models, :customer_name

    # ステータスで検索
    add_index :order_details_read_models, :status
  end
end
