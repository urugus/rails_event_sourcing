# frozen_string_literal: true

module Domain
  module Orders
    module Commands
      # 注文を発送するコマンド
      class ShipOrder < ::Commands::Command
        def order_id
          attributes[:order_id]
        end

        def tracking_number
          attributes[:tracking_number]
        end

        protected

        def validate!
          require_attributes(:order_id, :tracking_number)

          if tracking_number.to_s.strip.empty?
            raise ArgumentError, "Tracking number cannot be blank"
          end
        end
      end
    end
  end
end
