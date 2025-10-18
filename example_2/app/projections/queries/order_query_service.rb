module Projections
  module Queries
    class OrderQueryService
      def list_orders
        OrderSummaryReadModel.order(created_at: :desc)
      end

      def find_order(order_id)
        OrderDetailsReadModel.find_by(order_id: order_id)
      end
    end
  end
end
