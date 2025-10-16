# frozen_string_literal: true

module Projections
  module Projectors
    # ActiveRecord版の注文サマリープロジェクター
    # イベントを購読してOrderSummaryReadModelを更新する
    class ArOrderSummaryProjector
      # イベントを処理する
      def handle_event(event, event_record)
        case event
        when Domain::Orders::Events::OrderPlaced
          handle_order_placed(event)
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
        Models::OrderSummaryReadModel.create!(
          order_id: event.order_id,
          customer_name: event.customer_name,
          total_amount: event.total_amount,
          status: "pending",
          placed_at: event.placed_at
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
        Models::OrderSummaryReadModel.find_by(order_id: order_id)
      end
    end
  end
end
