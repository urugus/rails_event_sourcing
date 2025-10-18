class CreateEventRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :event_records do |t|
      t.string :aggregate_id, null: false
      t.string :aggregate_type, null: false
      t.string :event_type, null: false
      t.jsonb :data, null: false, default: {}
      t.integer :version, null: false
      t.datetime :occurred_at, null: false
      t.datetime :projected_at
    end

    add_index :event_records, [:aggregate_id, :aggregate_type, :version], unique: true, name: "index_event_records_on_aggregate_and_version"
    add_index :event_records, :event_type
  end
end
