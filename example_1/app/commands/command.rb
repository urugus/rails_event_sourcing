# frozen_string_literal: true

module Commands
  # コマンドの基底クラス
  class Command
    attr_reader :attributes

    def initialize(attributes = {})
      @attributes = attributes
      validate!
    end

    protected

    # バリデーション（サブクラスでオーバーライド可能）
    def validate!
      # デフォルトでは何もしない
    end

    # 必須属性のチェック
    def require_attributes(*keys)
      missing = keys.select { |key| attributes[key].nil? }
      if missing.any?
        raise ArgumentError, "Missing required attributes: #{missing.join(', ')}"
      end
    end
  end
end
