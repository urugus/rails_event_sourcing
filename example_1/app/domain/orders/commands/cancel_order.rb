# frozen_string_literal: true

module Domain
  module Orders
    module Commands
      # 注文をキャンセルするコマンド
      class CancelOrder < ::Commands::Command
        def order_id
          attributes[:order_id]
        end

        def reason
          attributes[:reason]
        end

        protected

        def validate!
          require_attributes(:order_id, :reason)

          if reason.to_s.strip.empty?
            raise ArgumentError, "Reason cannot be blank"
          end
        end
      end
    end
  end
end
