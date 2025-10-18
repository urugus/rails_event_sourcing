class CreateOrderDetailsReadModels < ActiveRecord::Migration[7.1]
  def change
    create_table :order_details_read_models do |t|
      t.string :order_id, null: false
      t.string :customer_name, null: false
      t.string :status, null: false
      t.jsonb :items, null: false, default: []
      t.integer :total_amount_cents, null: false, default: 0
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.datetime :shipped_at
      t.string :cancellation_reason
      t.string :tracking_number
      t.timestamps
    end

    add_index :order_details_read_models, :order_id, unique: true
  end
end
