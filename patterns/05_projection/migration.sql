-- Projection Checkpointsテーブル
-- 各Projectionの処理済み位置を記録
CREATE TABLE IF NOT EXISTS projection_checkpoints (
    projection_name VARCHAR(255) PRIMARY KEY,
    last_event_id BIGINT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE projection_checkpoints IS 'Projectionの処理済みイベント位置を記録';
COMMENT ON COLUMN projection_checkpoints.projection_name IS 'Projectionの名前';
COMMENT ON COLUMN projection_checkpoints.last_event_id IS '最後に処理したイベントID';
COMMENT ON COLUMN projection_checkpoints.updated_at IS '最終更新日時';
