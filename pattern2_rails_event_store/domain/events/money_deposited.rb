# frozen_string_literal: true

module Events
  class MoneyDeposited < RailsEventStore::Event
    # イベントのスキーマ定義（任意だが推奨）
    # data:
    #   account_number: String
    #   amount: Decimal
    #   description: String (optional)
    #   deposited_at: Time

    def self.strict(data:, metadata: {})
      new(
        event_id: SecureRandom.uuid,
        data: data,
        metadata: metadata.merge(timestamp: Time.current)
      )
    end
  end
end
