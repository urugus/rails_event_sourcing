# frozen_string_literal: true

require_relative '../../event_store/event'

module Domain
  module Events
    class MoneyWithdrawn < EventStore::Event
      def self.create(aggregate_id:, amount:, description: nil)
        new(
          event_id: SecureRandom.uuid,
          event_type: 'MoneyWithdrawn',
          aggregate_id: aggregate_id,
          data: {
            amount: amount,
            description: description
          },
          metadata: {
            timestamp: Time.now
          },
          version: 1
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
