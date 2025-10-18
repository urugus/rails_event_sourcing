module Inventory
  class Inventory
    attr_reader :product_id, :total_quantity, :reservations, :persisted_version, :pending_events

    def initialize(product_id:)
      @product_id = product_id
      @total_quantity = 0
      @reservations = []
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

    def add_stock(quantity:)
      ensure_positive_quantity(quantity)
      record_event(
        Events::StockAdded.new(
          product_id: product_id,
          quantity: quantity,
          added_at: Time.current
        )
      )
    end

    def reserve_stock(quantity:, reservation_id:, expires_in: 15.minutes)
      ensure_positive_quantity(quantity)
      ensure_sufficient_stock(quantity)

      record_event(
        Events::StockReserved.new(
          product_id: product_id,
          quantity: quantity,
          reservation_id: reservation_id,
          reserved_at: Time.current,
          expires_at: Time.current + expires_in
        )
      )
    end

    def confirm_reservation(reservation_id:)
      reservation = find_reservation(reservation_id)
      record_event(
        Events::ReservationConfirmed.new(
          product_id: product_id,
          reservation_id: reservation_id,
          confirmed_at: Time.current
        )
      )
    end

    def cancel_reservation(reservation_id:)
      reservation = find_reservation(reservation_id)
      record_event(
        Events::ReservationCancelled.new(
          product_id: product_id,
          reservation_id: reservation_id,
          quantity: reservation.quantity,
          cancelled_at: Time.current
        )
      )
    end

    def expire_reservation(reservation_id:)
      reservation = find_reservation(reservation_id)
      raise DomainError, "reservation #{reservation_id} has not expired yet" unless reservation.expired?

      record_event(
        Events::ReservationExpired.new(
          product_id: product_id,
          reservation_id: reservation_id,
          quantity: reservation.quantity,
          expired_at: Time.current
        )
      )
    end

    def available_quantity
      total_quantity - reserved_quantity
    end

    def reserved_quantity
      reservations.sum(&:quantity)
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
      when Events::StockAdded
        apply_stock_added(event)
      when Events::StockReserved
        apply_stock_reserved(event)
      when Events::ReservationConfirmed
        apply_reservation_confirmed(event)
      when Events::ReservationCancelled
        apply_reservation_cancelled(event)
      when Events::ReservationExpired
        apply_reservation_expired(event)
      else
        raise ArgumentError, "unknown event #{event.class}"
      end
    end

    def apply_stock_added(event)
      @total_quantity += event.quantity
    end

    def apply_stock_reserved(event)
      @reservations << InventoryItem.new(
        product_id: event.product_id,
        quantity: event.quantity,
        reservation_id: event.reservation_id,
        reserved_at: event.reserved_at,
        expires_at: event.expires_at
      )
    end

    def apply_reservation_confirmed(event)
      reservation = @reservations.find { |r| r.reservation_id == event.reservation_id }
      @total_quantity -= reservation.quantity
      @reservations.delete(reservation)
    end

    def apply_reservation_cancelled(event)
      @reservations.reject! { |r| r.reservation_id == event.reservation_id }
    end

    def apply_reservation_expired(event)
      @reservations.reject! { |r| r.reservation_id == event.reservation_id }
    end

    def ensure_positive_quantity(quantity)
      raise DomainError, "quantity must be positive" if quantity <= 0
    end

    def ensure_sufficient_stock(quantity)
      if available_quantity < quantity
        raise DomainError, "insufficient stock: available=#{available_quantity}, requested=#{quantity}"
      end
    end

    def find_reservation(reservation_id)
      reservation = reservations.find { |r| r.reservation_id == reservation_id }
      raise DomainError, "reservation #{reservation_id} not found" unless reservation
      reservation
    end
  end
end
