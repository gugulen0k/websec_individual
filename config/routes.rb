Rails.application.routes.draw do
  root "sessions#new"

  get  "/guestbook",          to: "guestbook#index"
  get  "/guestbook/new",      to: "guestbook#new"
  post "/guestbook",          to: "guestbook#create"


  get  "login",  to: "sessions#new"
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get "/admin",   to: "admin#dashboard",   as: :admin_dashboard
  get "/manager", to: "manager#dashboard", as: :manager_dashboard
  get "/user",    to: "user#dashboard",    as: :user_dashboard

  # Админ-панель с логами
  namespace :admin do
    resources :logs, only: [ :index ] do
      collection do
        get :search
        get :download
        get :stats
      end
    end

    resources :errors, only: [ :index ] do
      collection do
        get :search
        get :download
        get :stats
      end
    end
  end

  get "admin", to: "admin#index"
end
