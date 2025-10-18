class CreateInventoryReadModels < ActiveRecord::Migration[7.0]
  def change
    create_table :inventory_read_models do |t|
      t.string :product_id, null: false
      t.integer :total_quantity, null: false, default: 0
      t.integer :reserved_quantity, null: false, default: 0
      t.integer :available_quantity, null: false, default: 0
      t.jsonb :reservations, default: []
      t.timestamps
    end

    add_index :inventory_read_models, :product_id, unique: true
  end
end
