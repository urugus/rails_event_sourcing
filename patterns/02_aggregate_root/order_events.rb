# frozen_string_literal: true

require_relative 'aggregate_root'

# 注文ドメインのイベント定義

class OrderCreated < DomainEvent
  def initialize(customer_id:, items:, total:)
    super(customer_id: customer_id, items: items, total: total)
  end
end

class OrderSubmitted < DomainEvent
  def initialize(submitted_at: Time.now)
    super(submitted_at: submitted_at)
  end
end

class OrderShipped < DomainEvent
  def initialize(tracking_number:, shipped_at: Time.now)
    super(tracking_number: tracking_number, shipped_at: shipped_at)
  end
end

class OrderCancelled < DomainEvent
  def initialize(reason:, cancelled_at: Time.now)
    super(reason: reason, cancelled_at: cancelled_at)
  end
end

class OrderItemAdded < DomainEvent
  def initialize(product_id:, quantity:, price:)
    super(product_id: product_id, quantity: quantity, price: price)
  end
end

class OrderItemRemoved < DomainEvent
  def initialize(product_id:)
    super(product_id: product_id)
  end
end
