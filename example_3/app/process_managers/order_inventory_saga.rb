class OrderInventorySaga
  def initialize(order_command_handler:, inventory_command_handler:)
    @order_command_handler = order_command_handler
    @inventory_command_handler = inventory_command_handler
  end

  # 商品追加時: 在庫予約 → 注文に商品追加
  def add_item_with_reservation(order_id:, product_id:, product_name:, quantity:, unit_price_cents:)
    begin
      # ステップ1: 在庫を予約
      reservation_id = inventory_command_handler.reserve_stock(
        product_id: product_id,
        quantity: quantity
      )

      # ステップ2: 注文に商品を追加（reservation_idを渡す）
      order_command_handler.add_item(
        order_id: order_id,
        product_name: product_name,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        product_id: product_id,
        reservation_id: reservation_id
      )

      { success: true, reservation_id: reservation_id }
    rescue Inventory::DomainError => e
      # 在庫不足などのエラー
      { success: false, error: e.message }
    rescue Orders::DomainError => e
      # 注文エラーの場合、予約をキャンセル（補償トランザクション）
      if reservation_id
        inventory_command_handler.cancel_reservation(
          product_id: product_id,
          reservation_id: reservation_id
        )
      end
      { success: false, error: e.message }
    end
  end

  # 注文確定時: 予約を確定
  def confirm_order_with_inventory(order_id:, item_reservations:)
    begin
      # ステップ1: 注文を確定
      order_command_handler.confirm(order_id: order_id)

      # ステップ2: すべての予約を確定
      item_reservations.each do |reservation|
        inventory_command_handler.confirm_reservation(
          product_id: reservation[:product_id],
          reservation_id: reservation[:reservation_id]
        )
      end

      { success: true }
    rescue => e
      { success: false, error: e.message }
    end
  end

  # 注文キャンセル時: 予約を解放
  def cancel_order_with_inventory(order_id:, reason:, item_reservations:)
    begin
      # ステップ1: 注文をキャンセル
      order_command_handler.cancel(order_id: order_id, reason: reason)

      # ステップ2: すべての予約をキャンセル
      item_reservations.each do |reservation|
        inventory_command_handler.cancel_reservation(
          product_id: reservation[:product_id],
          reservation_id: reservation[:reservation_id]
        )
      end

      { success: true }
    rescue => e
      { success: false, error: e.message }
    end
  end

  # 商品削除時: 予約を解放
  def remove_item_with_reservation(order_id:, product_name:, product_id:, reservation_id:)
    begin
      # ステップ1: 注文から商品を削除
      order_command_handler.remove_item(
        order_id: order_id,
        product_name: product_name
      )

      # ステップ2: 予約をキャンセル
      inventory_command_handler.cancel_reservation(
        product_id: product_id,
        reservation_id: reservation_id
      )

      { success: true }
    rescue => e
      { success: false, error: e.message }
    end
  end

  private

  attr_reader :order_command_handler, :inventory_command_handler
end
