# frozen_string_literal: true

# Commandの基底クラス
# Commandは「何をしたいか」という意図を表現する
class Command
  # コマンドの一意なID
  attr_reader :command_id, :metadata

  def initialize
    @command_id = SecureRandom.uuid
    @metadata = {
      created_at: Time.now,
      user_id: nil,
      correlation_id: nil
    }
  end

  # メタデータの設定
  def with_metadata(user_id: nil, correlation_id: nil)
    @metadata[:user_id] = user_id if user_id
    @metadata[:correlation_id] = correlation_id || @command_id
    self
  end

  # コマンド名
  def command_name
    self.class.name
  end

  # コマンドをHash形式に変換
  def to_h
    {
      command_id: command_id,
      command_name: command_name,
      metadata: metadata
    }
  end
end

# 注文関連のコマンド

class CreateOrderCommand < Command
  attr_reader :order_id, :customer_id, :items

  def initialize(order_id:, customer_id:, items:)
    super()
    @order_id = order_id
    @customer_id = customer_id
    @items = items
  end
end

class SubmitOrderCommand < Command
  attr_reader :order_id

  def initialize(order_id:)
    super()
    @order_id = order_id
  end
end

class ShipOrderCommand < Command
  attr_reader :order_id, :tracking_number

  def initialize(order_id:, tracking_number:)
    super()
    @order_id = order_id
    @tracking_number = tracking_number
  end
end

class CancelOrderCommand < Command
  attr_reader :order_id, :reason

  def initialize(order_id:, reason:)
    super()
    @order_id = order_id
    @reason = reason
  end
end

class AddOrderItemCommand < Command
  attr_reader :order_id, :product_id, :quantity, :price

  def initialize(order_id:, product_id:, quantity:, price:)
    super()
    @order_id = order_id
    @product_id = product_id
    @quantity = quantity
    @price = price
  end
end
