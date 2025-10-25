Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "products#index"
  resources :products, only: [ :index, :show ]

  # Cart and Order routes
  resource :cart, only: [ :show, :destroy ] do
    resources :items, only: [ :create, :update, :destroy ], controller: "cart_items"
  end

  resources :orders, only: [ :index, :show, :create ]
end
