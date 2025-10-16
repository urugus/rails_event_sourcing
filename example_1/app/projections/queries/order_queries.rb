# frozen_string_literal: true

module Projections
  module Queries
    # 注文のクエリサービス
    # Read Modelから最適化されたデータを取得する
    class OrderQueries
      def initialize(read_model_store:)
        @read_model_store = read_model_store
      end

      # すべての注文サマリーを取得する
      def all_orders
        @read_model_store.all("order_summaries")
      end

      # 注文サマリーを取得する
      def find_order_summary(order_id)
        @read_model_store.find("order_summaries", order_id)
      end

      # 注文詳細を取得する
      def find_order_details(order_id)
        @read_model_store.find("order_details", order_id)
      end

      # ステータスで注文を検索する
      def find_orders_by_status(status)
        @read_model_store.where("order_summaries", { status: status })
      end

      # 顧客名で注文を検索する
      def find_orders_by_customer(customer_name)
        @read_model_store.where("order_summaries", { customer_name: customer_name })
      end

      # 発送済みの注文を取得する
      def shipped_orders
        find_orders_by_status("shipped")
      end

      # 確定待ちの注文を取得する
      def pending_orders
        find_orders_by_status("pending")
      end

      # 確定済みの注文を取得する
      def confirmed_orders
        find_orders_by_status("confirmed")
      end

      # キャンセルされた注文を取得する
      def cancelled_orders
        find_orders_by_status("cancelled")
      end
    end
  end
end
