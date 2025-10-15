-- Outboxテーブル
-- イベントをメッセージブローカーに発行するための一時テーブル
CREATE TABLE outbox (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    payload JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP,
    published BOOLEAN DEFAULT FALSE,
    retry_count INTEGER DEFAULT 0
);

-- 未発行メッセージの高速検索
CREATE INDEX idx_outbox_published ON outbox(published) WHERE published = FALSE;
CREATE INDEX idx_outbox_created_at ON outbox(created_at);
CREATE INDEX idx_outbox_aggregate_id ON outbox(aggregate_id);

COMMENT ON TABLE outbox IS 'メッセージブローカーへの発行待ちイベントを保持';
COMMENT ON COLUMN outbox.aggregate_id IS 'Aggregateの識別子（順序保証のため）';
COMMENT ON COLUMN outbox.event_type IS 'イベントの種類';
COMMENT ON COLUMN outbox.payload IS 'イベントのペイロードデータ';
COMMENT ON COLUMN outbox.published IS '発行済みフラグ';
COMMENT ON COLUMN outbox.published_at IS '発行日時';
COMMENT ON COLUMN outbox.retry_count IS '再試行回数';
