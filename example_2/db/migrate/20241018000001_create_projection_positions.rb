class CreateProjectionPositions < ActiveRecord::Migration[7.0]
  def change
    create_table :projection_positions do |t|
      t.string :projector_name, null: false
      t.bigint :last_event_id, null: false, default: 0
      t.datetime :last_processed_at

      t.timestamps
    end

    add_index :projection_positions, :projector_name, unique: true
  end
end
