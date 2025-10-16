# frozen_string_literal: true

module Projections
  module Queries
    # ActiveRecord版の注文クエリサービス
    # ActiveRecord Read Modelから最適化されたデータを取得する
    class ArOrderQueries
      # すべての注文サマリーを取得する
      def all_orders
        Models::OrderSummaryReadModel.recent.all
      end

      # 注文サマリーを取得する
      def find_order_summary(order_id)
        Models::OrderSummaryReadModel.find_by(order_id: order_id)
      end

      # 注文詳細を取得する（商品情報を含む）
      def find_order_details(order_id)
        Models::OrderDetailsReadModel
          .with_items
          .find_by(order_id: order_id)
      end

      # ステータスで注文を検索する
      def find_orders_by_status(status)
        Models::OrderSummaryReadModel
          .where(status: status)
          .recent
          .all
      end

      # 顧客名で注文を検索する
      def find_orders_by_customer(customer_name)
        Models::OrderSummaryReadModel
          .by_customer(customer_name)
          .recent
          .all
      end

      # 発送済みの注文を取得する
      def shipped_orders
        Models::OrderSummaryReadModel
          .shipped
          .recent
          .all
      end

      # 確定待ちの注文を取得する
      def pending_orders
        Models::OrderSummaryReadModel
          .pending
          .recent
          .all
      end

      # 確定済みの注文を取得する
      def confirmed_orders
        Models::OrderSummaryReadModel
          .confirmed
          .recent
          .all
      end

      # キャンセルされた注文を取得する
      def cancelled_orders
        Models::OrderSummaryReadModel
          .cancelled
          .recent
          .all
      end

      # 期間指定で注文を検索する
      def orders_between(start_date, end_date)
        Models::OrderSummaryReadModel
          .where(placed_at: start_date..end_date)
          .recent
          .all
      end

      # 高額注文を検索する（指定金額以上）
      def high_value_orders(amount)
        Models::OrderSummaryReadModel
          .where("total_amount >= ?", amount)
          .recent
          .all
      end

      # 統計情報を取得する
      def order_statistics
        {
          total_count: Models::OrderSummaryReadModel.count,
          pending_count: Models::OrderSummaryReadModel.pending.count,
          confirmed_count: Models::OrderSummaryReadModel.confirmed.count,
          shipped_count: Models::OrderSummaryReadModel.shipped.count,
          cancelled_count: Models::OrderSummaryReadModel.cancelled.count,
          total_revenue: Models::OrderSummaryReadModel.shipped.sum(:total_amount)
        }
      end
    end
  end
end
