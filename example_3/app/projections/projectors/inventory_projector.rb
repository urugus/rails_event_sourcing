class InventoryProjector < Projections::BaseProjector
  subscribes_to [
    Inventory::Events::StockAdded,
    Inventory::Events::StockReserved,
    Inventory::Events::ReservationConfirmed,
    Inventory::Events::ReservationCancelled,
    Inventory::Events::ReservationExpired
  ]

  on Inventory::Events::StockAdded do |event|
    inventory = find_or_create_inventory(event.product_id)
    inventory.total_quantity += event.quantity
    inventory.available_quantity = inventory.total_quantity - inventory.reserved_quantity
    inventory.save!
  end

  on Inventory::Events::StockReserved do |event|
    inventory = find_or_create_inventory(event.product_id)
    inventory.add_reservation(
      reservation_id: event.reservation_id,
      quantity: event.quantity,
      expires_at: event.expires_at
    )
    inventory.save!
  end

  on Inventory::Events::ReservationConfirmed do |event|
    InventoryReadModel.transaction do
      inventory = InventoryReadModel.lock.find_by!(product_id: event.product_id)
      reservation = inventory.reservations.find { |r| r["reservation_id"] == event.reservation_id }
      return unless reservation

      # 予約を確定 = 在庫から減らして予約を削除
      inventory.total_quantity -= reservation["quantity"]
      inventory.remove_reservation(reservation_id: event.reservation_id)
      inventory.save!
    end
  end

  on Inventory::Events::ReservationCancelled do |event|
    InventoryReadModel.transaction do
      inventory = InventoryReadModel.lock.find_by!(product_id: event.product_id)
      inventory.remove_reservation(reservation_id: event.reservation_id)
      inventory.save!
    end
  end

  on Inventory::Events::ReservationExpired do |event|
    InventoryReadModel.transaction do
      inventory = InventoryReadModel.lock.find_by!(product_id: event.product_id)
      inventory.remove_reservation(reservation_id: event.reservation_id)
      inventory.save!
    end
  end

  private

  def find_or_create_inventory(product_id)
    InventoryReadModel.find_or_create_by(product_id: product_id) do |inventory|
      inventory.total_quantity = 0
      inventory.reserved_quantity = 0
      inventory.available_quantity = 0
      inventory.reservations = []
    end
  end
end
