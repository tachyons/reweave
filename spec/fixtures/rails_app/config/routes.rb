# frozen_string_literal: true

# Routes fixture: legacy match syntax that UpdateRailsRoutes modernizes.
Rails.application.routes.draw do
  match ':controller(/:action(/:id))'
  match "/logout", via: :post
  get "/login", to: "sessions#new"
  resources :users
end
