# frozen_string_literal: true

module Projections
  module Projectors
    # ActiveRecord版の注文詳細プロジェクター
    # イベントを購読してOrderDetailsReadModelを更新する
    class ArOrderDetailsProjector
      # イベントを処理する
      def handle_event(event, event_record)
        case event
        when Domain::Orders::Events::OrderPlaced
          handle_order_placed(event)
        when Domain::Orders::Events::OrderItemAdded
          handle_order_item_added(event)
        when Domain::Orders::Events::OrderConfirmed
          handle_order_confirmed(event)
        when Domain::Orders::Events::OrderCancelled
          handle_order_cancelled(event)
        when Domain::Orders::Events::OrderShipped
          handle_order_shipped(event)
        end
      end

      private

      def handle_order_placed(event)
        Models::OrderDetailsReadModel.create!(
          order_id: event.order_id,
          customer_name: event.customer_name,
          total_amount: event.total_amount,
          status: "pending",
          placed_at: event.placed_at
        )
      end

      def handle_order_item_added(event)
        order = find_order(event.order_id)
        return unless order

        # 商品を追加
        Models::OrderItemReadModel.create!(
          order_id: event.order_id,
          product_name: event.product_name,
          quantity: event.quantity,
          unit_price: event.unit_price,
          subtotal: event.quantity * event.unit_price
        )
      end

      def handle_order_confirmed(event)
        order = find_order(event.order_id)
        return unless order

        order.update!(
          status: "confirmed",
          confirmed_at: event.confirmed_at
        )
      end

      def handle_order_cancelled(event)
        order = find_order(event.order_id)
        return unless order

        order.update!(
          status: "cancelled",
          cancelled_at: event.cancelled_at,
          cancel_reason: event.reason
        )
      end

      def handle_order_shipped(event)
        order = find_order(event.order_id)
        return unless order

        order.update!(
          status: "shipped",
          shipped_at: event.shipped_at,
          tracking_number: event.tracking_number
        )
      end

      def find_order(order_id)
        Models::OrderDetailsReadModel.find_by(order_id: order_id)
      end
    end
  end
end
