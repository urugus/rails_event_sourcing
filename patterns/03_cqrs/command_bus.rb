# frozen_string_literal: true

# Command Busの実装
# コマンドを適切なハンドラにディスパッチする
class CommandBus
  def initialize
    @handlers = {}
  end

  # ハンドラを登録
  def register(command_class, handler)
    @handlers[command_class] = handler
  end

  # コマンドをディスパッチ
  def dispatch(command)
    handler = @handlers[command.class]

    raise CommandBusError, "No handler registered for #{command.class}" unless handler

    # ログ記録
    log_command(command)

    # ハンドラを実行
    result = handler.handle(command)

    # 結果をログ記録
    log_result(command, result)

    result
  rescue => e
    log_error(command, e)
    raise
  end

  private

  def log_command(command)
    puts "[CommandBus] Dispatching: #{command.command_name} (id: #{command.command_id})"
  end

  def log_result(command, result)
    status = result.success? ? 'SUCCESS' : 'FAILURE'
    puts "[CommandBus] Result: #{status} for #{command.command_name}"
  end

  def log_error(command, error)
    puts "[CommandBus] ERROR: #{error.message} for #{command.command_name}"
  end

  class CommandBusError < StandardError; end
end
