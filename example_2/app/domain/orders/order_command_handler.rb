require "securerandom"

module Orders
  class OrderCommandHandler
    def initialize(repository:)
      @repository = repository
    end

    def create_order(customer_name:)
      order_id = SecureRandom.uuid
      order = repository.load(order_id)
      order.create(customer_name: customer_name)
      repository.store(order)
      order_id
    end

    def add_item(order_id:, product_name:, quantity:, unit_price_cents:)
      order = repository.load(order_id)
      order.add_item(
        product_name: product_name,
        quantity: quantity,
        unit_price_cents: unit_price_cents
      )
      repository.store(order)
    end

    def remove_item(order_id:, product_name:)
      order = repository.load(order_id)
      order.remove_item(product_name: product_name)
      repository.store(order)
    end

    def confirm(order_id:)
      order = repository.load(order_id)
      order.confirm
      repository.store(order)
    end

    def cancel(order_id:, reason:)
      order = repository.load(order_id)
      order.cancel(reason: reason)
      repository.store(order)
    end

    def ship(order_id:, tracking_number:)
      order = repository.load(order_id)
      order.ship(tracking_number: tracking_number)
      repository.store(order)
    end

    private

    attr_reader :repository
  end
end
