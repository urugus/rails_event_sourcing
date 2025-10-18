module Projections
  module Projectors
    class OrderDetailsProjector < BaseProjector
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
        OrderDetailsReadModel.create!(
          order_id: event.order_id,
          customer_name: event.customer_name,
          status: "draft",
          items: [],
          total_amount_cents: 0,
          confirmed_at: nil,
          cancelled_at: nil,
          shipped_at: nil,
          cancellation_reason: nil,
          tracking_number: nil
        )
      end

      on Orders::Events::ItemAdded do |event|
        OrderDetailsReadModel.transaction do
          record = OrderDetailsReadModel.lock.find_by!(order_id: event.order_id)
          items = Array(record.items).map(&:dup)
          existing_item = items.find { |item| item["product_name"] == event.product_name }

          if existing_item
            existing_item["quantity"] += event.quantity
            existing_item["unit_price_cents"] = event.unit_price_cents
          else
            items << {
              "product_name" => event.product_name,
              "quantity" => event.quantity,
              "unit_price_cents" => event.unit_price_cents
            }
          end

          record.update!(
            items: items,
            total_amount_cents: recalculate_total(items)
          )
        end
      end

      on Orders::Events::ItemRemoved do |event|
        OrderDetailsReadModel.transaction do
          record = OrderDetailsReadModel.lock.find_by!(order_id: event.order_id)
          items = Array(record.items).map(&:dup)
          items.reject! { |item| item["product_name"] == event.product_name }
          record.update!(
            items: items,
            total_amount_cents: recalculate_total(items)
          )
        end
      end

      on Orders::Events::OrderConfirmed do |event|
        handle_status_change(event, "confirmed", confirmed_at: event.confirmed_at)
      end

      on Orders::Events::OrderCancelled do |event|
        handle_status_change(event, "cancelled", cancelled_at: event.cancelled_at, cancellation_reason: event.reason)
      end

      on Orders::Events::OrderShipped do |event|
        handle_status_change(event, "shipped", shipped_at: event.shipped_at, tracking_number: event.tracking_number)
      end

      private

      def handle_status_change(event, status, extra_attributes = {})
        OrderDetailsReadModel.transaction do
          record = OrderDetailsReadModel.lock.find_by!(order_id: event.order_id)
          record.update!(
            { status: status }.merge(extra_attributes)
          )
        end
      end

      def recalculate_total(items)
        items.sum do |item|
          item.fetch("quantity") * item.fetch("unit_price_cents")
        end
      end
    end
  end
end
