# frozen_string_literal: true

require_relative '../02_aggregate_root/repository'
require_relative '../02_aggregate_root/order'
require_relative 'command'

# コマンドハンドラの基底クラス
class CommandHandler
  def initialize(repository)
    @repository = repository
  end

  def handle(command)
    raise NotImplementedError, "#{self.class} must implement #handle"
  end

  protected

  attr_reader :repository
end

# 注文作成コマンドハンドラ
class CreateOrderHandler < CommandHandler
  def handle(command)
    stream_id = "Order-#{command.order_id}"

    # 既に存在する場合はエラー
    if repository.exists?(stream_id)
      raise CommandError, "Order #{command.order_id} already exists"
    end

    # 新しい注文を作成
    order = Order.new
    order.create(
      customer_id: command.customer_id,
      items: command.items
    )

    # 保存
    repository.save(order, stream_id)

    CommandResult.success(order_id: command.order_id)
  end
end

# 注文確定コマンドハンドラ
class SubmitOrderHandler < CommandHandler
  def handle(command)
    stream_id = "Order-#{command.order_id}"

    repository.with_aggregate(Order, stream_id) do |order|
      order.submit
    end

    CommandResult.success(order_id: command.order_id)
  rescue => e
    CommandResult.failure(error: e.message)
  end
end

# 注文発送コマンドハンドラ
class ShipOrderHandler < CommandHandler
  def handle(command)
    stream_id = "Order-#{command.order_id}"

    repository.with_aggregate(Order, stream_id) do |order|
      order.ship(tracking_number: command.tracking_number)
    end

    CommandResult.success(order_id: command.order_id)
  rescue => e
    CommandResult.failure(error: e.message)
  end
end

# 注文キャンセルコマンドハンドラ
class CancelOrderHandler < CommandHandler
  def handle(command)
    stream_id = "Order-#{command.order_id}"

    repository.with_aggregate(Order, stream_id) do |order|
      order.cancel(reason: command.reason)
    end

    CommandResult.success(order_id: command.order_id)
  rescue => e
    CommandResult.failure(error: e.message)
  end
end

# 商品追加コマンドハンドラ
class AddOrderItemHandler < CommandHandler
  def handle(command)
    stream_id = "Order-#{command.order_id}"

    repository.with_aggregate(Order, stream_id) do |order|
      order.add_item(
        product_id: command.product_id,
        quantity: command.quantity,
        price: command.price
      )
    end

    CommandResult.success(order_id: command.order_id)
  rescue => e
    CommandResult.failure(error: e.message)
  end
end

# コマンド実行結果
class CommandResult
  attr_reader :success, :data, :error

  def initialize(success:, data: {}, error: nil)
    @success = success
    @data = data
    @error = error
  end

  def self.success(data = {})
    new(success: true, data: data)
  end

  def self.failure(error:)
    new(success: false, error: error)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end

# カスタムエラー
class CommandError < StandardError; end
