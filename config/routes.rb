require "sidekiq/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

   resources :image_requests, only: %i[index create show destroy] do
     post :retry, on: :member
    delete :destroy_all, on: :collection
   end

   namespace :api do
     namespace :v1 do
       resources :image_requests, only: %i[index create show destroy] do
         post :retry, on: :member
         get :statuses, on: :collection
        delete :destroy_all, on: :collection
       end

      resources :image_results, only: [] do
        post :regenerate, on: :member
        delete :destroy_image, on: :member
      end

      get :models, to: "image_requests#models"
    end
  end

  resources :prompt_projects, only: %i[index create show] do
    post :run, on: :member
  end
  resources :prompt_runs, only: %i[show] do
    resources :prompt_feedbacks, only: %i[create]
  end
  get "models", to: "image_requests#models"
  post "git_push", to: "git_pushes#create", as: :git_push
  get "generated_images/:id", to: "image_requests#image", as: :generated_image
  get "prompt_run_images/:id", to: "prompt_projects#image", as: :prompt_run_image
  post "generated_images/:id/regenerate", to: "image_requests#regenerate_result_image", as: :regenerate_generated_image
  delete "generated_images/:id", to: "image_requests#destroy_result_image", as: :destroy_generated_image
  mount Sidekiq::Web => "/sidekiq"
  root "home#index"
end
