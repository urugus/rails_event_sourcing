# frozen_string_literal: true

module Domain
  module Orders
    module Commands
      # 注文を確定するコマンド
      class ConfirmOrder < ::Commands::Command
        def order_id
          attributes[:order_id]
        end

        protected

        def validate!
          require_attributes(:order_id)
        end
      end
    end
  end
end
