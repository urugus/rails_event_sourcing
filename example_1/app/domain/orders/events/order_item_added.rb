# frozen_string_literal: true

module Domain
  module Orders
    module Events
      # 注文に商品が追加されたイベント
      class OrderItemAdded < EventSourcing::Event
        def order_id
          attributes[:order_id]
        end

        def product_name
          attributes[:product_name]
        end

        def quantity
          attributes[:quantity]
        end

        def unit_price
          attributes[:unit_price]
        end
      end
    end
  end
end
