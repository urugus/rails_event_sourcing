# frozen_string_literal: true

module Domain
  module Orders
    module Events
      # 注文が確定されたイベント
      class OrderConfirmed < EventSourcing::Event
        def order_id
          attributes[:order_id]
        end

        def confirmed_at
          attributes[:confirmed_at]
        end
      end
    end
  end
end
