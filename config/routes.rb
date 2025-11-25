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

  get "admin", to: "admin#index"
end
