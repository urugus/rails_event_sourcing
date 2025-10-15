-- Event Store基本テーブル
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

-- パフォーマンス最適化用インデックス
CREATE INDEX idx_events_stream_id ON events(stream_id);
CREATE INDEX idx_events_created_at ON events(created_at);
CREATE INDEX idx_events_event_type ON events(event_type);

-- コメント
COMMENT ON TABLE events IS 'Event Storeのメインテーブル。すべてのドメインイベントを格納';
COMMENT ON COLUMN events.stream_id IS 'Aggregateを識別するストリームID（例: Order-123）';
COMMENT ON COLUMN events.version IS 'ストリーム内でのイベントバージョン。楽観的ロックに使用';
COMMENT ON COLUMN events.event_type IS 'イベントの種類（例: OrderCreated, OrderShipped）';
COMMENT ON COLUMN events.data IS 'イベントのペイロードデータ（JSON形式）';
COMMENT ON COLUMN events.metadata IS 'イベントのメタデータ（user_id, correlation_idなど）';
