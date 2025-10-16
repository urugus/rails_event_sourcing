# frozen_string_literal: true

module Domain
  module Orders
    module Commands
      # 注文に商品を追加するコマンド
      class AddOrderItem < ::Commands::Command
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

        protected

        def validate!
          require_attributes(:order_id, :product_name, :quantity, :unit_price)

          if product_name.to_s.strip.empty?
            raise ArgumentError, "Product name cannot be blank"
          end

          if quantity <= 0
            raise ArgumentError, "Quantity must be positive"
          end

          if unit_price < 0
            raise ArgumentError, "Unit price cannot be negative"
          end
        end
      end
    end
  end
end
