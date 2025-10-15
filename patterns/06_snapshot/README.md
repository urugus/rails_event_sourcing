# 06. Snapshot Pattern

## 概要

Snapshotパターンは、Aggregateの状態のスナップショットを定期的に保存し、イベントリプレイのパフォーマンスを最適化するパターンです。

## 問題

Event Sourcingでは、Aggregateの現在の状態を復元するために、すべてのイベントを再生する必要があります。

```ruby
# 1000個のイベントを再生...時間がかかる！
order = Order.new
events = event_store.read_stream('Order-123')  # 1000 events
events.each { |e| order.apply_event(e) }
```

## 解決策: Snapshot

Aggregateの状態を定期的にスナップショット（保存）し、スナップショット以降のイベントのみを再生します。

```
Snapshot (v100) + Events (v101-v150) = Current State (v150)
```

## データベーススキーマ

```sql
CREATE TABLE snapshots (
    stream_id VARCHAR(255) PRIMARY KEY,
    version INTEGER NOT NULL,
    state JSONB NOT NULL,
    created_at TIMESTAMP
);
```

## 実装パターン

### スナップショットの作成
```ruby
def create_snapshot(aggregate, stream_id)
  snapshot = {
    stream_id: stream_id,
    version: aggregate.version,
    state: aggregate.to_snapshot
  }
  snapshot_store.save(snapshot)
end
```

### スナップショットからの復元
```ruby
def load_with_snapshot(aggregate_class, stream_id)
  aggregate = aggregate_class.new

  # スナップショットを読み込み
  snapshot = snapshot_store.find(stream_id)

  if snapshot
    aggregate.from_snapshot(snapshot.state)
    from_version = snapshot.version
  else
    from_version = 0
  end

  # スナップショット以降のイベントのみ再生
  events = event_store.read_stream(stream_id, from_version: from_version)
  aggregate.load_from_history(events)

  aggregate
end
```

## スナップショット戦略

### 1. 固定間隔
- N個のイベントごとにスナップショット作成
- 例: 100イベントごと

### 2. 時間ベース
- 一定時間ごとにスナップショット作成
- 例: 1日1回

### 3. オンデマンド
- 必要に応じて手動で作成

## メリット
- Aggregate復元の高速化
- 大量のイベントがあるAggregateに有効

## 注意点
- スナップショットは最適化のため（オプション）
- イベントが真のデータソース
- スナップショット削除しても問題なし
