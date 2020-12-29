Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "home#index"
  
  devise_for :users
  namespace :user do
    # user 登入後會轉址到 user_home_path
    root to: 'home#index' # 路徑會是 /user/home#index
  end
end
