class InventoryReadModel < ApplicationRecord
  validates :product_id, presence: true, uniqueness: true
  validates :total_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :available_quantity, numericality: { greater_than_or_equal_to: 0 }

  # 在庫が利用可能かどうか
  def available?(quantity)
    available_quantity >= quantity
  end

  # 予約を追加
  def add_reservation(reservation_id:, quantity:, expires_at:)
    self.reservations << {
      reservation_id: reservation_id,
      quantity: quantity,
      expires_at: expires_at.iso8601
    }
    self.reserved_quantity += quantity
    self.available_quantity = total_quantity - reserved_quantity
  end

  # 予約を削除
  def remove_reservation(reservation_id:)
    reservation = reservations.find { |r| r["reservation_id"] == reservation_id }
    return unless reservation

    self.reservations.reject! { |r| r["reservation_id"] == reservation_id }
    self.reserved_quantity -= reservation["quantity"]
    self.available_quantity = total_quantity - reserved_quantity
  end
end
