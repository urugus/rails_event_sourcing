require "securerandom"

module Inventory
  class InventoryCommandHandler
    def initialize(repository:)
      @repository = repository
    end

    def add_stock(product_id:, quantity:)
      inventory = repository.load(product_id)
      inventory.add_stock(quantity: quantity)
      repository.store(inventory)
    end

    def reserve_stock(product_id:, quantity:, reservation_id: nil, expires_in: 15.minutes)
      reservation_id ||= SecureRandom.uuid
      inventory = repository.load(product_id)
      inventory.reserve_stock(
        quantity: quantity,
        reservation_id: reservation_id,
        expires_in: expires_in
      )
      repository.store(inventory)
      reservation_id
    end

    def confirm_reservation(product_id:, reservation_id:)
      inventory = repository.load(product_id)
      inventory.confirm_reservation(reservation_id: reservation_id)
      repository.store(inventory)
    end

    def cancel_reservation(product_id:, reservation_id:)
      inventory = repository.load(product_id)
      inventory.cancel_reservation(reservation_id: reservation_id)
      repository.store(inventory)
    end

    def expire_reservation(product_id:, reservation_id:)
      inventory = repository.load(product_id)
      inventory.expire_reservation(reservation_id: reservation_id)
      repository.store(inventory)
    end

    private

    attr_reader :repository
  end
end
