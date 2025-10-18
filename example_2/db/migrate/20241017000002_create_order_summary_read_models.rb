class CreateOrderSummaryReadModels < ActiveRecord::Migration[7.1]
  def change
    create_table :order_summary_read_models do |t|
      t.string :order_id, null: false
      t.string :customer_name, null: false
      t.string :status, null: false
      t.integer :total_amount_cents, null: false, default: 0
      t.integer :item_count, null: false, default: 0
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.datetime :shipped_at
      t.timestamps
    end

    add_index :order_summary_read_models, :order_id, unique: true
    add_index :order_summary_read_models, :status
  end
end
