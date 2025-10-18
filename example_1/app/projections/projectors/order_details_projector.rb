module Projections
  module Projectors
    class OrderDetailsProjector
      def project(event)
        case event
        when Orders::Events::OrderCreated
          handle_order_created(event)
        when Orders::Events::ItemAdded
          handle_item_added(event)
        when Orders::Events::ItemRemoved
          handle_item_removed(event)
        when Orders::Events::OrderConfirmed
          handle_status_change(event, "confirmed", confirmed_at: event.confirmed_at)
        when Orders::Events::OrderCancelled
          handle_status_change(event, "cancelled", cancelled_at: event.cancelled_at, cancellation_reason: event.reason)
        when Orders::Events::OrderShipped
          handle_status_change(event, "shipped", shipped_at: event.shipped_at, tracking_number: event.tracking_number)
        end
      end

      private

      def handle_order_created(event)
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

      def handle_item_added(event)
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

      def handle_item_removed(event)
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
