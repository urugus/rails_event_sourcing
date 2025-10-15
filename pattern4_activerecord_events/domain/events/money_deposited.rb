# frozen_string_literal: true

require_relative 'base_event'

module Domain
  module Events
    class MoneyDeposited < BaseEvent
      def self.create(aggregate_id:, amount:, description: nil)
        new(
          event_id: SecureRandom.uuid,
          aggregate_id: aggregate_id,
          data: {
            amount: amount,
            description: description
          },
          metadata: {
            timestamp: Time.current,
            user_id: nil
          }
        )
      end

      def amount
        data[:amount]
      end

      def description
        data[:description]
      end
    end
  end
end
