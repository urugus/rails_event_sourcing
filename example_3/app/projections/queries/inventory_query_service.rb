class InventoryQueryService
  def get_inventory(product_id)
    inventory = InventoryReadModel.find_by(product_id: product_id)
    return nil unless inventory

    {
      product_id: inventory.product_id,
      total_quantity: inventory.total_quantity,
      reserved_quantity: inventory.reserved_quantity,
      available_quantity: inventory.available_quantity,
      reservations: inventory.reservations.map do |r|
        {
          reservation_id: r["reservation_id"],
          quantity: r["quantity"],
          expires_at: r["expires_at"]
        }
      end
    }
  end

  def check_availability(product_id, quantity)
    inventory = InventoryReadModel.find_by(product_id: product_id)
    return false unless inventory

    inventory.available?(quantity)
  end

  def list_all_inventories
    InventoryReadModel.all.map do |inventory|
      {
        product_id: inventory.product_id,
        total_quantity: inventory.total_quantity,
        reserved_quantity: inventory.reserved_quantity,
        available_quantity: inventory.available_quantity
      }
    end
  end

  def find_expired_reservations
    now = Time.current
    inventories = InventoryReadModel.all

    expired = []
    inventories.each do |inventory|
      inventory.reservations.each do |reservation|
        expires_at = Time.parse(reservation["expires_at"])
        if expires_at <= now
          expired << {
            product_id: inventory.product_id,
            reservation_id: reservation["reservation_id"],
            quantity: reservation["quantity"],
            expires_at: expires_at
          }
        end
      end
    end

    expired
  end
end
