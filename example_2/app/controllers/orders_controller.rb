class OrdersController < ApplicationController
  rescue_from Orders::DomainError, with: :render_unprocessable_entity
  rescue_from EventSourcing::EventStore::ConcurrentWriteError, with: :render_conflict
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def index
    summaries = query_service.list_orders
    render json: summaries.map { |summary| build_summary_json(summary) }
  end

  def show
    details = query_service.find_order(params[:id])
    if details
      render json: build_detail_json(details)
    else
      render_not_found
    end
  end

  def create
    order_id = command_handler.create_order(customer_name: create_params.fetch(:customer_name))
    render json: { order_id: order_id }, status: :created
  end

  def add_item
    command_handler.add_item(
      order_id: params[:id],
      product_name: add_item_params.fetch(:product_name),
      quantity: add_item_params.fetch(:quantity),
      unit_price_cents: add_item_params.fetch(:unit_price_cents)
    )
    head :no_content
  end

  def remove_item
    command_handler.remove_item(
      order_id: params[:id],
      product_name: remove_item_params.fetch(:product_name)
    )
    head :no_content
  end

  def confirm
    command_handler.confirm(order_id: params[:id])
    head :no_content
  end

  def cancel
    command_handler.cancel(
      order_id: params[:id],
      reason: cancel_params.fetch(:reason)
    )
    head :no_content
  end

  def ship
    command_handler.ship(
      order_id: params[:id],
      tracking_number: ship_params.fetch(:tracking_number)
    )
    head :no_content
  end

  private

  def command_handler
    @command_handler ||= Orders::Container.command_handler
  end

  def query_service
    @query_service ||= Projections::Container.query_service
  end

  def create_params
    params.require(:order).permit(:customer_name)
  end

  def add_item_params
    params.require(:order_item).permit(:product_name, :quantity, :unit_price_cents)
  end

  def remove_item_params
    params.require(:order_item).permit(:product_name)
  end

  def cancel_params
    params.require(:order).permit(:reason)
  end

  def ship_params
    params.require(:order).permit(:tracking_number)
  end

  def build_summary_json(record)
    {
      order_id: record.order_id,
      customer_name: record.customer_name,
      status: record.status,
      total_amount_cents: record.total_amount_cents,
      item_count: record.item_count,
      confirmed_at: record.confirmed_at,
      cancelled_at: record.cancelled_at,
      shipped_at: record.shipped_at
    }
  end

  def build_detail_json(record)
    {
      order_id: record.order_id,
      customer_name: record.customer_name,
      status: record.status,
      items: Array(record.items),
      total_amount_cents: record.total_amount_cents,
      confirmed_at: record.confirmed_at,
      cancelled_at: record.cancelled_at,
      shipped_at: record.shipped_at,
      cancellation_reason: record.cancellation_reason,
      tracking_number: record.tracking_number
    }
  end

  def render_unprocessable_entity(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def render_conflict(error)
    render json: { error: error.message }, status: :conflict
  end

  def render_not_found(_error = nil)
    render json: { error: "order not found" }, status: :not_found
  end
end
