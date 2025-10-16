# frozen_string_literal: true

class CreateOrderItemReadModels < ActiveRecord::Migration[7.0]
  def change
    # 注文商品Read Model
    # 注文詳細の商品情報を保持するテーブル
    create_table :order_item_read_models do |t|
      t.string :order_id, null: false
      t.string :product_name, null: false
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :subtotal, precision: 10, scale: 2, null: false

      t.timestamps
    end

    # インデックス
    # order_idで商品を取得
    add_index :order_item_read_models, :order_id

    # 外部キー制約
    # order_details_read_modelsとの整合性を保つ
    add_foreign_key :order_item_read_models,
                    :order_details_read_models,
                    column: :order_id,
                    primary_key: :order_id,
                    on_delete: :cascade
  end
end
