module Projections
  class Container
    class << self
      def order_query_service
        @order_query_service ||= Queries::OrderQueryService.new
      end

      def inventory_query_service
        @inventory_query_service ||= InventoryQueryService.new
      end

      # 互換性のため
      alias_method :query_service, :order_query_service

      def projectors
        @projectors ||= [
          Projectors::OrderSummaryProjector.new,
          Projectors::OrderDetailsProjector.new,
          InventoryProjector.new
        ]
      end

      def projection_manager
        @projection_manager ||= ProjectionManager.new(
          event_mappings: build_event_mappings,
          projectors: projectors
        )
      end

      # テスト用にコンテナの状態をリセット
      def reset!
        @order_query_service = nil
        @inventory_query_service = nil
        @projectors = nil
        @projection_manager = nil
      end

      private

      def build_event_mappings
        Orders::EventMappings.build.merge(Inventory::EventMappings.build)
      end
    end
  end
end
