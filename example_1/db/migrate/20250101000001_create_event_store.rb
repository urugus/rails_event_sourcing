# frozen_string_literal: true

class CreateEventStore < ActiveRecord::Migration[7.0]
  def change
    # イベントストアテーブル
    # すべてのドメインイベントを時系列で保存する
    create_table :events do |t|
      t.string :aggregate_id, null: false
      t.string :aggregate_type, null: false
      t.string :event_type, null: false
      t.jsonb :event_data, null: false, default: {}
      t.integer :version, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    # インデックス
    # 集約ごとのイベントストリームを効率的に取得するため
    add_index :events, [:aggregate_id, :aggregate_type, :version],
              unique: true,
              name: "idx_events_aggregate_stream"

    # イベントタイプで検索するため
    add_index :events, :event_type

    # 時系列でイベントを取得するため
    add_index :events, :occurred_at
  end
end
