# frozen_string_literal: true

Rails.application.routes.draw do
  # 注文エンドポイント
  resources :orders, only: [:index, :show, :create] do
    member do
      # コマンドエンドポイント（書き込み）
      post :add_item
      post :confirm
      post :cancel
      post :ship
    end

    collection do
      # クエリエンドポイント（読み取り）
      get :statistics
      get 'status/:status', action: :by_status, as: :by_status
    end
  end
end

# ルーティング例:
#
# POST   /orders                    注文を作成
# GET    /orders                    注文一覧を取得
# GET    /orders/:id                注文詳細を取得
# POST   /orders/:id/add_item       商品を追加
# POST   /orders/:id/confirm        注文を確定
# POST   /orders/:id/cancel         注文をキャンセル
# POST   /orders/:id/ship           注文を発送
# GET    /orders/status/:status     ステータスで検索
# GET    /orders/statistics         統計情報を取得
