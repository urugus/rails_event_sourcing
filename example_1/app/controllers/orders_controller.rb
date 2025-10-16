# frozen_string_literal: true

# 注文コントローラー
# CQRS パターンに従い、コマンド（書き込み）とクエリ（読み取り）を分離
class OrdersController < ApplicationController
  # POST /orders
  # 新しい注文を作成する（コマンド）
  def create
    command = Domain::Orders::Commands::PlaceOrder.new(
      order_id: SecureRandom.uuid,
      customer_name: params[:customer_name],
      total_amount: params[:total_amount]
    )

    $order_command_handler.handle_place_order(command)

    render json: { order_id: command.order_id }, status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /orders/:id/items
  # 注文に商品を追加する（コマンド）
  def add_item
    command = Domain::Orders::Commands::AddOrderItem.new(
      order_id: params[:id],
      product_name: params[:product_name],
      quantity: params[:quantity],
      unit_price: params[:unit_price]
    )

    $order_command_handler.handle_add_order_item(command)

    head :ok
  rescue ArgumentError, Domain::Orders::OrderCommandHandler::OrderNotFoundError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Domain::Orders::Order::InvalidOperationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /orders/:id/confirm
  # 注文を確定する（コマンド）
  def confirm
    command = Domain::Orders::Commands::ConfirmOrder.new(order_id: params[:id])
    $order_command_handler.handle_confirm_order(command)

    head :ok
  rescue Domain::Orders::OrderCommandHandler::OrderNotFoundError => e
    render json: { error: e.message }, status: :not_found
  rescue Domain::Orders::Order::InvalidOperationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /orders/:id/cancel
  # 注文をキャンセルする（コマンド）
  def cancel
    command = Domain::Orders::Commands::CancelOrder.new(
      order_id: params[:id],
      reason: params[:reason]
    )

    $order_command_handler.handle_cancel_order(command)

    head :ok
  rescue Domain::Orders::OrderCommandHandler::OrderNotFoundError => e
    render json: { error: e.message }, status: :not_found
  rescue Domain::Orders::Order::InvalidOperationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /orders/:id/ship
  # 注文を発送する（コマンド）
  def ship
    command = Domain::Orders::Commands::ShipOrder.new(
      order_id: params[:id],
      tracking_number: params[:tracking_number]
    )

    $order_command_handler.handle_ship_order(command)

    head :ok
  rescue Domain::Orders::OrderCommandHandler::OrderNotFoundError => e
    render json: { error: e.message }, status: :not_found
  rescue Domain::Orders::Order::InvalidOperationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /orders
  # すべての注文を取得する（クエリ）
  def index
    @orders = $order_queries.all_orders
    render json: @orders
  end

  # GET /orders/:id
  # 注文詳細を取得する（クエリ）
  def show
    @order = $order_queries.find_order_details(params[:id])

    if @order
      render json: @order.as_json(include: :order_item_read_models)
    else
      render json: { error: "Order not found" }, status: :not_found
    end
  end

  # GET /orders/status/:status
  # ステータスで注文を検索する（クエリ）
  def by_status
    @orders = $order_queries.find_orders_by_status(params[:status])
    render json: @orders
  end

  # GET /orders/statistics
  # 注文統計を取得する（クエリ）
  def statistics
    stats = $order_queries.order_statistics
    render json: stats
  end
end
