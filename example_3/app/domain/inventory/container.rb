module Inventory
  class Container
    def self.event_store
      @event_store ||= EventSourcing::EventStore.new
    end

    def self.inventory_repository
      @inventory_repository ||= InventoryRepository.new(event_store: event_store)
    end

    def self.inventory_command_handler
      @inventory_command_handler ||= InventoryCommandHandler.new(repository: inventory_repository)
    end
  end
end
