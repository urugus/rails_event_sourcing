module Projections
  class Container
    class << self
      def query_service
        @query_service ||= Queries::OrderQueryService.new
      end

      def projectors
        @projectors ||= [
          Projectors::OrderSummaryProjector.new,
          Projectors::OrderDetailsProjector.new
        ]
      end

      def projection_manager
        @projection_manager ||= ProjectionManager.new(
          event_mappings: Orders::EventMappings.build,
          projectors: projectors
        )
      end

      # テスト用にコンテナの状態をリセット
      def reset!
        @query_service = nil
        @projectors = nil
        @projection_manager = nil
      end
    end
  end
end
