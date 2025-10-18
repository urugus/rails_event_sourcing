module Projections
  module Projectors
    class OrderSummaryProjector < BaseProjector
      # Declare which events this projector subscribes to
      subscribes_to [
        Orders::Events::OrderCreated,
        Orders::Events::ItemAdded,
        Orders::Events::ItemRemoved,
        Orders::Events::OrderConfirmed,
        Orders::Events::OrderCancelled,
        Orders::Events::OrderShipped
      ]

      # Define handlers for each event type using declarative syntax
      on Orders::Events::OrderCreated do |event|
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

      on Orders::Events::ItemAdded do |event|
        OrderSummaryReadModel.transaction do
          record = OrderSummaryReadModel.lock.find_by!(order_id: event.order_id)
          total = record.total_amount_cents + (event.quantity * event.unit_price_cents)
          record.update!(
            item_count: record.item_count + event.quantity,
            total_amount_cents: total
          )
        end
      end

      on Orders::Events::ItemRemoved do |event|
        OrderSummaryReadModel.transaction do
          record = OrderSummaryReadModel.lock.find_by!(order_id: event.order_id)
          total = record.total_amount_cents - (event.quantity * event.unit_price_cents)
          record.update!(
            item_count: [record.item_count - event.quantity, 0].max,
            total_amount_cents: [total, 0].max
          )
        end
      end

      on Orders::Events::OrderConfirmed do |event|
        update_status(event.order_id, "confirmed", confirmed_at: event.confirmed_at)
      end

      on Orders::Events::OrderCancelled do |event|
        update_status(event.order_id, "cancelled", cancelled_at: event.cancelled_at)
      end

      on Orders::Events::OrderShipped do |event|
        update_status(event.order_id, "shipped", shipped_at: event.shipped_at)
      end

      private

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
