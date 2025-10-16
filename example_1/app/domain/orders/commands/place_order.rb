# frozen_string_literal: true

module Domain
  module Orders
    module Commands
      # 注文を作成するコマンド
      class PlaceOrder < ::Commands::Command
        def order_id
          attributes[:order_id]
        end

        def customer_name
          attributes[:customer_name]
        end

        def total_amount
          attributes[:total_amount]
        end

        protected

        def validate!
          require_attributes(:order_id, :customer_name, :total_amount)

          if customer_name.to_s.strip.empty?
            raise ArgumentError, "Customer name cannot be blank"
          end

          if total_amount <= 0
            raise ArgumentError, "Total amount must be positive"
          end
        end
      end
    end
  end
end
