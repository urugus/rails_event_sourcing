# frozen_string_literal: true

module EventSourcing
  # イベントの基底クラス
  class Event
    attr_reader :attributes

    def initialize(attributes = {})
      @attributes = attributes
    end

    # イベントをハッシュに変換する
    def to_h
      attributes
    end

    # ハッシュからイベントを復元する
    def self.from_h(data)
      new(data)
    end
  end
end
