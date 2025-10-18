class CreateProjectionErrors < ActiveRecord::Migration[7.0]
  def change
    create_table :projection_errors do |t|
      t.string :projector_name, null: false
      t.bigint :event_id, null: false
      t.string :event_type, null: false
      t.text :error_message, null: false
      t.text :error_backtrace
      t.integer :retry_count, null: false, default: 0
      t.datetime :next_retry_at
      t.datetime :last_error_at

      t.timestamps
    end

    add_index :projection_errors, [:projector_name, :event_id], unique: true
    add_index :projection_errors, :next_retry_at
    add_index :projection_errors, :retry_count
  end
end
