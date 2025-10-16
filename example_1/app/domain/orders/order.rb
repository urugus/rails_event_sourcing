# frozen_string_literal: true

module Domain
  module Orders
    # 注文集約
    class Order < EventSourcing::AggregateRoot
      attr_reader :customer_name, :items, :status, :total_amount, :tracking_number

      # 注文のステータス
      STATUS_PENDING = "pending"
      STATUS_CONFIRMED = "confirmed"
      STATUS_SHIPPED = "shipped"
      STATUS_CANCELLED = "cancelled"

      def initialize(id)
        super(id)
        @items = []
        @status = nil
        @customer_name = nil
        @total_amount = 0
        @tracking_number = nil
      end

      # 新しい注文を作成する
      def self.place(order_id:, customer_name:, total_amount:)
        order = new(order_id)
        order.place(customer_name: customer_name, total_amount: total_amount)
        order
      end

      # 注文を作成する
      def place(customer_name:, total_amount:)
        if @status
          raise InvalidOperationError, "Order already placed"
        end

        record_event(Events::OrderPlaced.new(
          order_id: id,
          customer_name: customer_name,
          total_amount: total_amount,
          placed_at: Time.current
        ))
      end

      # 商品を追加する
      def add_item(product_name:, quantity:, unit_price:)
        unless can_modify?
          raise InvalidOperationError, "Cannot add items to #{@status} order"
        end

        if quantity <= 0
          raise InvalidOperationError, "Quantity must be positive"
        end

        record_event(Events::OrderItemAdded.new(
          order_id: id,
          product_name: product_name,
          quantity: quantity,
          unit_price: unit_price
        ))
      end

      # 注文を確定する
      def confirm
        unless @status == STATUS_PENDING
          raise InvalidOperationError, "Can only confirm pending orders"
        end

        if @items.empty?
          raise InvalidOperationError, "Cannot confirm order without items"
        end

        record_event(Events::OrderConfirmed.new(
          order_id: id,
          confirmed_at: Time.current
        ))
      end

      # 注文をキャンセルする
      def cancel(reason:)
        if @status == STATUS_SHIPPED
          raise InvalidOperationError, "Cannot cancel shipped orders"
        end

        if @status == STATUS_CANCELLED
          raise InvalidOperationError, "Order already cancelled"
        end

        record_event(Events::OrderCancelled.new(
          order_id: id,
          reason: reason,
          cancelled_at: Time.current
        ))
      end

      # 注文を発送する
      def ship(tracking_number:)
        unless @status == STATUS_CONFIRMED
          raise InvalidOperationError, "Can only ship confirmed orders"
        end

        if tracking_number.to_s.strip.empty?
          raise InvalidOperationError, "Tracking number is required"
        end

        record_event(Events::OrderShipped.new(
          order_id: id,
          tracking_number: tracking_number,
          shipped_at: Time.current
        ))
      end

      protected

      # イベントを適用して状態を更新する
      def apply_event(event)
        case event
        when Events::OrderPlaced
          apply_order_placed(event)
        when Events::OrderItemAdded
          apply_order_item_added(event)
        when Events::OrderConfirmed
          apply_order_confirmed(event)
        when Events::OrderCancelled
          apply_order_cancelled(event)
        when Events::OrderShipped
          apply_order_shipped(event)
        end
      end

      private

      def apply_order_placed(event)
        @customer_name = event.customer_name
        @total_amount = event.total_amount
        @status = STATUS_PENDING
      end

      def apply_order_item_added(event)
        @items << {
          product_name: event.product_name,
          quantity: event.quantity,
          unit_price: event.unit_price
        }
      end

      def apply_order_confirmed(event)
        @status = STATUS_CONFIRMED
      end

      def apply_order_cancelled(event)
        @status = STATUS_CANCELLED
      end

      def apply_order_shipped(event)
        @status = STATUS_SHIPPED
        @tracking_number = event.tracking_number
      end

      # 注文を変更可能か
      def can_modify?
        @status == STATUS_PENDING
      end

      class InvalidOperationError < StandardError; end
    end
  end
end
