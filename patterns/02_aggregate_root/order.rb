# frozen_string_literal: true

require_relative 'aggregate_root'
require_relative 'order_events'

# 注文Aggregate
# ビジネスロジックをカプセル化し、不変条件を保護
class Order
  include AggregateRoot

  attr_reader :customer_id, :items, :total, :state

  def initialize
    super
    @state = :draft
    @items = []
    @total = 0
    @customer_id = nil
  end

  # コマンド: 注文を作成
  def create(customer_id:, items:)
    raise OrderError, 'Order already created' unless @state == :draft
    raise OrderError, 'Customer ID is required' if customer_id.nil?
    raise OrderError, 'Items cannot be empty' if items.empty?

    total = calculate_total(items)

    apply OrderCreated.new(
      customer_id: customer_id,
      items: items,
      total: total
    )
  end

  # コマンド: 注文を確定
  def submit
    raise OrderError, 'Order must be created first' unless @state == :created
    raise OrderError, 'Cannot submit empty order' if @items.empty?

    apply OrderSubmitted.new
  end

  # コマンド: 注文を発送
  def ship(tracking_number:)
    raise OrderError, 'Order must be submitted first' unless @state == :submitted
    raise OrderError, 'Tracking number is required' if tracking_number.nil? || tracking_number.empty?

    apply OrderShipped.new(tracking_number: tracking_number)
  end

  # コマンド: 注文をキャンセル
  def cancel(reason:)
    raise OrderError, 'Order already shipped' if @state == :shipped
    raise OrderError, 'Order already cancelled' if @state == :cancelled
    raise OrderError, 'Cannot cancel draft order' if @state == :draft

    apply OrderCancelled.new(reason: reason)
  end

  # コマンド: 商品を追加
  def add_item(product_id:, quantity:, price:)
    raise OrderError, 'Cannot modify order after submission' unless [:draft, :created].include?(@state)
    raise OrderError, 'Quantity must be positive' if quantity <= 0
    raise OrderError, 'Price must be positive' if price <= 0

    apply OrderItemAdded.new(
      product_id: product_id,
      quantity: quantity,
      price: price
    )
  end

  # コマンド: 商品を削除
  def remove_item(product_id:)
    raise OrderError, 'Cannot modify order after submission' unless [:draft, :created].include?(@state)

    item = @items.find { |i| i[:product_id] == product_id }
    raise OrderError, "Item not found: #{product_id}" unless item

    apply OrderItemRemoved.new(product_id: product_id)
  end

  # イベントハンドラ

  on OrderCreated do |event|
    @state = :created
    @customer_id = event.customer_id
    @items = event.items
    @total = event.total
  end

  on OrderSubmitted do |_event|
    @state = :submitted
  end

  on OrderShipped do |event|
    @state = :shipped
    @tracking_number = event.tracking_number
    @shipped_at = event.shipped_at
  end

  on OrderCancelled do |event|
    @state = :cancelled
    @cancellation_reason = event.reason
    @cancelled_at = event.cancelled_at
  end

  on OrderItemAdded do |event|
    @items << {
      product_id: event.product_id,
      quantity: event.quantity,
      price: event.price
    }
    @total = calculate_total(@items)
  end

  on OrderItemRemoved do |event|
    @items.reject! { |item| item[:product_id] == event.product_id }
    @total = calculate_total(@items)
  end

  # ヘルパーメソッド

  def shipped?
    @state == :shipped
  end

  def cancelled?
    @state == :cancelled
  end

  def can_be_modified?
    [:draft, :created].include?(@state)
  end

  private

  def calculate_total(items)
    items.sum { |item| item[:quantity] * item[:price] }
  end

  # カスタムエラークラス
  class OrderError < StandardError; end
end
