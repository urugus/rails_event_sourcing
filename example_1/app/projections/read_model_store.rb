# frozen_string_literal: true

module Projections
  # インメモリのRead Model Store
  # クエリサイドのデータを保存する
  class ReadModelStore
    def initialize
      @data = {}
    end

    # データを保存する
    def save(collection, id, data)
      @data[collection] ||= {}
      @data[collection][id] = data
    end

    # データを取得する
    def find(collection, id)
      return nil unless @data[collection]
      @data[collection][id]
    end

    # すべてのデータを取得する
    def all(collection)
      return [] unless @data[collection]
      @data[collection].values
    end

    # 条件に合うデータを検索する
    def where(collection, conditions = {})
      return [] unless @data[collection]

      @data[collection].values.select do |item|
        conditions.all? { |key, value| item[key] == value }
      end
    end

    # データを削除する
    def delete(collection, id)
      return unless @data[collection]
      @data[collection].delete(id)
    end

    # すべてのデータをクリアする（テスト用）
    def clear!
      @data.clear
    end
  end
end
