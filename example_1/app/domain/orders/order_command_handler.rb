# frozen_string_literal: true

module Domain
  module Orders
    # 注文のコマンドハンドラー
    # コマンドを受け取り、集約に対する操作を実行する
    class OrderCommandHandler
      def initialize(repository:)
        @repository = repository
      end

      # 注文を作成する
      def handle_place_order(command)
        order = Order.place(
          order_id: command.order_id,
          customer_name: command.customer_name,
          total_amount: command.total_amount
        )

        @repository.save(order)
      end

      # 商品を追加する
      def handle_add_order_item(command)
        order = find_order(command.order_id)

        order.add_item(
          product_name: command.product_name,
          quantity: command.quantity,
          unit_price: command.unit_price
        )

        @repository.save(order)
      end

      # 注文を確定する
      def handle_confirm_order(command)
        order = find_order(command.order_id)
        order.confirm
        @repository.save(order)
      end

      # 注文をキャンセルする
      def handle_cancel_order(command)
        order = find_order(command.order_id)
        order.cancel(reason: command.reason)
        @repository.save(order)
      end

      # 注文を発送する
      def handle_ship_order(command)
        order = find_order(command.order_id)
        order.ship(tracking_number: command.tracking_number)
        @repository.save(order)
      end

      private

      def find_order(order_id)
        order = @repository.find(order_id)
        if order.nil?
          raise OrderNotFoundError, "Order not found: #{order_id}"
        end
        order
      end

      class OrderNotFoundError < StandardError; end
    end
  end
end
