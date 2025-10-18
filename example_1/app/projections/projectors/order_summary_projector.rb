module Projections
  module Projectors
    class OrderSummaryProjector
      def project(event)
        case event
        when Orders::Events::OrderCreated
          handle_order_created(event)
        when Orders::Events::ItemAdded
          handle_item_added(event)
        when Orders::Events::ItemRemoved
          handle_item_removed(event)
        when Orders::Events::OrderConfirmed
          handle_order_confirmed(event)
        when Orders::Events::OrderCancelled
          handle_order_cancelled(event)
        when Orders::Events::OrderShipped
          handle_order_shipped(event)
        end
      end

      private

      def handle_order_created(event)
        OrderSummaryReadModel.create!(
          order_id: event.order_id,
          customer_name: event.customer_name,
          status: "draft",
          total_amount_cents: 0,
          item_count: 0,
          confirmed_at: nil,
          cancelled_at: nil,
          shipped_at: nil
        )
      end

      def handle_item_added(event)
        OrderSummaryReadModel.transaction do
          record = OrderSummaryReadModel.lock.find_by!(order_id: event.order_id)
          total = record.total_amount_cents + (event.quantity * event.unit_price_cents)
          record.update!(
            item_count: record.item_count + event.quantity,
            total_amount_cents: total
          )
        end
      end

      def handle_item_removed(event)
        OrderSummaryReadModel.transaction do
          record = OrderSummaryReadModel.lock.find_by!(order_id: event.order_id)
          total = record.total_amount_cents - (event.quantity * event.unit_price_cents)
          record.update!(
            item_count: [record.item_count - event.quantity, 0].max,
            total_amount_cents: [total, 0].max
          )
        end
      end

      def handle_order_confirmed(event)
        update_status(event.order_id, "confirmed", confirmed_at: event.confirmed_at)
      end

      def handle_order_cancelled(event)
        update_status(event.order_id, "cancelled", cancelled_at: event.cancelled_at)
      end

      def handle_order_shipped(event)
        update_status(event.order_id, "shipped", shipped_at: event.shipped_at)
      end

      def update_status(order_id, status, timestamps = {})
        OrderSummaryReadModel.transaction do
          record = OrderSummaryReadModel.lock.find_by!(order_id: order_id)
          record.update!(
            { status: status }.merge(timestamps)
          )
        end
      end
    end
  end
end
