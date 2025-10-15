# frozen_string_literal: true

require_relative '../../event_store/event'

module Domain
  module Events
    class AccountOpened < EventStore::Event
      def self.create(aggregate_id:, owner_name:, initial_balance:)
        new(
          event_id: SecureRandom.uuid,
          event_type: 'AccountOpened',
          aggregate_id: aggregate_id,
          data: {
            owner_name: owner_name,
            initial_balance: initial_balance
          },
          metadata: {
            timestamp: Time.now
          },
          version: 1
        )
      end

      def owner_name
        data[:owner_name]
      end

      def initial_balance
        data[:initial_balance]
      end
    end
  end
end
