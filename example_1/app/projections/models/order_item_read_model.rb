# frozen_string_literal: true

module Projections
  module Models
    # ActiveRecord版の注文商品Read Model
    # テーブル: order_item_read_models
    #
    # 注文詳細の商品情報を保持します。
    class OrderItemReadModel < ApplicationRecord
      self.table_name = "order_item_read_models"

      # アソシエーション
      belongs_to :order_details_read_model,
                 class_name: "Projections::Models::OrderDetailsReadModel",
                 foreign_key: :order_id,
                 primary_key: :order_id

      # バリデーション
      validates :order_id, presence: true
      validates :product_name, presence: true
      validates :quantity, presence: true, numericality: { greater_than: 0 }
      validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
      validates :subtotal, presence: true, numericality: { greater_than_or_equal_to: 0 }

      # コールバック
      before_validation :calculate_subtotal

      private

      def calculate_subtotal
        self.subtotal = quantity * unit_price if quantity && unit_price
      end
    end
  end
end

# マイグレーション例:
#
# class CreateOrderItemReadModels < ActiveRecord::Migration[7.0]
#   def change
#     create_table :order_item_read_models do |t|
#       t.string :order_id, null: false, index: true
#       t.string :product_name, null: false
#       t.integer :quantity, null: false
#       t.decimal :unit_price, precision: 10, scale: 2, null: false
#       t.decimal :subtotal, precision: 10, scale: 2, null: false
#
#       t.timestamps
#     end
#
#     add_foreign_key :order_item_read_models, :order_details_read_models,
#                     column: :order_id, primary_key: :order_id
#   end
# end
