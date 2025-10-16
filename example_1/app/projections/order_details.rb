# frozen_string_literal: true

module Projections
  # 注文詳細のRead Model
  # 注文の詳細表示用の最適化されたデータ構造（商品情報を含む）
  class OrderDetails
    attr_reader :order_id, :customer_name, :total_amount, :status,
                :placed_at, :confirmed_at, :shipped_at, :cancelled_at,
                :tracking_number, :cancel_reason, :items

    def initialize(attributes = {})
      @order_id = attributes[:order_id]
      @customer_name = attributes[:customer_name]
      @total_amount = attributes[:total_amount]
      @status = attributes[:status]
      @placed_at = attributes[:placed_at]
      @confirmed_at = attributes[:confirmed_at]
      @shipped_at = attributes[:shipped_at]
      @cancelled_at = attributes[:cancelled_at]
      @tracking_number = attributes[:tracking_number]
      @cancel_reason = attributes[:cancel_reason]
      @items = attributes[:items] || []
    end

    def add_item(product_name:, quantity:, unit_price:)
      @items << {
        product_name: product_name,
        quantity: quantity,
        unit_price: unit_price,
        subtotal: quantity * unit_price
      }
    end

    def items_total
      @items.sum { |item| item[:subtotal] }
    end

    def to_h
      {
        order_id: @order_id,
        customer_name: @customer_name,
        total_amount: @total_amount,
        status: @status,
        placed_at: @placed_at,
        confirmed_at: @confirmed_at,
        shipped_at: @shipped_at,
        cancelled_at: @cancelled_at,
        tracking_number: @tracking_number,
        cancel_reason: @cancel_reason,
        items: @items,
        items_total: items_total
      }
    end
  end
end
