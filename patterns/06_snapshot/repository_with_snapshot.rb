# frozen_string_literal: true

require_relative '../02_aggregate_root/repository'
require_relative 'snapshot_store'

# Snapshotをサポートするリポジトリ
class RepositoryWithSnapshot < Repository
  def initialize(event_store, snapshot_store)
    super(event_store)
    @snapshot_store = snapshot_store
  end

  # Aggregateをスナップショットから復元
  def load(aggregate_class, stream_id)
    aggregate = aggregate_class.new

    # スナップショットを取得
    snapshot = @snapshot_store.find(stream_id)

    if snapshot
      puts "[Repository] Loading from snapshot (version: #{snapshot.version})"
      aggregate.from_snapshot(snapshot.state)
      from_version = snapshot.version
    else
      puts "[Repository] No snapshot found, loading from beginning"
      from_version = 0
    end

    # スナップショット以降のイベントを取得
    events = @event_store.read_stream(stream_id, from_version: from_version)

    if events.empty? && snapshot.nil?
      raise "Stream not found: #{stream_id}"
    end

    # イベントを再生
    aggregate.load_from_history(events)
    puts "[Repository] Loaded #{events.size} events after snapshot"

    aggregate
  end

  # Aggregateを保存し、必要に応じてスナップショットを作成
  def save(aggregate, stream_id)
    super(aggregate, stream_id)

    # スナップショットを作成すべきか判定
    if @snapshot_store.should_create_snapshot?(aggregate.version)
      create_snapshot(aggregate, stream_id)
    end
  end

  # スナップショットを作成
  def create_snapshot(aggregate, stream_id)
    puts "[Repository] Creating snapshot for #{stream_id} (version: #{aggregate.version})"

    @snapshot_store.save(
      stream_id: stream_id,
      version: aggregate.version,
      state: aggregate.to_snapshot
    )
  end
end
