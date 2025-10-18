module Orders
  class OrderItem
    attr_reader :product_name, :quantity, :unit_price_cents, :product_id, :reservation_id

    def initialize(product_name:, quantity:, unit_price_cents:, product_id: nil, reservation_id: nil)
      @product_name = product_name
      @quantity = quantity
      @unit_price_cents = unit_price_cents
      @product_id = product_id
      @reservation_id = reservation_id
      validate!
      freeze
    end

    # 小計を計算
    def subtotal
      quantity * unit_price_cents
    end

    # 数量を更新した新しいインスタンスを返す（Immutable）
    def with_quantity(new_quantity)
      self.class.new(
        product_name: product_name,
        quantity: new_quantity,
        unit_price_cents: unit_price_cents,
        product_id: product_id,
        reservation_id: reservation_id
      )
    end

    # 単価を更新した新しいインスタンスを返す（Immutable）
    def with_unit_price(new_price)
      self.class.new(
        product_name: product_name,
        quantity: quantity,
        unit_price_cents: new_price,
        product_id: product_id,
        reservation_id: reservation_id
      )
    end

    # 数量を加算した新しいインスタンスを返す
    def add_quantity(additional_quantity)
      with_quantity(quantity + additional_quantity)
    end

    # 値ベースの等価性
    def ==(other)
      other.is_a?(self.class) &&
        product_name == other.product_name &&
        quantity == other.quantity &&
        unit_price_cents == other.unit_price_cents &&
        product_id == other.product_id &&
        reservation_id == other.reservation_id
    end

    alias eql? ==

    def hash
      [product_name, quantity, unit_price_cents, product_id, reservation_id].hash
    end

    # ハッシュへの変換（イベントやシリアライズ用）
    def to_h
      {
        product_name: product_name,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        product_id: product_id,
        reservation_id: reservation_id
      }
    end

    private

    def validate!
      raise ArgumentError, "product_name must be present" if product_name.nil? || product_name.empty?
      raise ArgumentError, "quantity must be positive" if quantity.nil? || quantity <= 0
      raise ArgumentError, "unit_price_cents must be positive" if unit_price_cents.nil? || unit_price_cents <= 0
    end
  end
end
