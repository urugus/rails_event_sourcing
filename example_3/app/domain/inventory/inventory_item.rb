module Inventory
  class InventoryItem
    attr_reader :product_id, :quantity, :reserved_at, :reservation_id, :expires_at

    def initialize(product_id:, quantity:, reservation_id:, reserved_at:, expires_at:)
      @product_id = product_id
      @quantity = quantity
      @reservation_id = reservation_id
      @reserved_at = reserved_at
      @expires_at = expires_at
    end

    def expired?(current_time = Time.current)
      current_time >= expires_at
    end
  end
end
