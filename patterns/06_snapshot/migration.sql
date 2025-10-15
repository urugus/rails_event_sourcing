-- Snapshotsテーブル
CREATE TABLE IF NOT EXISTS snapshots (
    stream_id VARCHAR(255) PRIMARY KEY,
    version INTEGER NOT NULL,
    state JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_snapshots_created_at ON snapshots(created_at);

COMMENT ON TABLE snapshots IS 'Aggregateの状態のスナップショット';
COMMENT ON COLUMN snapshots.stream_id IS 'ストリームID';
COMMENT ON COLUMN snapshots.version IS 'スナップショット作成時のバージョン';
COMMENT ON COLUMN snapshots.state IS 'Aggregateの状態（JSON）';
