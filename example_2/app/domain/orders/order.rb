module Orders
  class Order
    attr_reader :id, :customer_name, :status, :items, :persisted_version, :pending_events

    def initialize(id:)
      @id = id
      @customer_name = nil
      @status = :not_created
      @items = []
      @persisted_version = 0
      @pending_events = []
    end

    def load_from_history(events)
      events.each do |event|
        apply_event(event)
        @persisted_version += 1
      end
      @pending_events.clear
      self
    end

    def create(customer_name:)
      ensure_not_created
      record_event(Events::OrderCreated.new(order_id: id, customer_name: customer_name))
    end

    def add_item(product_name:, quantity:, unit_price_cents:)
      ensure_created
      ensure_editable
      ensure_positive(quantity: quantity, unit_price_cents: unit_price_cents)
      record_event(
        Events::ItemAdded.new(
          order_id: id,
          product_name: product_name,
          quantity: quantity,
          unit_price_cents: unit_price_cents
        )
      )
    end

    def remove_item(product_name:)
      ensure_created
      ensure_editable
      item = find_item(product_name)
      record_event(
        Events::ItemRemoved.new(
          order_id: id,
          product_name: product_name,
          quantity: item.quantity,
          unit_price_cents: item.unit_price_cents
        )
      )
    end

    def confirm
      ensure_created
      ensure_editable
      ensure_has_items
      record_event(
        Events::OrderConfirmed.new(
          order_id: id,
          confirmed_at: Time.current
        )
      )
    end

    def cancel(reason:)
      ensure_created
      ensure_not_cancelled
      ensure_not_shipped
      record_event(
        Events::OrderCancelled.new(
          order_id: id,
          reason: reason,
          cancelled_at: Time.current
        )
      )
    end

    def ship(tracking_number:)
      ensure_created
      ensure_confirmed
      record_event(
        Events::OrderShipped.new(
          order_id: id,
          tracking_number: tracking_number,
          shipped_at: Time.current
        )
      )
    end

    def total_amount_cents
      items.sum(&:subtotal)
    end

    def mark_events_persisted
      @persisted_version += @pending_events.length
      @pending_events.clear
    end

    private

    def record_event(event)
      apply_event(event)
      @pending_events << event
    end

    def apply_event(event)
      case event
      when Events::OrderCreated
        apply_order_created(event)
      when Events::ItemAdded
        apply_item_added(event)
      when Events::ItemRemoved
        apply_item_removed(event)
      when Events::OrderConfirmed
        apply_order_confirmed(event)
      when Events::OrderCancelled
        apply_order_cancelled(event)
      when Events::OrderShipped
        apply_order_shipped(event)
      else
        raise ArgumentError, "unknown event #{event.class}"
      end
    end

    def apply_order_created(event)
      @customer_name = event.customer_name
      @status = :draft
    end

    def apply_item_added(event)
      existing_item = @items.find { |item| item.product_name == event.product_name }
      if existing_item
        # Immutableなので既存のアイテムを削除して、新しいインスタンスを追加
        @items.delete(existing_item)
        @items << OrderItem.new(
          product_name: event.product_name,
          quantity: existing_item.quantity + event.quantity,
          unit_price_cents: event.unit_price_cents
        )
      else
        @items << OrderItem.new(
          product_name: event.product_name,
          quantity: event.quantity,
          unit_price_cents: event.unit_price_cents
        )
      end
    end

    def apply_item_removed(event)
      @items.reject! { |item| item.product_name == event.product_name }
    end

    def apply_order_confirmed(_event)
      @status = :confirmed
    end

    def apply_order_cancelled(_event)
      @status = :cancelled
    end

    def apply_order_shipped(_event)
      @status = :shipped
    end

    def ensure_not_created
      return if status == :not_created

      raise DomainError, "order already created"
    end

    def ensure_created
      return unless status == :not_created

      raise DomainError, "order not yet created"
    end

    def ensure_editable
      return unless [:confirmed, :cancelled, :shipped].include?(status)

      raise DomainError, "order is no longer editable"
    end

    def ensure_positive(quantity:, unit_price_cents:)
      if quantity <= 0 || unit_price_cents <= 0
        raise DomainError, "quantity and unit price must be positive"
      end
    end

    def find_item(product_name)
      item = items.find { |candidate| candidate.product_name == product_name }
      return item if item

      raise DomainError, "item #{product_name} not found"
    end

    def ensure_has_items
      raise DomainError, "order has no items" if items.empty?
    end

    def ensure_not_cancelled
      raise DomainError, "order already cancelled" if status == :cancelled
    end

    def ensure_not_shipped
      raise DomainError, "order already shipped" if status == :shipped
    end

    def ensure_confirmed
      raise DomainError, "order must be confirmed before shipping" unless status == :confirmed
    end
  end
end
