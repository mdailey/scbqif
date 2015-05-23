Rails.application.routes.draw do

  devise_for :users

  resources :users do
    resources :accounts do
      collection do
        post 'sync'
      end
      resources :statements do
        collection do
          post 'sync' => 'statements#sync_all'
        end
        member do
          post 'sync' => 'statements#sync_one'
        end
      end
    end
  end

  resources :profiles

  root 'home#index'

end
