# frozen_string_literal: true

class CreateOrderSummaryReadModels < ActiveRecord::Migration[7.0]
  def change
    # 注文サマリーRead Model
    # 注文一覧表示用に最適化されたテーブル
    create_table :order_summary_read_models do |t|
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
    add_index :order_summary_read_models, :order_id, unique: true

    # 顧客名で検索
    add_index :order_summary_read_models, :customer_name

    # ステータスで検索（最も頻繁に使用される）
    add_index :order_summary_read_models, :status

    # 日付範囲で検索
    add_index :order_summary_read_models, :placed_at

    # 複合インデックス：ステータスと日付でソート
    add_index :order_summary_read_models, [:status, :placed_at]
  end
end
