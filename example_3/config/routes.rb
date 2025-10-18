Rails.application.routes.draw do
  resources :orders, only: [:index, :show, :create] do
    member do
      post :add_item
      post :remove_item
      post :confirm
      post :cancel
      post :ship
    end
  end

  # Inventory management endpoints
  resources :inventory, only: [:index, :show], param: :product_id do
    member do
      post :add_stock
    end
  end
end
