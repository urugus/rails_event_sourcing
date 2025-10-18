class InventoryController < ApplicationController
  before_action :run_projections

  # POST /inventory/:product_id/add_stock
  def add_stock
    product_id = params[:product_id]
    quantity = params[:quantity].to_i

    command_handler.add_stock(
      product_id: product_id,
      quantity: quantity
    )

    run_projections

    render json: {
      message: "Stock added successfully",
      product_id: product_id,
      quantity: quantity
    }, status: :created
  rescue Inventory::DomainError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /inventory/:product_id
  def show
    product_id = params[:product_id]
    inventory = query_service.get_inventory(product_id)

    if inventory
      render json: inventory
    else
      render json: { error: "Inventory not found" }, status: :not_found
    end
  end

  # GET /inventory
  def index
    inventories = query_service.list_all_inventories
    render json: inventories
  end

  private

  def command_handler
    Inventory::Container.inventory_command_handler
  end

  def query_service
    Projections::Container.inventory_query_service
  end

  def run_projections
    Projections::Container.projection_manager.call
  end
end
