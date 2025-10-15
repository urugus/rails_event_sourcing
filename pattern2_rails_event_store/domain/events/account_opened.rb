# frozen_string_literal: true

module Events
  class AccountOpened < RailsEventStore::Event
    # イベントのスキーマ定義（任意だが推奨）
    # data:
    #   account_number: String
    #   owner_name: String
    #   initial_balance: Decimal
    #   opened_at: Time

    def self.strict(data:, metadata: {})
      new(
        event_id: SecureRandom.uuid,
        data: data,
        metadata: metadata.merge(timestamp: Time.current)
      )
    end
  end
end
