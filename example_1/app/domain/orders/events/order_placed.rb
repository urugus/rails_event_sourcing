# frozen_string_literal: true

module Domain
  module Orders
    module Events
      # 注文が作成されたイベント
      class OrderPlaced < EventSourcing::Event
        def order_id
          attributes[:order_id]
        end

        def customer_name
          attributes[:customer_name]
        end

        def total_amount
          attributes[:total_amount]
        end

        def placed_at
          attributes[:placed_at]
        end
      end
    end
  end
end
