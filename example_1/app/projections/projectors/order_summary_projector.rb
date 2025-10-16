# frozen_string_literal: true

module Projections
  module Projectors
    # 注文サマリーのプロジェクター
    # イベントを購読してOrderSummaryを更新する
    class OrderSummaryProjector
      def initialize(read_model_store:)
        @read_model_store = read_model_store
      end

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
        summary = OrderSummary.new(
          order_id: event.order_id,
          customer_name: event.customer_name,
          total_amount: event.total_amount,
          status: "pending",
          placed_at: event.placed_at
        )

        @read_model_store.save("order_summaries", event.order_id, summary.to_h)
      end

      def handle_order_confirmed(event)
        data = @read_model_store.find("order_summaries", event.order_id)
        return unless data

        data[:status] = "confirmed"
        data[:confirmed_at] = event.confirmed_at

        @read_model_store.save("order_summaries", event.order_id, data)
      end

      def handle_order_cancelled(event)
        data = @read_model_store.find("order_summaries", event.order_id)
        return unless data

        data[:status] = "cancelled"
        data[:cancelled_at] = event.cancelled_at
        data[:cancel_reason] = event.reason

        @read_model_store.save("order_summaries", event.order_id, data)
      end

      def handle_order_shipped(event)
        data = @read_model_store.find("order_summaries", event.order_id)
        return unless data

        data[:status] = "shipped"
        data[:shipped_at] = event.shipped_at
        data[:tracking_number] = event.tracking_number

        @read_model_store.save("order_summaries", event.order_id, data)
      end
    end
  end
end
