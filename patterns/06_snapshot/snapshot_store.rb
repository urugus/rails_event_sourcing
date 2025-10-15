# frozen_string_literal: true

require 'json'

# Snapshot
class Snapshot
  attr_reader :stream_id, :version, :state, :created_at

  def initialize(stream_id:, version:, state:, created_at: Time.now)
    @stream_id = stream_id
    @version = version
    @state = state
    @created_at = created_at
  end

  def self.from_db(row)
    new(
      stream_id: row['stream_id'],
      version: row['version'].to_i,
      state: JSON.parse(row['state'], symbolize_names: true),
      created_at: Time.parse(row['created_at'])
    )
  end
end

# Snapshot Store
class SnapshotStore
  SNAPSHOT_INTERVAL = 50 # N個のイベントごとにスナップショット作成

  def initialize(connection)
    @connection = connection
  end

  # スナップショットを保存
  def save(stream_id:, version:, state:)
    @connection.exec_params(
      'INSERT INTO snapshots (stream_id, version, state, created_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (stream_id) DO UPDATE SET
         version = EXCLUDED.version,
         state = EXCLUDED.state,
         created_at = EXCLUDED.created_at',
      [stream_id, version, state.to_json, Time.now]
    )
  end

  # スナップショットを取得
  def find(stream_id)
    result = @connection.exec_params(
      'SELECT * FROM snapshots WHERE stream_id = $1',
      [stream_id]
    )

    return nil if result.ntuples.zero?

    Snapshot.from_db(result[0])
  end

  # スナップショットを削除
  def delete(stream_id)
    @connection.exec_params(
      'DELETE FROM snapshots WHERE stream_id = $1',
      [stream_id]
    )
  end

  # スナップショットが必要か判定
  def should_create_snapshot?(version)
    version > 0 && version % SNAPSHOT_INTERVAL == 0
  end

  # すべてのスナップショットを取得
  def all
    result = @connection.exec('SELECT * FROM snapshots ORDER BY created_at DESC')
    result.map { |row| Snapshot.from_db(row) }
  end

  # 古いスナップショットを削除
  def cleanup(older_than: Time.now - 30 * 24 * 60 * 60)
    @connection.exec_params(
      'DELETE FROM snapshots WHERE created_at < $1',
      [older_than]
    )
  end
end
