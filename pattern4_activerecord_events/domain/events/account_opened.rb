# frozen_string_literal: true

require_relative 'base_event'

module Domain
  module Events
    class AccountOpened < BaseEvent
      def self.create(aggregate_id:, owner_name:, initial_balance:)
        new(
          event_id: SecureRandom.uuid,
          aggregate_id: aggregate_id,
          data: {
            owner_name: owner_name,
            initial_balance: initial_balance
          },
          metadata: {
            timestamp: Time.current,
            user_id: nil # コンテキストから取得可能
          }
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
