Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "dashboard#show"

  # master data
  resources :sites, :zones, :locations, :customers, :items, :sensors, :device_profiles, except: :show

  # receiving
  resources :receipts, only: %i[index new create show] do
    member do
      patch :complete
      post :attach_photos
    end
    resources :receipt_lines, only: :create do
      member { patch :putaway }
    end
  end

  # shipping
  resources :shipments, only: %i[index new create show] do
    member { patch :ship }
    resources :shipment_lines, only: %i[create destroy] do
      collection { post :auto }
      member { patch :pick }
    end
  end

  # inventory
  resources :lots, only: %i[index show] do
    member do
      patch :hold
      patch :unhold
    end
  end
  get "stock", to: "stock#index"
  resources :movements, only: %i[index new create]
  resources :stocktakes, only: %i[index new create show] do
    member do
      patch :submit
      patch :approve
    end
    resources :stocktake_lines, only: :update
  end

  # temperature
  get "temperature", to: "temperature_board#show"
  resources :temperature_readings, only: %i[index new create] do
    member do
      get :correct, action: :new_correction
      post :correct, action: :create_correction
    end
  end
  resources :reading_imports, only: %i[new create]
  resources :excursions, only: %i[index show]
  resources :excursion_lot_impacts, only: :update

  # admin
  resources :imports, only: %i[index new create show] do
    member do
      post :commit
      post :rollback
    end
  end
  resources :users, except: %i[show destroy]
  resources :audit_logs, only: :index

  # reports
  get "reports", to: "reports#index"
  scope "reports", controller: :reports do
    get :stock, as: :stock_report
    get :daily_stock, as: :daily_stock_report
    get :movements, as: :movements_report
    get :zone_log, as: :zone_log_report
    get :excursion_history, as: :excursion_history_report
    get :lot_temperature, as: :lot_temperature_report
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
