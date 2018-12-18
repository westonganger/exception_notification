Dummy::Application.routes.draw do
  resources :posts, only: %i[create show]
end
