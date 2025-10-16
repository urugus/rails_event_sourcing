# frozen_string_literal: true

module Domain
  module Orders
    module Events
      # 注文がキャンセルされたイベント
      class OrderCancelled < EventSourcing::Event
        def order_id
          attributes[:order_id]
        end

        def reason
          attributes[:reason]
        end

        def cancelled_at
          attributes[:cancelled_at]
        end
      end
    end
  end
end
