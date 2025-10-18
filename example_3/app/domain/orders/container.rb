module Orders
  class Container
    class << self
      def command_handler
        @command_handler ||= OrderCommandHandler.new(repository: repository)
      end

      def repository
        @repository ||= OrderRepository.new(event_store: event_store)
      end

      def event_store
        @event_store ||= EventSourcing::EventStore.new(
          event_mappings: EventMappings.build
        )
      end

      # テスト用にコンテナの状態をリセット
      def reset!
        @command_handler = nil
        @repository = nil
        @event_store = nil
      end
    end
  end
end
