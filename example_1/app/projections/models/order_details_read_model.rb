# frozen_string_literal: true

module Projections
  module Models
    # ActiveRecord版の注文詳細Read Model
    # テーブル: order_details_read_models
    #
    # このモデルは注文詳細表示用に最適化されています。
    # 商品情報を含む完全な注文データを保持します。
    class OrderDetailsReadModel < ApplicationRecord
      self.table_name = "order_details_read_models"

      # アソシエーション
      has_many :order_item_read_models,
               class_name: "Projections::Models::OrderItemReadModel",
               foreign_key: :order_id,
               primary_key: :order_id,
               dependent: :destroy

      # バリデーション
      validates :order_id, presence: true, uniqueness: true
      validates :customer_name, presence: true
      validates :status, presence: true, inclusion: { in: %w[pending confirmed shipped cancelled] }
      validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

      # スコープ
      scope :pending, -> { where(status: "pending") }
      scope :confirmed, -> { where(status: "confirmed") }
      scope :shipped, -> { where(status: "shipped") }
      scope :cancelled, -> { where(status: "cancelled") }
      scope :by_customer, ->(name) { where(customer_name: name) }
      scope :recent, -> { order(placed_at: :desc) }
      scope :with_items, -> { includes(:order_item_read_models) }

      # 商品合計を計算
      def items_total
        order_item_read_models.sum(&:subtotal)
      end

      # ステータスチェック
      def pending?
        status == "pending"
      end

      def confirmed?
        status == "confirmed"
      end

      def shipped?
        status == "shipped"
      end

      def cancelled?
        status == "cancelled"
      end
    end
  end
end

# マイグレーション例:
#
# class CreateOrderDetailsReadModels < ActiveRecord::Migration[7.0]
#   def change
#     create_table :order_details_read_models do |t|
#       t.string :order_id, null: false, index: { unique: true }
#       t.string :customer_name, null: false, index: true
#       t.decimal :total_amount, precision: 10, scale: 2, null: false
#       t.string :status, null: false, index: true
#       t.datetime :placed_at, null: false
#       t.datetime :confirmed_at
#       t.datetime :shipped_at
#       t.datetime :cancelled_at
#       t.string :tracking_number
#       t.string :cancel_reason
#
#       t.timestamps
#     end
#   end
# end
