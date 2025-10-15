# frozen_string_literal: true

# Projectionの基底クラス
class Projection
  def initialize(connection)
    @connection = connection
  end

  # イベントを投影
  def project(event)
    raise NotImplementedError, "#{self.class} must implement #project"
  end

  # すべてのイベントを再生してProjectionを再構築
  def rebuild(event_store)
    clear
    reset_checkpoint

    events = event_store.read_all_events(limit: 10000)
    events.each do |event|
      project(event)
      update_checkpoint(event.id)
    end

    puts "[#{self.class}] Rebuilt from #{events.size} events"
  end

  # Read Modelをクリア
  def clear
    raise NotImplementedError, "#{self.class} must implement #clear"
  end

  # Checkpoint関連
  def projection_name
    self.class.name
  end

  def get_checkpoint
    result = @connection.exec_params(
      'SELECT last_event_id FROM projection_checkpoints WHERE projection_name = $1',
      [projection_name]
    )

    result.ntuples > 0 ? result[0]['last_event_id'].to_i : 0
  end

  def update_checkpoint(event_id)
    @connection.exec_params(
      'INSERT INTO projection_checkpoints (projection_name, last_event_id, updated_at)
       VALUES ($1, $2, CURRENT_TIMESTAMP)
       ON CONFLICT (projection_name) DO UPDATE SET
         last_event_id = EXCLUDED.last_event_id,
         updated_at = EXCLUDED.updated_at',
      [projection_name, event_id]
    )
  end

  def reset_checkpoint
    @connection.exec_params(
      'DELETE FROM projection_checkpoints WHERE projection_name = $1',
      [projection_name]
    )
  end

  protected

  attr_reader :connection
end
