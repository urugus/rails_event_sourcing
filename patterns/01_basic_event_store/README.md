# 01. Basic Event Store

## 概要

Event Sourcingの基礎となるEvent Storeの実装です。イベントをデータベースに永続化し、ストリームごとにイベントを管理します。

## 主要概念

### Event Store
- アプリケーションの状態変化を「イベント」として記録
- イベントは **不変（Immutable）**
- 時系列順に並んだイベントの集合が「ストリーム」

### Stream
- 特定のAggregateに関連するイベントの集合
- 例: `Order-123` というストリームには、注文123に関するすべてのイベントが含まれる

## データベーススキーマ

```sql
CREATE TABLE events (
    id         BIGSERIAL PRIMARY KEY,
    stream_id  VARCHAR(255) NOT NULL,
    version    INTEGER NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    data       JSONB NOT NULL,
    metadata   JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (stream_id, version)
);

CREATE INDEX idx_events_stream_id ON events(stream_id);
CREATE INDEX idx_events_created_at ON events(created_at);
```

### 重要なポイント

1. **UNIQUE制約 (stream_id, version)**
   - 同じストリームに同じバージョンのイベントを追加できない
   - 楽観的ロックを実現し、並行更新の競合を防ぐ

2. **JSONB型**
   - イベントデータを柔軟に格納
   - PostgreSQLのJSONB機能でクエリも可能

## 実装ファイル

- `migration.sql`: データベーステーブル定義
- `event.rb`: Eventドメインモデル
- `event_store.rb`: EventStoreサービスクラス
- `event_store_spec.rb`: テストコード

## 使用例

```ruby
# Event Storeの初期化
store = EventStore.new

# イベントの追加
event = Event.new(
  stream_id: 'Order-123',
  event_type: 'OrderCreated',
  data: { customer_id: 1, total: 1000 }
)
store.append(event)

# ストリームからイベントを読み込み
events = store.read_stream('Order-123')
events.each { |e| puts e.event_type }
```

## 学べること

- イベントの永続化
- ストリームベースのイベント管理
- 楽観的ロックによる並行制御
- JSONBを使った柔軟なデータ格納
