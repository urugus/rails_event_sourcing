# frozen_string_literal: true

module Domain
  module Orders
    module Events
      # 注文が発送されたイベント
      class OrderShipped < EventSourcing::Event
        def order_id
          attributes[:order_id]
        end

        def tracking_number
          attributes[:tracking_number]
        end

        def shipped_at
          attributes[:shipped_at]
        end
      end
    end
  end
end
